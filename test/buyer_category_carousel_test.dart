import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shophop/core/theme/app_theme.dart';
import 'package:shophop/features/buyer/data/services/buyer_catalog_service.dart';
import 'package:shophop/features/buyer/presentation/pages/buyer_catalog_page.dart';
import 'package:shophop/features/buyer/presentation/pages/buyer_home_page.dart';

// Synthetic API records: production category names/order live only in Laravel.
List<Map<String, dynamic>> categoryRecords(int count) => List.generate(
  count,
  (i) => {
    'name': i == 1 ? 'Electronics and Gadgets' : 'Department ${i + 1}',
    'slug': 'department-${i + 1}',
    'icon': 'shopping-bag',
    'subcategories': ['Section ${i + 1}'],
    'product_count': 0,
  },
);

http.Response homeResponse(List<Map<String, dynamic>> categories) =>
    http.Response(
      jsonEncode({
        'success': true,
        'data': {'categories': categories},
      }),
      200,
      headers: {'content-type': 'application/json'},
    );

Widget homeApp({
  double scale = 1,
  ValueChanged<BuyerCategoryData>? onCategory,
}) => MaterialApp(
  theme: AppTheme.light,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: Scaffold(
    body: BuyerHomePage(
      token: 'test',
      onSessionExpired: () async {},
      onOpenSearch: () {},
      onOpenCategory: onCategory ?? (_) {},
      onOpenProduct: (_) {},
      onOpenCart: () {},
      onOpenOrders: () {},
      onOpenMessages: () {},
    ),
  ),
);

Finder get carousel => find.byKey(const ValueKey('buyer-category-carousel'));
Finder get categoryScroll =>
    find.descendant(of: carousel, matching: find.byType(Scrollable));
Finder categoryItem(String slug) =>
    find.byKey(ValueKey('buyer-category-$slug'));

void phoneSize(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  for (final width in [320.0, 390.0, 480.0]) {
    for (final scale in [1.0, 1.8]) {
      testWidgets(
        'all API categories are swipeable and compact at ${width}px / ${scale}x',
        (tester) async {
          phoneSize(tester, width);
          final records = categoryRecords(14);
          final selected = <BuyerCategoryData>[];
          await http.runWithClient(
            () async {
              await tester.pumpWidget(
                homeApp(scale: scale, onCategory: selected.add),
              );
              await tester.pumpAndSettle();
              expect(carousel, findsOneWidget);
              expect(
                tester.getSize(carousel).height,
                lessThan(scale == 1 ? 125 : 180),
              );
              expect(find.text('All Categories'), findsNothing);
              for (final record in records) {
                final item = categoryItem(record['slug'] as String);
                await tester.scrollUntilVisible(
                  item,
                  180,
                  scrollable: categoryScroll,
                );
                await tester.tap(item);
                await tester.pump();
                expect(tester.takeException(), isNull);
              }
              expect(
                selected.map((c) => c.slug),
                records.map((c) => c['slug']),
              );
              expect(
                selected.map((c) => c.name),
                records.map((c) => c['name']),
              );
              expect(selected.last.subcategories, ['Section 14']);
              // Horizontal gestures can return to the beginning, and Home still scrolls vertically.
              await tester.drag(categoryScroll, const Offset(5000, 0));
              await tester.pumpAndSettle();
              expect(
                categoryItem('department-1').hitTestable(),
                findsOneWidget,
              );
              final verticalScroll = find
                  .descendant(
                    of: find.byType(CustomScrollView),
                    matching: find.byType(Scrollable),
                  )
                  .first;
              await tester.drag(verticalScroll, const Offset(0, -250));
              await tester.pumpAndSettle();
              expect(
                tester.state<ScrollableState>(verticalScroll).position.pixels,
                greaterThan(0),
              );
              expect(tester.takeException(), isNull);
              await tester.pumpWidget(const SizedBox());
            },
            () => MockClient((request) async {
              expect(request.url.path, endsWith('/buyer/home'));
              return homeResponse(records);
            }),
          );
        },
      );
    }
  }

  testWidgets('empty categories have a retry that loads the backend list', (
    tester,
  ) async {
    var calls = 0;
    await http.runWithClient(
      () async {
        await tester.pumpWidget(homeApp());
        await tester.pumpAndSettle();
        expect(find.text('No categories available right now.'), findsOneWidget);
        await tester.tap(find.text('Refresh categories'));
        await tester.pumpAndSettle();
        expect(categoryItem('department-1'), findsOneWidget);
        expect(calls, 2);
        await tester.pumpWidget(const SizedBox());
      },
      () => MockClient(
        (_) async => homeResponse(++calls == 1 ? [] : categoryRecords(14)),
      ),
    );
  });

  testWidgets(
    'loading and network error do not invent categories and retry recovers',
    (tester) async {
      final pending = Completer<http.Response>();
      var calls = 0;
      await http.runWithClient(
        () async {
          await tester.pumpWidget(homeApp());
          expect(find.byType(CircularProgressIndicator), findsOneWidget);
          pending.complete(http.Response('{"message":"Offline"}', 503));
          await tester.pumpAndSettle();
          expect(find.text('Unable to load ShopHop'), findsOneWidget);
          expect(carousel, findsNothing);
          await tester.tap(find.text('Try again'));
          await tester.pumpAndSettle();
          expect(categoryItem('department-1'), findsOneWidget);
          await tester.pumpWidget(const SizedBox());
        },
        () => MockClient(
          (_) => ++calls == 1
              ? pending.future
              : Future.value(homeResponse(categoryRecords(14))),
        ),
      );
    },
  );

  testWidgets(
    'failed background refresh is visible and retry reflects changed backend categories',
    (tester) async {
      var calls = 0;
      await http.runWithClient(
        () async {
          await tester.pumpWidget(homeApp());
          await tester.pumpAndSettle();
          await tester.pump(const Duration(seconds: 15));
          await tester.pumpAndSettle();
          expect(
            find.textContaining("Couldn't refresh categories and products"),
            findsOneWidget,
          );
          await tester.tap(find.text('Try again'));
          await tester.pumpAndSettle();
          expect(find.text('Updated backend name'), findsOneWidget);
          expect(find.text('Department 1'), findsNothing);
          await tester.scrollUntilVisible(
            categoryItem('department-15'),
            200,
            scrollable: categoryScroll,
          );
          expect(categoryItem('department-15').hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
        () => MockClient((_) async {
          calls++;
          if (calls == 2) return http.Response('{"message":"Offline"}', 503);
          final records = categoryRecords(calls > 2 ? 15 : 14);
          if (calls > 2) records[0]['name'] = 'Updated backend name';
          return homeResponse(records);
        }),
      );
    },
  );

  testWidgets(
    'last category opens filtered catalog and its zero-product state',
    (tester) async {
      phoneSize(tester, 390);
      final navigator = GlobalKey<NavigatorState>();
      String? filter;
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            MaterialApp(
              navigatorKey: navigator,
              theme: AppTheme.light,
              home: Scaffold(
                body: BuyerHomePage(
                  token: 'test',
                  onSessionExpired: () async {},
                  onOpenSearch: () {},
                  onOpenCategory: (category) => navigator.currentState!.push(
                    MaterialPageRoute<void>(
                      builder: (_) => BuyerCatalogPage(
                        token: 'test',
                        category: category,
                        onSessionExpired: () async {},
                        onOpenProduct: (_) {},
                      ),
                    ),
                  ),
                  onOpenProduct: (_) {},
                  onOpenCart: () {},
                  onOpenOrders: () {},
                  onOpenMessages: () {},
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final last = categoryItem('department-14');
          await tester.scrollUntilVisible(
            last,
            220,
            scrollable: categoryScroll,
          );
          await tester.tap(last);
          await tester.pumpAndSettle();
          expect(filter, 'department-14');
          expect(find.text('No products found'), findsOneWidget);
          expect(find.text('Department 14'), findsWidgets);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
        () => MockClient((request) async {
          if (request.url.path.endsWith('/home')) {
            return homeResponse(categoryRecords(14));
          }
          filter = request.url.queryParameters['category'];
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'items': [],
                'pagination': {'current_page': 1, 'last_page': 1, 'total': 0},
              },
            }),
            200,
          );
        }),
      );
    },
  );
}
