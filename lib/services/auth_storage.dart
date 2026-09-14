import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthStorage {
  static const String _tokenKey = 'gl_auth_token';

  static const FlutterSecureStorage _storage =
      FlutterSecureStorage();

  static Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  static Future<String?> readToken() async {
    return _storage.read(key: _tokenKey);
  }

  static Future<void> deleteToken() async {
    await _storage.delete(key: _tokenKey);
  }
}