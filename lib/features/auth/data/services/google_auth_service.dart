import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthService {
  GoogleAuthService._();

  // Public OAuth client IDs are supplied at build time; never embed a secret.
  static const webClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
  static const iosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');
  static Future<void>? _initialization;

  static Future<String> getIdToken() async {
    if (kIsWeb) {
      throw StateError('Use ShopHop Web to sign in with Google in a browser.');
    }
    if (webClientId.isEmpty ||
        (defaultTargetPlatform == TargetPlatform.iOS && iosClientId.isEmpty)) {
      throw StateError('Google sign-in is not configured for this app build.');
    }

    final google = GoogleSignIn.instance;
    _initialization ??= google.initialize(
      clientId: defaultTargetPlatform == TargetPlatform.iOS
          ? iosClientId
          : null,
      serverClientId: webClientId,
    );
    await _initialization;
    final account = await google.authenticate();
    final token = account.authentication.idToken;
    if (token == null || token.isEmpty) {
      throw StateError('Google did not provide a sign-in token. Try again.');
    }
    return token;
  }
}
