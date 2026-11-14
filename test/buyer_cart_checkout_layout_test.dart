import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shophop/core/theme/app_theme.dart';
import 'package:shophop/features/buyer/presentation/pages/buyer_cart_page.dart';
import 'package:shophop/features/buyer/presentation/pages/buyer_checkout_page.dart';

Map<String, dynamic> line(String id, {int quantity = 1, int stock = 5}) => {
  'line_key': id,
  'product_id': int.parse(id),
  'variant_id': 7,
  'name': 'Comfortable cotton everyday shirt with a long product title',
  'variant': 'Color: Black · Size: Medium',
  'image': '',
  'price': 700,
  'qty': quantity,
  'stock': stock,
  'is_available': quantity <= stock,
  'line_total': 700 * quantity,
};
Map<String, dynamic> shop = {
  'id': 2,
  'name': 'Test Shop with a longer seller name',
  'municipality': 'Calamba City',
};
http.Response response(Map<String, dynamic> data) =>
    http.Response(jsonEncode({'success': true, 'data': data}), 200);
Map<String, dynamic> preview({int courier = 3, double shipping = 60}) => {
  'address': {
    'name': 'Test Buyer With A Long Name',
    'phone': '09171234567',
    'line': '123 Demo Street, Barangay 1',
    'city': 'Calamba City, Laguna',
    'is_default': true,
    'complete': true,
    'verified': true,
  },
  'cart_groups': [
    {
      'shop': shop,
      'items': [line('11', quantity: 2)],
      'shipping_fee_standard': shipping,
      'shipping_fee': shipping,
      'selected_shipping_method': 'standard',
      'selected_logistics_partner_id': courier,
      'shipping_quote': {
        'route_label': 'Same municipality / local route',
        'weight_kg': 0.05,
        'base_fee': 40,
        'distance_fee': 20,
      },
      'logistics_options': [
        {'id': 3, 'name': 'LagunaGo Logistics'},
        {
          'id': 4,
          'name': 'ShopHop Nationwide Logistics with a long company name',
        },
      ],
      'merchandise_subtotal': 1400,
      'group_total': 1400 + shipping,
    },
  ],
  'payment_method': 'cod',
  'item_count': 1,
  'quantity_count': 2,
  'shop_count': 1,
  'available_vouchers': [],
  'summary': {
    'merchandise_subtotal': 1400,
    'shipping_fee': shipping,
    'grand_total': 1400 + shipping,
  },
};

void main() {
  testWidgets(
    'cart preserves selected line IDs and quantities and blocks checkout during mutation',
    (tester) async {
      var quantity = 1;
      final updating = Completer<http.Response>();
      Map<String, int>? selected;
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.light,
              home: BuyerCartPage(
                token: 'test',
                onSessionExpired: () async {},
                onOpenProductId: (_) {},
                onContinueShopping: () {},
                onCheckout: (items) => selected = items,
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('cart-select-12')));
          await tester.pump();
          await tester.tap(find.text('Checkout (1)'));
          expect(selected, {'11': 1});
          await tester.tap(find.byKey(const ValueKey('cart-increase-11')));
          await tester.pump();
          expect(
            tester
                .widget<FilledButton>(
                  find.widgetWithText(FilledButton, 'Checkout (1)'),
                )
                .onPressed,
            isNull,
          );
          quantity = 2;
          updating.complete(response({'cart_count': 2}));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Checkout (1)'));
          expect(selected, {'11': 2});
          expect(tester.takeException(), isNull);
        },
        () => MockClient((request) async {
          expect(request.headers['authorization'], 'Bearer test');
          if (request.method != 'GET') return updating.future;
          return response({
            'groups': [
              {
                'shop': shop,
                'items': [line('11', quantity: quantity), line('12')],
              },
            ],
            'cart_count': 2,
            'quantity_count': quantity + 1,
            'subtotal': 700 * (quantity + 1),
          });
        }),
      );
    },
  );

  testWidgets(
    'cart keeps stock limits, group/select-all and confirmed deletion working',
    (tester) async {
      var removed = false;
      Map<String, int>? selected;
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.light,
              home: BuyerCartPage(
                token: 'test',
                onSessionExpired: () async {},
                onOpenProductId: (_) {},
                onContinueShopping: () {},
                onCheckout: (items) => selected = items,
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<IconButton>(
                  find.descendant(
                    of: find.byKey(const ValueKey('cart-increase-11')),
                    matching: find.byType(IconButton),
                  ),
                )
                .onPressed,
            isNull,
          );
          expect(
            tester
                .widget<Checkbox>(find.byKey(const ValueKey('cart-select-12')))
                .onChanged,
            isNull,
          );
          await tester.tap(find.byKey(const ValueKey('cart-shop-2')));
          await tester.pump();
          expect(
            tester
                .widget<FilledButton>(
                  find.widgetWithText(FilledButton, 'Checkout'),
                )
                .onPressed,
            isNull,
          );
          await tester.tap(find.byKey(const ValueKey('cart-select-all')));
          await tester.pump();
          await tester.tap(find.text('Checkout (1)'));
          expect(selected, {'11': 1});
          await tester.tap(find.byKey(const ValueKey('cart-remove-11')));
          await tester.pumpAndSettle();
          await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
          await tester.pumpAndSettle();
          expect(removed, isTrue);
          expect(find.byKey(const ValueKey('cart-select-11')), findsNothing);
          expect(tester.takeException(), isNull);
        },
        () => MockClient((request) async {
          if (request.method == 'DELETE') {
            expect(request.url.path, endsWith('/cart/11'));
            removed = true;
            return response({'cart_count': 1});
          }
          return response({
            'groups': [
              {
                'shop': shop,
                'items': [
                  if (!removed) line('11', stock: 1),
                  line('12', stock: 0),
                ],
              },
            ],
            'cart_count': removed ? 1 : 2,
            'quantity_count': removed ? 1 : 2,
            'unavailable_count': 1,
          });
        }),
      );
    },
  );

  for (final width in [320.0, 390.0, 480.0]) {
    for (final scale in [1.0, 1.5]) {
      testWidgets(
        'cart and checkout fit ${width.toInt()}px at ${scale}x text with keyboard',
        (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await http.runWithClient(
            () async {
              await tester.pumpWidget(
                MaterialApp(
                  theme: AppTheme.light,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!,
                  ),
                  home: BuyerCartPage(
                    token: 'test',
                    onSessionExpired: () async {},
                    onOpenProductId: (_) {},
                    onContinueShopping: () {},
                    onCheckout: (_) {},
                  ),
                ),
              );
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
              expect(find.text('Color: Black · Size: Medium'), findsOneWidget);
              await tester.pumpWidget(const SizedBox());
              await tester.pumpWidget(
                MaterialApp(
                  theme: AppTheme.light,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!,
                  ),
                  home: BuyerCheckoutPage(
                    token: 'test',
                    items: const {'11': 2},
                    onSessionExpired: () async {},
                    onOrderPlaced: () {},
                  ),
                ),
              );
              await tester.pumpAndSettle();
              expect(find.text('Delivery Address'), findsOneWidget);
              expect(find.textContaining('Laravel'), findsNothing);
              expect(tester.takeException(), isNull);
              await tester.scrollUntilVisible(
                find.byKey(const ValueKey('seller-note-2')),
                220,
                scrollable: find.byType(Scrollable).first,
              );
              await tester.pumpAndSettle();
              await tester.enterText(
                find.byKey(const ValueKey('seller-note-2')),
                'Please pack carefully',
              );
              tester.view.viewInsets = const FakeViewPadding(bottom: 260);
              await tester.pumpAndSettle();
              expect(
                tester
                    .getBottomLeft(
                      find.widgetWithText(FilledButton, 'Place Order'),
                    )
                    .dy,
                lessThanOrEqualTo(640),
              );
              expect(tester.takeException(), isNull);
              tester.view.resetViewInsets();
            },
            () => MockClient(
              (request) async => request.url.path.endsWith('/cart')
                  ? response({
                      'groups': [
                        {
                          'shop': shop,
                          'items': [
                            line('11')..addAll({
                              'price': 12345.67,
                              'line_total': 12345.67,
                            }),
                          ],
                        },
                      ],
                      'cart_count': 1,
                      'quantity_count': 1,
                      'vouchers': [
                        {
                          'code': 'SAVE',
                          'title': 'A long available shop voucher title',
                          'description': 'Save on your next purchase',
                        },
                      ],
                    })
                  : response(preview()),
            ),
          );
        },
      );
    }
  }

  testWidgets(
    'checkout recalculates courier totals and sends one order for the selected cart lines',
    (tester) async {
      var courier = 3;
      var placed = 0;
      final pending = Completer<http.Response>();
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.light,
              home: BuyerCheckoutPage(
                token: 'test',
                items: const {'11': 2},
                onSessionExpired: () async {},
                onOrderPlaced: () {},
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.ensureVisible(
            find.text('ShopHop Nationwide Logistics with a long company name'),
          );
          await tester.pumpAndSettle();
          await tester.tap(
            find.text('ShopHop Nationwide Logistics with a long company name'),
          );
          await tester.pumpAndSettle();
          expect(courier, 4);
          expect(find.text('₱1480.00'), findsWidgets);
          final place = tester
              .widget<FilledButton>(
                find.byKey(const ValueKey('place-order-button')),
              )
              .onPressed!;
          place();
          place();
          await tester.pumpAndSettle();
          expect(find.text('Place order?'), findsOneWidget);
          await tester.tap(
            find.widgetWithText(FilledButton, 'Place Order').last,
          );
          await tester.pump();
          expect(placed, 1);
          final button = find.byKey(const ValueKey('place-order-button'));
          expect(tester.widget<FilledButton>(button).onPressed, isNull);
          pending.complete(
            response({
              'checkout_group_id': 'test',
              'order_ids': [100],
              'grand_total': 1480,
              'payment_method': 'cod',
              'cart_count': 0,
            }),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          expect(find.text('Order placed!'), findsOneWidget);
          await tester.tap(find.text('View My Orders'));
          await tester.pumpAndSettle();
          expect(placed, 1);
          expect(tester.takeException(), isNull);
        },
        () => MockClient((request) async {
          final body = jsonDecode(request.body) as Map;
          expect(body['items'], {
            '11': {'quantity': 2},
          });
          if (request.url.path.endsWith('/place-order')) {
            placed++;
            expect(body['logistics_partner'], {'2': 4});
            expect(body['payment_method'], 'cod');
            return pending.future;
          }
          courier =
              (body['logistics_partner'] as Map?)?['2'] as int? ?? courier;
          return response(
            preview(courier: courier, shipping: courier == 4 ? 80 : 60),
          );
        }),
      );
    },
  );
}
