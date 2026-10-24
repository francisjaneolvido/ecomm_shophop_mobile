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
  static const String _rememberKey = 'shophop_auth_remember';

  // The active session always lives in memory while the app is open.
  // Secure storage is only used when the user explicitly enables Remember me.
  static AuthSession? _memorySession;

  static Future<void> saveSession({
    required String token,
    required String email,
    required String accountType,
    required bool rememberMe,
  }) async {
    final session = AuthSession(
      token: token,
      email: email,
      accountType: accountType,
    );

    _memorySession = session;

    if (!rememberMe) {
      // Prevent a previous remembered login from surviving after the user
      // signs in again without checking Remember me.
      await _clearPersistedSession();
      return;
    }

    try {
      await _storage.write(key: _tokenKey, value: token);
      await _storage.write(key: _emailKey, value: email);
      await _storage.write(key: _accountTypeKey, value: accountType);
      await _storage.write(key: _rememberKey, value: 'true');
    } catch (error, stackTrace) {
      // Keep the in-memory session usable even if persistence fails.
      debugPrint('ShopHop session persistence failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  /// Reads the active session used by authenticated screens.
  /// This can be either a temporary in-memory session or a remembered session.
  static Future<AuthSession?> readSession() async {
    final cached = _memorySession;
    if (cached != null) {
      return cached;
    }

    return readRememberedSession();
  }

  /// Used during app startup. A session is restored only when Remember me was
  /// explicitly enabled during the successful login that created it.
  static Future<AuthSession?> readRememberedSession() async {
    try {
      final remembered = await _storage.read(key: _rememberKey);
      if (remembered != 'true') {
        return null;
      }

      final token = await _storage.read(key: _tokenKey);
      final email = await _storage.read(key: _emailKey);
      final accountType = await _storage.read(key: _accountTypeKey);

      if (token == null ||
          token.isEmpty ||
          email == null ||
          email.isEmpty ||
          accountType == null ||
          accountType.isEmpty) {
        await _clearPersistedSession();
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
      debugPrint('ShopHop remembered session read failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  static Future<String?> readToken() async {
    final cached = _memorySession;
    if (cached != null) {
      return cached.token;
    }

    final session = await readRememberedSession();
    return session?.token;
  }

  static Future<void> clearSession() async {
    _memorySession = null;
    await _clearPersistedSession();
  }

  static Future<void> _clearPersistedSession() async {
    for (final key in const [
      _tokenKey,
      _emailKey,
      _accountTypeKey,
      _rememberKey,
    ]) {
      try {
        await _storage.delete(key: key);
      } catch (error) {
        debugPrint('ShopHop session cleanup failed for $key: $error');
      }
    }
  }
}
