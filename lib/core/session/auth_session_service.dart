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
  static const String _welcomeCompletedKey = 'shophop_welcome_completed';

  // The active session lives in memory while the app is open. Login credentials
  // are persisted only with Remember me; the welcome flag is independent.
  static AuthSession? _memorySession;

  /// The welcome screen is a one-time introduction, independent of Remember me.
  static Future<bool> hasCompletedWelcome() async {
    try {
      return await _storage.read(key: _welcomeCompletedKey) == 'true';
    } catch (error) {
      debugPrint('ShopHop welcome preference read failed: $error');
      return false;
    }
  }

  static Future<void> markWelcomeComplete() async {
    try {
      await _storage.write(key: _welcomeCompletedKey, value: 'true');
    } catch (error) {
      debugPrint('ShopHop welcome preference save failed: $error');
    }
  }

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
    await markWelcomeComplete();

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
      await markWelcomeComplete();
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

  static Future<void> replaceToken(String token) async {
    final session = await readSession();
    if (session == null) return;
    var remember = false;
    try {
      remember = await _storage.read(key: _rememberKey) == 'true';
    } catch (_) {}
    await saveSession(
      token: token,
      email: session.email,
      accountType: session.accountType,
      rememberMe: remember,
    );
  }

  static Future<void> clearSession() async {
    _memorySession = null;
    await _clearPersistedSession();
  }

  static Future<bool> isRemembered() async =>
      await _storage.read(key: _rememberKey) == 'true';

  /// Keep the current session in memory while removing saved sign-in details.
  static Future<void> forgetRememberedSession() async {
    _memorySession = await readSession();
    // Unlike logout cleanup, a failure must reach the settings screen.
    for (final key in [_rememberKey, _tokenKey, _emailKey, _accountTypeKey]) {
      await _storage.delete(key: key);
    }
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
