class ApiConfig {
  ApiConfig._();

  // Production default. Override at build/run time for local development:
  // flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/mobile
  // Android emulator: 10.0.2.2; browser on the PC: 127.0.0.1.
  static const String _productionBaseUrl = 'https://shop-hop.site/api/mobile';

  static const String _overrideBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static String get baseUrl => _overrideBaseUrl.trim().isNotEmpty
      ? _overrideBaseUrl.trim().replaceFirst(RegExp(r'/+$'), '')
      : _productionBaseUrl;

  /// Public Laravel origin without `/api/mobile`.
  static Uri get serverOrigin {
    final apiUri = Uri.parse(baseUrl);
    return Uri(
      scheme: apiUri.scheme,
      host: apiUri.host,
      port: apiUri.hasPort ? apiUri.port : null,
    );
  }

  /// Resolve Laravel media URLs for the active backend. Laravel may still
  /// return absolute localhost URLs (or HTTP links to its HTTPS hostname).
  /// Only rewrite localhost or this backend's own hostname; leave external
  /// CDN and payment provider URLs untouched.
  static String resolveMediaUrl(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return '';

    final parsed = Uri.tryParse(raw);
    if (parsed == null) return raw;

    final origin = serverOrigin;
    if (parsed.hasScheme) {
      final host = parsed.host.toLowerCase();
      const localHosts = {'127.0.0.1', 'localhost', '10.0.2.2'};
      final isLocal = localHosts.contains(host);
      final isInsecureSameHost = parsed.scheme == 'http' &&
          origin.scheme == 'https' &&
          host == origin.host.toLowerCase();

      if (isLocal || isInsecureSameHost) {
        return Uri(
          scheme: origin.scheme,
          host: origin.host,
          port: origin.hasPort ? origin.port : null,
          path: parsed.path,
          query: parsed.hasQuery ? parsed.query : null,
          fragment: parsed.hasFragment ? parsed.fragment : null,
        ).toString();
      }
      return raw;
    }

    // A scheme-relative URL (//other.example/image.jpg) is already absolute
    // to a host; preserve that host instead of inventing a ShopHop path.
    if (raw.startsWith('//')) return '${origin.scheme}:$raw';

    final normalized = raw.startsWith('/') ? raw.substring(1) : raw;
    return origin.resolve(normalized).toString();
  }
}
