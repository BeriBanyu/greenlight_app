import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  bool _isProcessing = false;

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) {
      return;
    }

    final String? code = capture.barcodes.firstOrNull?.rawValue;

    if (code == null || code.isEmpty) {
      return;
    }

    _isProcessing = true;

    try {
      final Map<String, dynamic> data = _parseQrData(code);

      final String? apSsid = data['ap_ssid'] as String?;
      final String? key = data['key'] as String?;

      if (apSsid == null || key == null || apSsid.isEmpty || key.isEmpty) {
        throw const FormatException('В QR-коде нет ap_ssid или key');
      }

      Navigator.of(context).pop({
        'ap_ssid': apSsid,
        'key': key,
      });
    } catch (_) {
      setState(() {
        _isProcessing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Это не QR-код GreenLight. Отсканируй код светильника.',
          ),
        ),
      );
    }
  }

  Map<String, dynamic> _parseQrData(String code) {
    final String text = code.trim();

    if (!text.startsWith('{') || !text.endsWith('}')) {
      throw const FormatException('QR не содержит JSON');
    }

    final RegExp ssidRegExp =
        RegExp(r'"ap_ssid"\s*:\s*"([^"]+)"');
    final RegExp keyRegExp =
        RegExp(r'"key"\s*:\s*"([^"]+)"');

    final Match? ssidMatch = ssidRegExp.firstMatch(text);
    final Match? keyMatch = keyRegExp.firstMatch(text);

    if (ssidMatch == null || keyMatch == null) {
      throw const FormatException('Нет обязательных полей');
    }

    return {
      'ap_ssid': ssidMatch.group(1)!,
      'key': keyMatch.group(1)!,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Сканирование QR-кода'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            onDetect: _onDetect,
          ),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(
                  color: const Color(0xFF81C784),
                  width: 4,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          const Positioned(
            left: 24,
            right: 24,
            bottom: 48,
            child: Text(
              'Наведите камеру на QR-код на корпусе или в инструкции светильника.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}