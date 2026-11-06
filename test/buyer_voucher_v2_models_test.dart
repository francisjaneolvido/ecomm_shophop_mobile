import 'package:flutter_test/flutter_test.dart';
import 'package:shophop/features/buyer/data/services/buyer_checkout_service.dart';

void main() {
  test(
    'checkout preview preserves seller identity and voucher details for separate shops',
    () {
      final preview = BuyerCheckoutPreviewData.fromJson({
        'address': {'complete': true},
        'cart_groups': [
          {
            'shop': {'id': 11, 'name': 'Seller A'},
            'voucher_discount': 100,
            'seller_shipping_discount': 0,
            'items': [],
          },
          {
            'shop': {'id': 22, 'name': 'Seller B'},
            'voucher_discount': 0,
            'seller_shipping_discount': 20,
            'items': [],
          },
        ],
        'available_vouchers': [
          {
            'code': 'SELLER10',
            'seller_id': 11,
            'kind': 'merchandise',
            'product_ids': [3],
          },
          {
            'code': 'SHIP20',
            'seller_id': 22,
            'kind': 'shipping',
            'product_ids': [4],
          },
        ],
        'available_platform_vouchers': [
          {'code': 'WELCOME30', 'name': 'Welcome', 'kind': 'merchandise'},
        ],
        'summary': {
          'grand_total': 950,
          'voucher_discount': 100,
          'seller_shipping_discount': 20,
        },
      });

      expect(preview.groups.map((s) => s.sellerId), [11, 22]);
      expect(preview.groups.first.voucherDiscount, 100);
      expect(preview.groups.last.sellerShippingDiscount, 20);
      expect(preview.vouchers.map((v) => v.sellerId), [11, 22]);
      expect(preview.availablePlatformVouchers.single.code, 'WELCOME30');
      expect(preview.summary.grandTotal, 950);
    },
  );
}
