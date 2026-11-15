import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shophop/features/buyer/data/services/buyer_catalog_service.dart';
import 'package:shophop/features/buyer/presentation/pages/buyer_account_page.dart';
import 'package:shophop/features/buyer/presentation/pages/buyer_my_likes_page.dart';
import 'package:shophop/features/buyer/presentation/widgets/buyer_product_card.dart';

BuyerProductData product(int id, {bool video = false}) =>
    BuyerProductData.fromJson({
      'id': id,
      'name': 'A product with a long name that wraps over two lines $id',
      'category': 'Home and Garden',
      'price': 100.5,
      'original_price': 150,
      'discount_percent': 33,
      'stock': 10,
      'rating': id.isEven ? 4.8 : 0,
      'reviews': id.isEven ? 12 : 0,
      'image': '',
      'video_url': video ? 'https://example.test/demo.mp4' : '',
      'media_first': video ? 'video' : 'image',
    });

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets('mixed media masonry has no overflow at text scale $scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var opened = 0;
      final products = List.generate(24, (i) => product(i, video: i.isOdd));
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: Scaffold(
              body: LayoutBuilder(
                builder: (context, constraints) => GridView.builder(
                  gridDelegate: BuyerProductCard.gridDelegate(
                    context,
                    constraints.maxWidth,
                    products,
                  ),
                  itemCount: products.length,
                  itemBuilder: (context, index) => BuyerProductCard(
                    key: ValueKey(index),
                    product: products[index],
                    onTap: () => opened++,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final first = find.byKey(const ValueKey(0));
      final second = find.byKey(const ValueKey(1));
      expect(
        tester.getSize(second).height,
        greaterThan(tester.getSize(first).height),
      );
      final media = find.descendant(
        of: first,
        matching: find.byType(AspectRatio),
      );
      final video = find.descendant(
        of: second,
        matching: find.byType(AspectRatio),
      );
      expect(tester.widget<AspectRatio>(media).aspectRatio, 1);
      expect(tester.widget<AspectRatio>(video).aspectRatio, .75);
      expect(
        find.descendant(of: first, matching: find.text('4.8 (12)')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: second, matching: find.text('No reviews yet')),
        findsOneWidget,
      );
      expect(find.byType(IconButton), findsNothing);
      await tester.tap(first);
      expect(opened, 1);
      await tester.scrollUntilVisible(find.byKey(const ValueKey(23)), 400);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('logout requires confirmation and Cancel keeps the session', (
    tester,
  ) async {
    var loggedOut = 0;
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BuyerAccountPage(
            displayName: 'Buyer',
            token: 'test',
            email: 'buyer@example.test',
            loggingOut: false,
            onLogout: () => loggedOut++,
            onOpenOrders: (_) {},
            onOpenLikes: () {},
            onOpenCart: () {},
          ),
        ),
      ),
    );
    await tester.scrollUntilVisible(find.text('Sign out'), 300);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(loggedOut, 0);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(loggedOut, 0);
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
    await tester.pumpAndSettle();
    expect(loggedOut, 1);
  });

  testWidgets('Manage Likes can remove an unavailable saved product', (
    tester,
  ) async {
    var deletes = 0;
    final client = MockClient((request) async {
      if (request.method == 'DELETE') {
        deletes++;
        return http.Response(
          jsonEncode({
            'data': {'is_liked': false},
          }),
          200,
        );
      }
      return http.Response(
        jsonEncode({
          'data': {
            'count': 1,
            'items': [
              {
                'id': 42,
                'name': 'Unavailable saved product',
                'category': 'Home',
                'stock': 0,
                'price': 100,
                'is_available': false,
              },
            ],
          },
        }),
        200,
      );
    });
    await http.runWithClient(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BuyerMyLikesPage(
              token: 'test',
              onSessionExpired: () async {},
              onOpenSearch: () {},
              onOpenCart: () {},
              onOpenProduct: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(BuyerProductCard), findsOneWidget);
      await tester.tap(find.text('Manage'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Remove'));
      await tester.pumpAndSettle();
      expect(deletes, 1);
      expect(find.byType(BuyerProductCard), findsNothing);
      expect(find.text('Manage Likes'), findsNothing);
    }, () => client);
  });
}
