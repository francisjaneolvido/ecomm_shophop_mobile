import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shophop/core/config/api_config.dart';
import 'package:shophop/features/auth/data/services/auth_service.dart';

void main() {
  group('ShopHop production API configuration', () {
    test('uses HTTPS mobile API by default', () {
      // Run this test without a custom --dart-define.
      expect(ApiConfig.baseUrl, 'https://shop-hop.site/api/mobile');
      expect(ApiConfig.serverOrigin.toString(), 'https://shop-hop.site');
    });

    test('rewrites localhost Laravel media to the live origin', () {
      expect(
        ApiConfig.resolveMediaUrl('http://127.0.0.1:8000/storage/items/photo.jpg'),
        'https://shop-hop.site/storage/items/photo.jpg',
      );
    });

    test('upgrades HTTP media from the same ShopHop hostname', () {
      expect(
        ApiConfig.resolveMediaUrl('http://shop-hop.site/storage/x.jpg?size=2'),
        'https://shop-hop.site/storage/x.jpg?size=2',
      );
    });

    test('resolves relative asset paths against web origin, not /api/mobile', () {
      expect(
        ApiConfig.resolveMediaUrl('/images/product.jpg'),
        'https://shop-hop.site/images/product.jpg',
      );
    });

    test('does not rewrite genuine third-party media', () {
      expect(
        ApiConfig.resolveMediaUrl('https://example.org/image.png'),
        'https://example.org/image.png',
      );
    });
  });

  group('Auth response parsing', () {
    test('does not accept a Cloudflare HTML page as successful login', () {
      final result = AuthApiResult.fromResponse(http.Response(
        '<html><body>Authentication required</body></html>',
        200,
        headers: {'content-type': 'text/html'},
      ));
      expect(result.success, isFalse);
      expect(result.status, 'unexpected_response');
    });

    test('retains valid Laravel auth result', () {
      final result = AuthApiResult.fromResponse(http.Response(
        '{"success":true,"status":"approved","message":"Welcome","data":{"token":"test-token"}}',
        200,
        headers: {'content-type': 'application/json'},
      ));
      expect(result.success, isTrue);
      expect(result.data['token'], 'test-token');
    });

    test('does not accept a 500 response even with a success field', () {
      final result = AuthApiResult.fromResponse(http.Response(
        '{"success":true,"message":"not actually successful"}',
        500,
      ));
      expect(result.success, isFalse);
    });
  });
}
