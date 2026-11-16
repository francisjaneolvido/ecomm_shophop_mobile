import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shophop/features/seller/data/services/seller_workspace_service.dart';

void main() {
  test('a 25 MB Seller video is sent as authenticated MP4 multipart', () async {
    final bytes = Uint8List(26214400);
    final result = await http.runWithClient(
      () => SellerWorkspaceService.saveProduct(
        token: 'seller-test',
        fields: {'name': 'Test product'},
        video: PlatformFile(name: 'item.mp4', size: bytes.length, bytes: bytes),
      ),
      () => MockClient((request) async {
        expect(request.headers['authorization'], 'Bearer seller-test');
        expect(request.url.path, endsWith('/seller/inventory/products'));
        expect(request.bodyBytes.length, greaterThan(26214400));
        final header = latin1.decode(request.bodyBytes.take(1200).toList());
        expect(header, contains('name="video"; filename="item.mp4"'));
        expect(header, contains('content-type: video/mp4'));
        return http.Response(
          jsonEncode({
            'success': true,
            'message': 'Saved.',
            'data': {'id': 1},
          }),
          200,
        );
      }),
    );
    expect(result.success, isTrue);
  });

  test('a video above 25 MB is rejected before sending any request', () async {
    var requests = 0;
    final result = await http.runWithClient(
      () => SellerWorkspaceService.saveProduct(
        token: 'seller-test',
        fields: {},
        video: PlatformFile(
          name: 'large.mp4',
          size: 26214401,
          bytes: Uint8List(8),
        ),
      ),
      () => MockClient((request) async {
        requests++;
        return http.Response('{"success":true}', 200);
      }),
    );
    expect(result.success, isFalse);
    expect(result.message, contains('25 MB'));
    expect(requests, 0);
  });

  test(
    'a proxy 413 keeps the Seller draft and explains the upload limit',
    () async {
      final result = await http.runWithClient(
        () => SellerWorkspaceService.saveProduct(
          token: 'seller-test',
          productId: 7,
          fields: {},
        ),
        () => MockClient(
          (request) async =>
              http.Response('<html>Content too large</html>', 413),
        ),
      );
      expect(result.success, isFalse);
      expect(result.statusCode, 413);
      expect(result.message, contains('upload'));
      expect(result.message, contains('25 MB'));
    },
  );
}
