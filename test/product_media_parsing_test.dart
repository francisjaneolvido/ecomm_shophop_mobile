import 'package:flutter_test/flutter_test.dart';
import 'package:shophop/features/buyer/data/services/buyer_catalog_service.dart';

void main() {
  test('Buyer product accepts backend image_url when image is absent', () {
    final product = BuyerProductData.fromJson({
      'id': 1, 'name': 'Sample', 'price': 200, 'stock': 5,
      'image_url': '/storage/products/photo.jpg',
      'seller': {'business_name': 'ShopHop Seller'},
    });
    expect(product.image, contains('/storage/products/photo.jpg'));
  });

  test('Buyer product media fallback ignores video URLs as image sources', () {
    final product = BuyerProductData.fromJson({
      'id': 2, 'name': 'Video-first Sample', 'price': 350, 'stock': 5,
      'media': [
        {'type': 'video', 'url': '/storage/videos/demo.mp4'},
        {'type': 'image', 'url': '/storage/products/cover.jpg'},
      ],
      'seller': {},
    });
    expect(product.image, contains('/storage/products/cover.jpg'));
  });
}
