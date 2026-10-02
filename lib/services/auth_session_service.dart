import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthSession {
  const AuthSession({
    required this.token,
    required this.email,
    required this.accountType,
  });

  final String token;
  final String email;
  final String accountType;
}

class AuthSessionService {
  AuthSessionService._();

  static const FlutterSecureStorage _storage =
      FlutterSecureStorage();

  static const String _tokenKey =
      'shophop_auth_token';
  static const String _emailKey =
      'shophop_auth_email';
  static const String _accountTypeKey =
      'shophop_auth_account_type';

  static Future<void> saveSession({
    required String token,
    required String email,
    required String accountType,
  }) async {
    await Future.wait([
      _storage.write(
        key: _tokenKey,
        value: token,
      ),
      _storage.write(
        key: _emailKey,
        value: email,
      ),
      _storage.write(
        key: _accountTypeKey,
        value: accountType,
      ),
    ]);
  }

  static Future<AuthSession?> readSession() async {
    final values =
        await Future.wait([
      _storage.read(
        key: _tokenKey,
      ),
      _storage.read(
        key: _emailKey,
      ),
      _storage.read(
        key: _accountTypeKey,
      ),
    ]);

    final token = values[0];
    final email = values[1];
    final accountType = values[2];

    if (token == null ||
        token.isEmpty ||
        email == null ||
        email.isEmpty ||
        accountType == null ||
        accountType.isEmpty) {
      return null;
    }

    return AuthSession(
      token: token,
      email: email,
      accountType: accountType,
    );
  }

  static Future<String?> readToken() {
    return _storage.read(
      key: _tokenKey,
    );
  }

  static Future<void> clearSession() {
    return Future.wait([
      _storage.delete(
        key: _tokenKey,
      ),
      _storage.delete(
        key: _emailKey,
      ),
      _storage.delete(
        key: _accountTypeKey,
      ),
    ]);
  }
}
