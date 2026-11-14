import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shophop/core/theme/app_theme.dart';
import 'package:shophop/features/buyer/data/services/buyer_catalog_service.dart';
import 'package:shophop/features/buyer/presentation/pages/buyer_home_page.dart';
import 'package:shophop/features/buyer/presentation/pages/buyer_catalog_page.dart';
import 'package:shophop/features/buyer/presentation/pages/buyer_product_detail_page.dart';
import 'package:shophop/features/buyer/presentation/widgets/buyer_product_card.dart';

Map<String, dynamic> product(int id, String name) => {
  'id': id,
  'name': name,
  'category': 'Home and Garden',
  'price': 169.99,
  'original_price': 199.99,
  'discount_percent': 15,
  'stock': 10,
  'seller': {'business_name': 'Test Shop'},
};
final categories = [
  {
    'name': 'Pet Supplies',
    'slug': 'pet-supplies',
    'icon': 'paw-print',
    'subcategories': ['Dog Food & Treats'],
    'product_count': 1,
  },
  {
    'name': 'Home and Garden',
    'slug': 'home-and-garden',
    'icon': 'sofa',
    'subcategories': ['Furniture & Decor'],
    'product_count': 2,
  },
];
http.Response response(dynamic data) => http.Response(
  jsonEncode({'success': true, 'data': data}),
  200,
  headers: {'content-type': 'application/json'},
);
Map<String, dynamic> listing(List<Map<String, dynamic>> products) => {
  'items': products,
  'pagination': {
    'current_page': 1,
    'last_page': 1,
    'total': products.length,
    'has_more': false,
  },
};
Map<String, dynamic> home(String name) => {
  'categories': categories,
  'cart_count': 2,
  'banners': [
    {
      'eyebrow': 'WELCOME TO SHOPHOP',
      'heading': 'Everything you love, just a hop away.',
      'description':
          'Discover electronics, everyday essentials, home picks, and more from ShopHop sellers.',
      'target': 'categories',
      'link_label': 'Shop Categories',
    },
  ],
  'deal_products': [product(1, 'Seller discount')],
  'top_products': [product(2, 'Top product')],
  'discover_products': [product(3, name)],
};

void main() {
  testWidgets(
    'Home keeps category product shortcuts without a directory and refreshes products',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var name = 'Original listing';
      var homeCalls = 0;
      var searches = 0;
      String? selectedCategory;
      var messages = 0;
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.light,
              home: Scaffold(
                body: BuyerHomePage(
                  token: 'test',
                  onSessionExpired: () async {},
                  onOpenSearch: () => searches++,
                  onOpenCategory: (category) => selectedCategory = category.slug,
                  onOpenProduct: (_) {},
                  onOpenCart: () {},
                  onOpenOrders: () {},
                  onOpenMessages: () => messages++,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip('Messages'));
          expect(messages, 1);
          expect(
            find.text('Everything you love, just a hop away.'),
            findsOneWidget,
          );
          expect(find.text('All Categories'), findsNothing);
          await tester.tap(find.text('Shop now'));
          expect(searches, 1);
          await tester.scrollUntilVisible(find.text('Pet Supplies'), 180,
            scrollable: find.byType(Scrollable).first);
          await tester.tap(find.text('Pet Supplies'));
          expect(selectedCategory, 'pet-supplies');
          await tester.scrollUntilVisible(
            find.text('Daily Discover'),
            300,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.scrollUntilVisible(
            find.text('Original listing'),
            180,
            scrollable: find.byType(Scrollable).first,
          );
          name = 'Approved seller update';
          await tester.pump(const Duration(seconds: 15));
          await tester.pumpAndSettle();
          expect(homeCalls, greaterThanOrEqualTo(2));
          expect(find.text('Approved seller update'), findsOneWidget);
          expect(find.text('Original listing'), findsNothing);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
        () => MockClient((request) async {
          homeCalls++;
          return response(home(name));
        }),
      );
    },
  );

  testWidgets('category product listing retains subcategory filtering', (tester) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(theme: AppTheme.light,
        home: BuyerCatalogPage(token: 'test', category: BuyerCategoryData.fromJson(categories[1]),
          initialSubcategory: 'Furniture & Decor', onSessionExpired: () async {}, onOpenProduct: (_) {})));
      await tester.pumpAndSettle();
      expect(find.text('Available desk lamp'), findsOneWidget);
      expect(find.text('Browse Categories'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }, () => MockClient((request) async {
      expect(request.url.queryParameters['category'], 'home-and-garden');
      expect(request.url.queryParameters['subcategory'], 'Furniture & Decor');
      return response(listing([product(1, 'Available desk lamp')]));
    }));
  });

  testWidgets('Search ignores an older response after the query changes', (
    tester,
  ) async {
    final stale = Completer<http.Response>();
    await http.runWithClient(
      () async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: BuyerCatalogPage(
              token: 'test',
              onSessionExpired: () async {},
              onOpenProduct: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'lamp');
        await tester.pump(const Duration(milliseconds: 460));
        await tester.enterText(find.byType(TextField), 'chair');
        await tester.pump(const Duration(milliseconds: 460));
        await tester.pumpAndSettle();
        expect(find.text('Current chair'), findsOneWidget);
        stale.complete(response(listing([product(1, 'Stale lamp')])));
        await tester.pumpAndSettle();
        expect(find.text('Stale lamp'), findsNothing);
        expect(find.text('Current chair'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      },
      () => MockClient((request) async {
        final query = request.url.queryParameters['q'];
        if (query == 'lamp') return stale.future;
        return response(
          listing([
            product(2, query == 'chair' ? 'Current chair' : 'Initial product'),
          ]),
        );
      }),
    );
  });

  testWidgets(
    'Product card fits enlarged text and keeps Like separate from opening',
    (tester) async {
      var opens = 0;
      var likes = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: Builder(
                builder: (context) => Scaffold(
                  body: Center(
                    child: SizedBox(
                      width: 144,
                      height: BuyerProductCard.extent(context, 144),
                      child: BuyerProductCard(
                        product: BuyerProductData.fromJson(
                          product(
                            1,
                            'Long product name that wraps across lines',
                          ),
                        ),
                        onTap: () => opens++,
                        onLike: () => likes++,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('\u20b1169.99'), findsOneWidget);
      await tester.tap(find.byType(IconButton));
      expect(likes, 1);
      expect(opens, 0);
      await tester.tap(find.text('Long product name that wraps across lines'));
      expect(opens, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Unavailable product photo preserves the card and its actions', (
    tester,
  ) async {
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SizedBox(
            width: 180,
            height: 330,
            child: BuyerProductCard(
              product: BuyerProductData.fromJson({
                ...product(1, 'Photo failure product'),
                'image': 'https://example.invalid/missing.jpg',
              }),
              onTap: () => opened = true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Photo failure product'), findsOneWidget);
    expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    await tester.tap(find.text('Photo failure product'));
    expect(opened, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Detail polling clamps quantity and disables unavailable variants',
    (tester) async {
      var stock = 3;
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.light,
              home: BuyerProductDetailPage(
                token: 'test',
                productId: 1,
                onSessionExpired: () async {},
                onOpenProduct: (_) {},
                onOpenSearch: () {},
                onOpenCart: ({String? buyNowLineKey}) {},
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('Variation & quantity'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Variation & quantity'));
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip('Increase quantity'));
          await tester.tap(find.text('Confirm selection'));
          await tester.pumpAndSettle();
          expect(find.text('White / Qty: 2'), findsOneWidget);
          stock = 1;
          await tester.pump(const Duration(seconds: 15));
          await tester.pumpAndSettle();
          expect(find.text('White / Qty: 1'), findsOneWidget);
          stock = 0;
          await tester.pump(const Duration(seconds: 15));
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<FilledButton>(
                  find.widgetWithText(FilledButton, 'Buy Now'),
                )
                .onPressed,
            isNull,
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
        () => MockClient(
          (_) async => response({
            ...product(1, 'Variant lamp'),
            'has_variants': true,
            'variants': [
              {
                'id': 1,
                'name': 'White',
                'label': 'White',
                'price': 169.99,
                'stock': stock,
                'status': 'active',
                'in_stock': stock > 0,
              },
            ],
          }),
        ),
      );
    },
  );

  testWidgets(
    'Compact review previews retain seller replies and open more reviews',
    (tester) async {
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.light,
              home: BuyerProductDetailPage(
                token: 'test',
                productId: 1,
                onSessionExpired: () async {},
                onOpenProduct: (_) {},
                onOpenSearch: () {},
                onOpenCart: ({String? buyNowLineKey}) {},
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('View reviews'));
          await tester.pumpAndSettle();
          expect(find.text('View reviews').hitTestable(), findsOneWidget);
          expect(find.text('Third review comment'), findsNothing);
          expect(
            find.text('Seller reply: Thank you for your feedback.'),
            findsOneWidget,
          );
          await tester.tap(find.text('View reviews'));
          await tester.pumpAndSettle();
          expect(find.text('Third review comment'), findsOneWidget);
          expect(
            find.descendant(
              of: find.byType(DraggableScrollableSheet),
              matching: find.text('Seller reply: Thank you for your feedback.'),
            ),
            findsOneWidget,
          );
          await tester.tap(find.byTooltip('Close reviews'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
        () => MockClient(
          (_) async => response({
            ...product(1, 'Reviewed lamp'),
            'reviews': 3,
            'rating': 4.7,
            'reviews_data': [
              {
                'id': 1,
                'buyer_name': 'Buyer A',
                'rating': 5,
                'comment': 'First review comment',
                'seller_reply': 'Thank you for your feedback.',
              },
              {
                'id': 2,
                'buyer_name': 'Buyer B',
                'rating': 4,
                'comment': 'Second review comment',
              },
              {
                'id': 3,
                'buyer_name': 'Buyer C',
                'rating': 5,
                'comment': 'Third review comment',
              },
            ],
            'rating_breakdown': {'5': 2, '4': 1},
          }),
        ),
      );
    },
  );

  testWidgets(
    'Details keeps variant selection and Buy Now connected to the cart',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Map<String, dynamic>? added;
      String? openedLine;
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.light,
              home: BuyerProductDetailPage(
                token: 'test',
                productId: 1,
                onSessionExpired: () async {},
                onOpenProduct: (_) {},
                onOpenSearch: () {},
                onOpenCart: ({String? buyNowLineKey}) =>
                    openedLine = buyNowLineKey,
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('Shop'));
          await tester.pumpAndSettle();
          expect(find.text('Shop details'), findsOneWidget);
          await tester.tap(find.byTooltip('Close shop details'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Chat'));
          await tester.pumpAndSettle();
          expect(
            find.text('Say hello to start the conversation.'),
            findsOneWidget,
          );
          await tester.pageBack();
          await tester.pumpAndSettle();
          expect(find.byTooltip('Add to Cart'), findsOneWidget);
          await tester.ensureVisible(find.text('Variation & quantity'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Variation & quantity'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Blue'));
          await tester.tap(find.byTooltip('Increase quantity'));
          await tester.tap(find.text('Confirm selection'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Buy Now'));
          await tester.pumpAndSettle();
          expect(added?['product_id'], 1);
          expect(added?['variant_id'], 12);
          expect(added?['qty'], 2);
          expect(openedLine, 'line-1');
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
        () => MockClient((request) async {
          if (request.url.path.endsWith('/chat/open')) {
            expect(jsonDecode(request.body)['seller_id'], 99);
            return http.Response(
              jsonEncode({'ok': true, 'chat_id': 4}),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          if (request.url.path.contains('/chat/')) {
            return http.Response(
              jsonEncode({'ok': true, 'messages': []}),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          if (request.method == 'POST') {
            added = jsonDecode(request.body) as Map<String, dynamic>;
            return response({'cart_count': 1, 'line_key': 'line-1'});
          }
          return response({
            ...product(1, 'Variant lamp'),
            'seller': {'user_id': 99, 'business_name': 'Test Shop'},
            'has_variants': true,
            'variants': [
              {
                'id': 11,
                'name': 'White',
                'label': 'White',
                'price': 169.99,
                'stock': 2,
                'status': 'active',
                'in_stock': true,
              },
              {
                'id': 12,
                'name': 'Blue',
                'label': 'Blue',
                'price': 180,
                'stock': 3,
                'status': 'active',
                'in_stock': true,
              },
            ],
          });
        }),
      );
    },
  );
}
