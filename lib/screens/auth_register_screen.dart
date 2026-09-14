import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AuthRegisterScreen extends StatefulWidget {
  const AuthRegisterScreen({super.key});

  @override
  State<AuthRegisterScreen> createState() =>
      _AuthRegisterScreenState();
}

class _AuthRegisterScreenState
    extends State<AuthRegisterScreen> {
  // Адрес твоего сервера FastAPI
  static const String _apiBaseUrl =
      'http://45.150.9.50:8000';

  final GlobalKey<FormState> _formKey =
      GlobalKey<FormState>();

  final TextEditingController _emailController =
      TextEditingController();
  final TextEditingController _passwordController =
      TextEditingController();

  bool _isLoading = false;
  bool _consentGiven = false;
  String? _errorMessage;

  // Флаг для глазка пароля: false — пароль скрыт, true — показан
  bool _passwordVisible = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final FormState? form = _formKey.currentState;
    if (form == null) return;

    if (!form.validate()) {
      return;
    }

    if (!_consentGiven) {
      setState(() {
        _errorMessage =
            'Нужно дать согласие на обработку персональных данных.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final Uri uri = Uri.parse(
        '$_apiBaseUrl/auth/register',
      );

      final http.Response response =
          await http
              .post(
                uri,
                headers: {
                  'Content-Type':
                      'application/json; charset=utf-8',
                },
                body: jsonEncode({
                  'email':
                      _emailController.text.trim(),
                  'password':
                      _passwordController.text.trim(),
                  'consent': true,
                }),
              )
              .timeout(
                const Duration(seconds: 10),
              );

      if (response.statusCode == 200) {
        // Успех: показываем сообщение и потом
        // будем переходить на экран ввода кода
        final Map<String, dynamic> data =
            jsonDecode(response.body)
                as Map<String, dynamic>;

        final String message =
            (data['message'] as String?) ??
                'На почту отправлен код подтверждения.';

        if (!mounted) return;

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

        // TODO: сюда позже добавим переход на экран ввода кода
        // Navigator.of(context).push(
        //   MaterialPageRoute(
        //     builder: (_) => AuthVerifyScreen(
        //       email: _emailController.text.trim(),
        //     ),
        //   ),
        // );
      } else if (response.statusCode == 409) {
        // Пользователь уже есть
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Пользователь с таким email уже зарегистрирован.';
        });
      } else if (response.statusCode == 400) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Некорректные данные. Проверьте email и пароль.';
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Ошибка сервера: ${response.statusCode}';
        });
      }
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage =
            'Не удалось подключиться к серверу. '
            'Проверьте интернет.';
      });
    }
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
          'Регистрация',
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
                  'Создайте аккаунт, чтобы привязать '
                  'светильники и управлять ими из интернета.',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _emailController,
                  keyboardType:
                      TextInputType.emailAddress,
                  decoration:
                      const InputDecoration(
                    labelText: 'Email',
                    hintText: 'user@example.com',
                    border: OutlineInputBorder(),
                  ),
                  validator: (String? value) {
                    final String v =
                        (value ?? '').trim();
                    if (v.isEmpty) {
                      return 'Укажите email.';
                    }
                    if (!v.contains('@') ||
                        !v.contains('.')) {
                      return 'Похоже, это не email.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_passwordVisible,
                  decoration: InputDecoration(
                    labelText: 'Пароль',
                    border:
                        const OutlineInputBorder(),
                    suffixIcon: IconButton(
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
                    final String v =
                        (value ?? '').trim();
                    if (v.length < 8) {
                      return 'Минимум 8 символов.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),
                CheckboxListTile(
                  value: _consentGiven,
                  onChanged: (bool? value) {
                    setState(() {
                      _consentGiven =
                          value ?? false;
                    });
                  },
                  controlAffinity:
                      ListTileControlAffinity.leading,
                  activeColor: primary,
                  title: const Text(
                    'Я согласен(а) на обработку '
                    'персональных данных и принимаю '
                    'пользовательское соглашение.',
                  ),
                ),
                if (_errorMessage != null)
                  Padding(
                    padding:
                        const EdgeInsets.only(
                      top: 8,
                    ),
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
                        _isLoading ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor:
                          Colors.white,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color:
                                  Colors.white,
                            ),
                          )
                        : const Text(
                            'Зарегистрироваться',
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
    );
  }
}