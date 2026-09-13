import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'lamp_control_screen.dart';
import 'qr_scanner_screen.dart';

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  static const String _lampAddress = 'http://192.168.4.1';

  String? _apSsid;
  String? _key;

  String? _deviceId;
  String? _firmware;
  String? _product;

  @override
  void initState() {
    super.initState();
    _loadSavedDevice();
  }

  Future<void> _loadSavedDevice() async {
    final SharedPreferences prefs =
        await SharedPreferences.getInstance();

    final String? savedId = prefs.getString('gl_device_id');
    final String? savedKey = prefs.getString('gl_device_key');
    final String? savedFirmware =
        prefs.getString('gl_device_firmware');
    final String? savedProduct =
        prefs.getString('gl_device_product');
    final String? savedApSsid =
        prefs.getString('gl_device_ap_ssid');

    if (!mounted) {
      return;
    }

    if (savedId != null && savedKey != null) {
      setState(() {
        _deviceId = savedId;
        _key = savedKey;
        _firmware =
            (savedFirmware != null && savedFirmware.isNotEmpty)
                ? savedFirmware
                : null;
        _product =
            (savedProduct != null && savedProduct.isNotEmpty)
                ? savedProduct
                : null;
        _apSsid =
            (savedApSsid != null && savedApSsid.isNotEmpty)
                ? savedApSsid
                : null;
      });
    }
  }

  Future<void> _saveDeviceToPrefs() async {
    if (_deviceId == null || _key == null) {
      return;
    }

    final SharedPreferences prefs =
        await SharedPreferences.getInstance();

    await prefs.setString('gl_device_id', _deviceId!);
    await prefs.setString('gl_device_key', _key!);
    await prefs.setString('gl_device_firmware', _firmware ?? '');
    await prefs.setString('gl_device_product', _product ?? '');
    await prefs.setString('gl_device_ap_ssid', _apSsid ?? '');
  }

  Future<void> _startConnection() async {
    final Map<String, dynamic>? qrData =
        await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (context) => const QrScannerScreen(),
      ),
    );

    if (qrData == null || !mounted) {
      return;
    }

    final String? scannedSsid = qrData['ap_ssid']?.toString();
    final String? scannedKey = qrData['key']?.toString();

    if (scannedSsid == null ||
        scannedSsid.isEmpty ||
        scannedKey == null ||
        scannedKey.isEmpty) {
      _showSimpleError(
        'QR-код не содержит ap_ssid или key.',
      );
      return;
    }

    setState(() {
      _apSsid = scannedSsid;
      _key = scannedKey;

      _deviceId = null;
      _firmware = null;
      _product = null;
    });

    _showWifiInstruction();
  }

  void _showWifiInstruction() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(
            Icons.wifi_rounded,
            color: Color(0xFF2E7D32),
            size: 44,
          ),
          title: const Text('Подключитесь к светильнику'),
          content: Text(
            'Сверните приложение и откройте настройки Wi-Fi.\n\n'
            'Подключитесь к сети:\n\n'
            '${_apSsid ?? ''}\n\n'
            'Если Android сообщит, что в сети нет интернета, '
            'выберите «Оставаться подключённым».\n\n'
            'Вернитесь сюда и нажмите «Проверить подключение».',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _verifyEsp32();
              },
              child: const Text('Проверить подключение'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _verifyEsp32() async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Expanded(
                child: Text('Проверяем соединение с ESP32...'),
              ),
            ],
          ),
        );
      },
    );

    String? foundDeviceId;
    String? foundFirmware;
    String? foundProduct;
    String? errorMessage;

    try {
      final Uri uri = Uri.parse('$_lampAddress/info');

      final http.Response response = await http.get(uri).timeout(
            const Duration(seconds: 7),
          );

      if (response.statusCode != 200) {
        throw Exception(
          'ESP32 вернула код ${response.statusCode}',
        );
      }

      final dynamic decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        throw const FormatException(
          'ESP32 вернула данные неправильного формата',
        );
      }

      foundDeviceId = decoded['deviceId']?.toString();
      foundFirmware = decoded['firmware']?.toString();
      foundProduct = decoded['product']?.toString();

      if (foundDeviceId == null || foundDeviceId.isEmpty) {
        throw const FormatException(
          'В ответе ESP32 отсутствует deviceId',
        );
      }
    } on TimeoutException {
      errorMessage =
          'ESP32 не ответила за 7 секунд. Проверьте, что телефон '
          'подключён к сети ${_apSsid ?? 'GreenLight'}.';
    } on FormatException catch (error) {
      errorMessage = error.message;
    } catch (error) {
      errorMessage =
          'Не удалось связаться со светильником.\n\n$error';
    }

    if (!mounted) {
      return;
    }

    Navigator.of(context, rootNavigator: true).pop();

    if (errorMessage != null) {
      _showConnectionError(errorMessage);
      return;
    }

    setState(() {
      _deviceId = foundDeviceId;
      _firmware = foundFirmware;
      _product = foundProduct;
    });

    await _saveDeviceToPrefs();
    _showDeviceConnected();
  }

  void _showSimpleError(String message) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Ошибка'),
          content: Text(message),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Закрыть'),
            ),
          ],
        );
      },
    );
  }

  void _showConnectionError(String message) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(
            Icons.error_outline_rounded,
            color: Colors.red,
            size: 44,
          ),
          title: const Text('Светильник не найден'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Закрыть'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _showWifiInstruction();
              },
              child: const Text('Повторить'),
            ),
          ],
        );
      },
    );
  }

  void _showDeviceConnected() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(
            Icons.check_circle_rounded,
            color: Color(0xFF2E7D32),
            size: 48,
          ),
          title: const Text('Светильник подключён'),
          content: Text(
            'Приложение получило ответ от устройства.\n\n'
            'ID: ${_deviceId ?? 'неизвестен'}\n'
            'Прошивка: ${_firmware ?? 'неизвестна'}\n'
            'Модель: ${_product ?? 'неизвестна'}',
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Готово'),
            ),
          ],
        );
      },
    );
  }

  void _openLampControl() {
    final String? deviceId = _deviceId;
    final String? keyValue = _key;

    if (deviceId == null || keyValue == null) {
      _showSimpleError(
        'Нет данных устройства. Отсканируйте QR-код заново.',
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => LampControlScreen(
          deviceId: deviceId,
          keyValue: keyValue,
          firmware: _firmware,
          product: _product,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasVerifiedDevice = _deviceId != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Мои светильники'),
      ),
      body: hasVerifiedDevice
          ? _buildDeviceList()
          : _buildEmptyState(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.wb_sunny_outlined,
              size: 96,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 24),
            const Text(
              'Светильники не добавлены',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Отсканируйте QR-код GreenLight и подключитесь '
              'к точке доступа светильника.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black54,
                fontSize: 16,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: _startConnection,
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: const Text('Подключить светильник'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceList() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Локальные светильники',
          style: TextStyle(
            fontSize: 14,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: const CircleAvatar(
              radius: 26,
              backgroundColor: Color(0xFFE8F5E9),
              child: Icon(
                Icons.wb_sunny_rounded,
                color: Color(0xFF2E7D32),
                size: 30,
              ),
            ),
            title: const Text(
              'GreenLight',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                'ID: $_deviceId\n'
                'Прошивка: ${_firmware ?? 'неизвестна'}',
              ),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: _openLampControl,
          ),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: _startConnection,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Подключить ещё один светильник'),
        ),
      ],
    );
  }
}