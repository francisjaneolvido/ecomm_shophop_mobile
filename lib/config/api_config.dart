import 'package:flutter/foundation.dart';

class ApiConfig {
  ApiConfig._();

  static const String _overrideBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static String get baseUrl {
    if (_overrideBaseUrl.isNotEmpty) {
      return _overrideBaseUrl.replaceFirst(RegExp(r'/$'), '');
    }

    if (kIsWeb) {
      return 'http://127.0.0.1:8000/api/mobile';
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000/api/mobile';
    }

    return 'http://127.0.0.1:8000/api/mobile';
  }

  /// The Laravel origin without `/api/mobile`.
  static Uri get serverOrigin {
    final apiUri = Uri.parse(baseUrl);

    return Uri(
      scheme: apiUri.scheme,
      host: apiUri.host,
      port: apiUri.hasPort ? apiUri.port : null,
    );
  }

  /// Laravel's `asset()` may return localhost URLs. That is fine on Chrome,
  /// but Android emulators must use 10.0.2.2 (or the API_BASE_URL host).
  /// This method keeps product/category media on the same host as the API.
  static String resolveMediaUrl(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) {
      return '';
    }

    final parsed = Uri.tryParse(raw);
    if (parsed == null) {
      return raw;
    }

    if (parsed.hasScheme) {
      final localHosts = <String>{
        '127.0.0.1',
        'localhost',
        '10.0.2.2',
      };

      if (localHosts.contains(parsed.host.toLowerCase())) {
        return Uri(
          scheme: serverOrigin.scheme,
          host: serverOrigin.host,
          port: serverOrigin.hasPort ? serverOrigin.port : null,
          path: parsed.path,
          query: parsed.hasQuery ? parsed.query : null,
          fragment: parsed.hasFragment ? parsed.fragment : null,
        ).toString();
      }

      return raw;
    }

    final normalized = raw.startsWith('/') ? raw.substring(1) : raw;
    return serverOrigin.resolve(normalized).toString();
  }
}
