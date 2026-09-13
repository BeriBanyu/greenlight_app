import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'lamp_schedule_screen.dart';

class LampControlScreen extends StatefulWidget {
  const LampControlScreen({
    super.key,
    required this.deviceId,
    required this.keyValue,
    this.firmware,
    this.product,
  });

  final String deviceId;
  final String keyValue;
  final String? firmware;
  final String? product;

  @override
  State<LampControlScreen> createState() => _LampControlScreenState();
}

class _LampControlScreenState extends State<LampControlScreen> {
  static const String _lampAddress = 'http://192.168.4.1';

  static const Color _primary = Color(0xFF2E7D32);
  static const Color _background = Color(0xFFF5F5F0);
  static const Color _lightGreen = Color(0xFFE8F5E9);

  bool _isLoading = true;
  bool _isSending = false;
  bool _isOn = false;
  bool _isAutomatic = true;

  double _brightness = 0;
  int _lastNonZeroBrightness = 100;

  String _connectivity = 'UNKNOWN';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus({bool showLoader = true}) async {
    if (showLoader && mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final Uri uri = Uri.parse('$_lampAddress/status');

      final http.Response response = await http.get(uri).timeout(
            const Duration(seconds: 7),
          );

      if (response.statusCode != 200) {
        throw Exception(
          'ESP32 вернула код ${response.statusCode}',
        );
      }

      _parseStatus(response.body);

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = null;
      });
    } on TimeoutException {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage =
            'ESP32 не ответила. Проверьте подключение телефона '
            'к Wi-Fi светильника.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = 'Ошибка получения состояния:\n$error';
      });
    }
  }

  void _parseStatus(String rawStatus) {
    final List<String> parts = rawStatus
        .trim()
        .split(RegExp(r'[\s,;|]+'))
        .where((part) => part.isNotEmpty)
        .toList();

    bool foundPower = false;
    bool foundMode = false;
    bool foundBrightness = false;

    bool newIsOn = _isOn;
    bool newIsAutomatic = _isAutomatic;
    double newBrightness = _brightness;
    String newConnectivity = _connectivity;

    for (final String originalPart in parts) {
      final String part = originalPart.toUpperCase();

      if (part == 'ON') {
        newIsOn = true;
        foundPower = true;
        continue;
      }

      if (part == 'OFF') {
        newIsOn = false;
        foundPower = true;
        continue;
      }

      if (part == 'AUTO') {
        newIsAutomatic = true;
        foundMode = true;
        continue;
      }

      if (part == 'MANUAL') {
        newIsAutomatic = false;
        foundMode = true;
        continue;
      }

      if (part == 'ONLINE' ||
          part == 'OFFLINE' ||
          part == 'WIFI_ONLY' ||
          part == 'WIFIONLY') {
        newConnectivity = part;
        continue;
      }

      // На случай, если статус содержит проценты, типа "75%".
      final String numberText = part.replaceAll(
        RegExp(r'[^0-9]'),
        '',
      );

      final int? number = int.tryParse(numberText);

      if (!foundBrightness &&
          number != null &&
          number >= 0 &&
          number <= 100) {
        newBrightness = number.toDouble();
        foundBrightness = true;

        if (number > 0) {
          _lastNonZeroBrightness = number;
        }
      }
    }

    if (!foundPower || !foundMode || !foundBrightness) {
      throw FormatException(
        'Не удалось распознать ответ ESP32: $rawStatus',
      );
    }

    _isOn = newIsOn;
    _isAutomatic = newIsAutomatic;
    _brightness = newBrightness;
    _connectivity = newConnectivity;
  }

  Future<void> _sendCommand(String command) async {
    if (_isSending) {
      return;
    }

    setState(() {
      _isSending = true;
      _errorMessage = null;
    });

    try {
      final Uri uri = Uri.parse('$_lampAddress/command');

      final http.Response response = await http
          .post(
            uri,
            body: {
              'key': widget.keyValue,
              'cmd': command,
            },
          )
          .timeout(const Duration(seconds: 7));

      if (response.statusCode == 403) {
        throw Exception(
          'Неверный ключ устройства. '
          'Отсканируйте QR-код повторно.',
        );
      }

      if (response.statusCode != 200) {
        throw Exception(
          'ESP32 вернула код ${response.statusCode}: '
          '${response.body}',
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _isSending = false;
      });

      // Лёгкая задержка, чтобы ESP32 успела применить изменения.
      await Future<void>.delayed(
        const Duration(milliseconds: 150),
      );

      await _loadStatus(showLoader: false);
    } on TimeoutException {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSending = false;
        _errorMessage =
            'ESP32 не ответила. Проверьте Wi-Fi телефона.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSending = false;
        _errorMessage = error.toString();
      });
    }
  }

  Future<void> _togglePower() async {
    if (_isSending) {
      return;
    }

    final bool shouldTurnOn = !_isOn;

    setState(() {
      // При ручном управлении мы явно выходим из авто.
      _isAutomatic = false;
      _isOn = shouldTurnOn;

      if (shouldTurnOn) {
        if (_brightness == 0) {
          _brightness = _lastNonZeroBrightness.toDouble();
        }
      } else {
        if (_brightness > 0) {
          _lastNonZeroBrightness = _brightness.round();
        }

        _brightness = 0;
      }
    });

    await _sendCommand(shouldTurnOn ? 'ON' : 'OFF');
  }

  Future<void> _sendBrightness(double value) async {
    if (_isAutomatic || _isSending) {
      return;
    }

    final int percent = value.round().clamp(0, 100).toInt();

    if (percent > 0) {
      _lastNonZeroBrightness = percent;
    }

    setState(() {
      _brightness = percent.toDouble();
      _isOn = percent > 0;
    });

    await _sendCommand('BRIGHT:$percent');
  }

  Future<void> _returnToAuto() async {
    if (_isAutomatic || _isSending) {
      return;
    }

    setState(() {
      _isAutomatic = true;
    });

    await _sendCommand('MODE:AUTO');
  }

  void _openSchedule() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => LampScheduleScreen(
          deviceId: widget.deviceId,
          keyValue: widget.keyValue,
        ),
      ),
    );
  }

  void _showNetworkInfo() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            _connectivity == 'ONLINE'
                ? 'Светильник подключён к серверу.'
                : 'Приложение подключено к локальной сети светильника.',
          ),
        ),
      );
  }

  void _showSettings() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: _background,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 6, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Информация о светильнике',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 22),
                _buildInfoRow('Название', 'GreenLight Grow'),
                _buildInfoRow('ID', widget.deviceId),
                _buildInfoRow(
                  'Модель',
                  widget.product ?? 'grow',
                ),
                _buildInfoRow(
                  'Прошивка',
                  widget.firmware ?? 'неизвестна',
                ),
                _buildInfoRow('Адрес', '192.168.4.1'),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: _primary,
                    ),
                    child: const Text('Готово'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 95,
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.black54,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: const Text(
          'Green Light',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _showSettings,
            tooltip: 'Настройки',
            icon: const Icon(Icons.settings_outlined),
          ),
          IconButton(
            onPressed: _showNetworkInfo,
            tooltip: 'Локальная сеть',
            icon: const Icon(Icons.wifi_off_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: _primary,
        ),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    return RefreshIndicator(
      color: _primary,
      onRefresh: () => _loadStatus(showLoader: false),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 520,
              ),
              child: Column(
                children: [
                  _buildDeviceHeader(),
                  const SizedBox(height: 34),
                  _buildBulbGlow(),
                  const SizedBox(height: 22),
                  Text(
                    _isOn ? 'Свет включён' : 'Свет выключен',
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 30),
                  _buildBrightness(),
                  const SizedBox(height: 20),
                  _buildBadges(),
                  const SizedBox(height: 28),
                  if (_isSending) ...[
                    const LinearProgressIndicator(
                      color: _primary,
                      backgroundColor: _lightGreen,
                    ),
                    const SizedBox(height: 18),
                  ],
                  _buildPowerButton(),
                  const SizedBox(height: 14),
                  _buildSecondaryButtons(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceHeader() {
    return Column(
      children: [
        const Text(
          'GreenLight Grow',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 7),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: _primary,
                shape: BoxShape.circle,
              ),
              child: SizedBox(
                width: 8,
                height: 8,
              ),
            ),
            SizedBox(width: 8),
            Text(
              'Подключён',
              style: TextStyle(
                color: _primary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBulbGlow() {
    final double intensity = _isOn ? _brightness / 100 : 0;

    final double glowOpacity = 0.10 + (intensity * 0.22);
    final double glowBlur = 25 + (intensity * 35);
    final double glowSpread = 5 + (intensity * 18);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
      width: 205,
      height: 205,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: _isOn
              ? [
                  Color.fromRGBO(
                    46,
                    125,
                    50,
                    0.24 + intensity * 0.12,
                  ),
                  const Color.fromRGBO(46, 125, 50, 0.08),
                  const Color.fromRGBO(46, 125, 50, 0),
                ]
              : [
                  const Color.fromRGBO(120, 120, 120, 0.08),
                  const Color.fromRGBO(120, 120, 120, 0.03),
                  const Color.fromRGBO(120, 120, 120, 0),
                ],
        ),
        boxShadow: _isOn
            ? [
                BoxShadow(
                  color: Color.fromRGBO(
                    46,
                    125,
                    50,
                    glowOpacity,
                  ),
                  blurRadius: glowBlur,
                  spreadRadius: glowSpread,
                ),
              ]
            : null,
      ),
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          width: 116,
          height: 116,
          decoration: BoxDecoration(
            color: _isOn ? _lightGreen : const Color(0xFFE5E5E1),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color.fromRGBO(0, 0, 0, 0.08),
                blurRadius: _isOn ? 18 : 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Icon(
            _isOn
                ? Icons.lightbulb_rounded
                : Icons.lightbulb_outline_rounded,
            size: 64,
            color: _isOn ? _primary : Colors.grey.shade500,
          ),
        ),
      ),
    );
  }

  Widget _buildBrightness() {
    return Column(
      children: [
        Row(
          children: [
            const Text(
              'Яркость',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              '${_brightness.round()}%',
              style: const TextStyle(
                color: _primary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: _primary,
            inactiveTrackColor: const Color(0xFFD8DDD5),
            thumbColor: _primary,
            overlayColor: const Color.fromRGBO(46, 125, 50, 0.14),
            disabledActiveTrackColor: _primary,
            disabledInactiveTrackColor: const Color(0xFFD8DDD5),
            disabledThumbColor: _primary,
            trackHeight: 6,
            thumbShape: const RoundSliderThumbShape(
              enabledThumbRadius: 10,
              disabledThumbRadius: 10,
            ),
          ),
          child: Slider(
            value: _brightness,
            min: 0,
            max: 100,
            divisions: 100,
            label: '${_brightness.round()}%',
            onChanged: _isAutomatic || _isSending
                ? null
                : (value) {
                    setState(() {
                      _brightness = value;
                      _isOn = value.round() > 0;
                    });
                  },
            onChangeEnd: _isAutomatic || _isSending
                ? null
                : _sendBrightness,
          ),
        ),
        if (_isAutomatic)
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Яркость управляется расписанием',
              style: TextStyle(
                color: Colors.black45,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBadges() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 10,
      children: [
        _buildBadge(
          icon: _isAutomatic
              ? Icons.schedule_rounded
              : Icons.tune_rounded,
          text: _isAutomatic
              ? 'Режим: Авто'
              : 'Режим: Ручной',
        ),
        _buildBadge(
          icon: Icons.wifi_rounded,
          text: 'В сети',
        ),
      ],
    );
  }

  Widget _buildBadge({
    required IconData icon,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: _lightGreen,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 17,
            color: _primary,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: _primary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPowerButton() {
    return SizedBox(
      width: double.infinity,
      height: 57,
      child: FilledButton(
        onPressed: _isSending ? null : _togglePower,
        style: FilledButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFA8C6AA),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 2,
        ),
        child: Text(
          _isOn ? 'ВЫКЛЮЧИТЬ' : 'ВКЛЮЧИТЬ',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryButtons() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 50,
            child: OutlinedButton.icon(
              onPressed: _isAutomatic || _isSending
                  ? null
                  : _returnToAuto,
              style: OutlinedButton.styleFrom(
                foregroundColor: _primary,
                side: const BorderSide(
                  color: _primary,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(
                Icons.autorenew_rounded,
                size: 19,
              ),
              label: const Text(
                'Вернуть авто',
                maxLines: 1,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 50,
            child: OutlinedButton.icon(
              onPressed: _isSending ? null : _openSchedule,
              style: OutlinedButton.styleFrom(
                foregroundColor: _primary,
                side: const BorderSide(
                  color: _primary,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(
                Icons.calendar_month_outlined,
                size: 19,
              ),
              label: const Text(
                'Расписание',
                maxLines: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: const BoxDecoration(
                color: Color(0xFFFFEBEE),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                color: Colors.red,
                size: 46,
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'Нет связи со светильником',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'Неизвестная ошибка',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black54,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 26),
            FilledButton.icon(
              onPressed: () => _loadStatus(),
              style: FilledButton.styleFrom(
                backgroundColor: _primary,
              ),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }
}