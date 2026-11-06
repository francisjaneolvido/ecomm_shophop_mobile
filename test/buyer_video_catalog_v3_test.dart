import 'package:flutter_test/flutter_test.dart';
import 'package:shophop/features/buyer/data/services/buyer_catalog_service.dart';

void main() {
  test('Buyer catalog parses video-first metadata on product cards', () {
    final product = BuyerProductData.fromJson({
      'id': 20,
      'name': 'Video product',
      'category': 'Electronics and Gadgets',
      'price': 500,
      'stock': 4,
      'image': '/storage/products/cover.webp',
      'video_url': '/storage/products/demo.mp4',
      'media_first': 'video',
      'seller': <String, dynamic>{},
    });
    expect(product.videoFirst, isTrue);
    expect(product.videoUrl, contains('demo.mp4'));
    expect(product.image, contains('cover.webp'));
    expect(product.copyWith(isLiked: true).videoFirst, isTrue);
    expect(product.copyWith(isLiked: true).videoUrl, product.videoUrl);
  });

  test('Older product payloads remain image-only by default', () {
    final product = BuyerProductData.fromJson({
      'id': 21,
      'name': 'Old item',
      'price': 200,
      'stock': 1,
      'seller': <String, dynamic>{},
    });
    expect(product.videoUrl, isEmpty);
    expect(product.videoFirst, isFalse);
  });
}
