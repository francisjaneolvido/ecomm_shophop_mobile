import 'package:flutter/foundation.dart';
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

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static const String _tokenKey = 'shophop_auth_token';
  static const String _emailKey = 'shophop_auth_email';
  static const String _accountTypeKey = 'shophop_auth_account_type';

  // Keep the active session in memory as well. This avoids repeatedly touching
  // WebCrypto during a single Flutter Web session and makes navigation resilient
  // when the browser secure-storage implementation temporarily fails.
  static AuthSession? _memorySession;

  static Future<void> saveSession({
    required String token,
    required String email,
    required String accountType,
  }) async {
    final session = AuthSession(
      token: token,
      email: email,
      accountType: accountType,
    );
    _memorySession = session;

    try {
      // Do these sequentially. Concurrent WebCrypto/local-storage operations can
      // be less reliable during Flutter Web development/hot reloads.
      await _storage.write(key: _tokenKey, value: token);
      await _storage.write(key: _emailKey, value: email);
      await _storage.write(key: _accountTypeKey, value: accountType);
    } catch (error, stackTrace) {
      // The in-memory session remains valid for the current app session. A
      // persistence failure should not strand the user on a loading screen.
      debugPrint('ShopHop session persistence failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  static Future<AuthSession?> readSession() async {
    final cached = _memorySession;
    if (cached != null) {
      return cached;
    }

    try {
      final token = await _storage.read(key: _tokenKey);
      final email = await _storage.read(key: _emailKey);
      final accountType = await _storage.read(key: _accountTypeKey);

      if (token == null ||
          token.isEmpty ||
          email == null ||
          email.isEmpty ||
          accountType == null ||
          accountType.isEmpty) {
        return null;
      }

      final session = AuthSession(
        token: token,
        email: email,
        accountType: accountType,
      );
      _memorySession = session;
      return session;
    } catch (error, stackTrace) {
      debugPrint('ShopHop session read failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  static Future<String?> readToken() async {
    final cached = _memorySession;
    if (cached != null) {
      return cached.token;
    }

    try {
      return await _storage.read(key: _tokenKey);
    } catch (error) {
      debugPrint('ShopHop token read failed: $error');
      return null;
    }
  }

  static Future<void> clearSession() async {
    _memorySession = null;

    for (final key in const [_tokenKey, _emailKey, _accountTypeKey]) {
      try {
        await _storage.delete(key: key);
      } catch (error) {
        debugPrint('ShopHop session cleanup failed for $key: $error');
      }
    }
  }
}
