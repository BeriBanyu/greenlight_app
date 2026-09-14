import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class AuthVerifyScreen extends StatefulWidget {
  const AuthVerifyScreen({
    super.key,
    required this.email,
  });

  final String email;

  @override
  State<AuthVerifyScreen> createState() =>
      _AuthVerifyScreenState();
}

class _AuthVerifyScreenState extends State<AuthVerifyScreen> {
  static const String _apiBaseUrl =
      'https://greenlight-lamp.ru';

  final GlobalKey<FormState> _formKey =
      GlobalKey<FormState>();

  final TextEditingController _codeController =
      TextEditingController();

  bool _isLoading = false;
  bool _isResending = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verifyCode() async {
    final FormState? form = _formKey.currentState;

    if (form == null || !form.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final http.Response response = await http
          .post(
            Uri.parse('$_apiBaseUrl/auth/verify'),
            headers: {
              'Content-Type':
                  'application/json; charset=utf-8',
            },
            body: jsonEncode({
              'email': widget.email,
              'code': _codeController.text.trim(),
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (!mounted) {
        return;
      }

      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
            jsonDecode(response.body)
                as Map<String, dynamic>;

        final String message =
            (data['message'] as String?) ??
                'Email успешно подтверждён.';

        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              content: Text(message),
            ),
          );

        // TODO: после появления экрана «Мои светильники»
        // сохранить token и перейти на DevicesScreen.
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = _readErrorMessage(response);
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage =
            'Не удалось подключиться к серверу. '
            'Проверьте интернет.';
      });
    }
  }

  Future<void> _resendCode() async {
    setState(() {
      _isResending = true;
      _errorMessage = null;
    });

    try {
      final http.Response response = await http
          .post(
            Uri.parse('$_apiBaseUrl/auth/resend-code'),
            headers: {
              'Content-Type':
                  'application/json; charset=utf-8',
            },
            body: jsonEncode({
              'email': widget.email,
              'code': '000000',
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (!mounted) {
        return;
      }

      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
            jsonDecode(response.body)
                as Map<String, dynamic>;

        final String message =
            (data['message'] as String?) ??
                'Новый код отправлен на email.';

        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              content: Text(message),
            ),
          );
      } else {
        setState(() {
          _errorMessage = _readErrorMessage(response);
        });
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage =
            'Не удалось подключиться к серверу. '
            'Проверьте интернет.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  String _readErrorMessage(http.Response response) {
    try {
      final Map<String, dynamic> data =
          jsonDecode(response.body)
              as Map<String, dynamic>;

      final dynamic detail = data['detail'];

      if (detail is String && detail.isNotEmpty) {
        return detail;
      }
    } catch (_) {
      // Сервер может вернуть не JSON; ниже будет общий текст.
    }

    return 'Ошибка сервера: ${response.statusCode}';
  }

  @override
  Widget build(BuildContext context) {
    const Color primary = Color(0xFF2E7D32);
    const Color background = Color(0xFFF5F5F0);

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Подтверждение email',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 16,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                const Text(
                  'Введите шестизначный код, отправленный на адрес:',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.email,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _codeController,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Код подтверждения',
                    hintText: '000000',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  onFieldSubmitted: (_) => _verifyCode(),
                  validator: (String? value) {
                    final String code =
                        (value ?? '').trim();

                    if (code.length != 6) {
                      return 'Введите код из 6 цифр.';
                    }

                    return null;
                  },
                ),
                if (_errorMessage != null)
                  Padding(
                    padding:
                        const EdgeInsets.only(top: 12),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: Colors.red.shade700,
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed:
                        _isLoading ? null : _verifyCode,
                    style: FilledButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Подтвердить email',
                            style: TextStyle(
                              fontWeight:
                                  FontWeight.w700,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed:
                        _isResending ? null : _resendCode,
                    child: _isResending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Отправить код повторно',
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}