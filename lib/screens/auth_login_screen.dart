import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/auth_storage.dart';
import 'devices_screen.dart';

class AuthLoginScreen extends StatefulWidget {
  const AuthLoginScreen({super.key});

  @override
  State<AuthLoginScreen> createState() =>
      _AuthLoginScreenState();
}

class _AuthLoginScreenState extends State<AuthLoginScreen> {
  static const String _apiBaseUrl =
      'https://greenlight-lamp.ru';

  final GlobalKey<FormState> _formKey =
      GlobalKey<FormState>();

  final TextEditingController _emailController =
      TextEditingController();
  final TextEditingController _passwordController =
      TextEditingController();

  bool _isLoading = false;
  bool _passwordVisible = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
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
            Uri.parse('$_apiBaseUrl/auth/login'),
            headers: {
              'Content-Type':
                  'application/json; charset=utf-8',
            },
            body: jsonEncode({
              'email': _emailController.text.trim(),
              'password': _passwordController.text,
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

        final String? token = data['token'] as String?;

        if (token == null || token.isEmpty) {
          setState(() {
            _isLoading = false;
            _errorMessage =
                'Сервер не вернул токен авторизации.';
          });
          return;
        }

        await AuthStorage.saveToken(token);

        if (!mounted) {
          return;
        }

        setState(() {
          _isLoading = false;
        });

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (BuildContext context) =>
                const DevicesScreen(),
          ),
          (Route<dynamic> route) => false,
        );
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
          'Вход в аккаунт',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 16,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 420,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Войдите, чтобы управлять привязанными '
                      'светильниками через интернет.',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        hintText: 'user@example.com',
                        border: OutlineInputBorder(),
                      ),
                      validator: (String? value) {
                        final String email =
                            (value ?? '').trim();

                        if (email.isEmpty) {
                          return 'Укажите email.';
                        }

                        if (!email.contains('@') ||
                            !email.contains('.')) {
                          return 'Похоже, это не email.';
                        }

                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: !_passwordVisible,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _login(),
                      decoration: InputDecoration(
                        labelText: 'Пароль',
                        border:
                            const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          tooltip: _passwordVisible
                              ? 'Скрыть пароль'
                              : 'Показать пароль',
                          icon: Icon(
                            _passwordVisible
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() {
                              _passwordVisible =
                                  !_passwordVisible;
                            });
                          },
                        ),
                      ),
                      validator: (String? value) {
                        final String password =
                            value ?? '';

                        if (password.isEmpty) {
                          return 'Введите пароль.';
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
                            _isLoading ? null : _login,
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
                                'Войти',
                                style: TextStyle(
                                  fontWeight:
                                      FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}