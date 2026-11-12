import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shophop/core/theme/app_theme.dart';
import 'package:shophop/features/buyer/presentation/pages/buyer_orders_page.dart';

Map<String, dynamic> order(int id, String status) => {
  'id': id,
  'display_id': 'SHP-$id',
  'seller_name': 'Test Shop',
  'status': status,
  'status_label': status == 'completed' ? 'Completed' : 'Out for Delivery',
  'status_note': 'Recorded order status.',
  'total_amount': 1005,
  'payment_method': 'cod',
  'tracking_code': 'PARCEL-$id',
  'delivery_address': 'Calamba, Laguna',
  'can_confirm_receipt': false,
  'items': [
    {'name': 'Pedigree', 'variant': 'Standard', 'quantity': 2, 'price': 180},
  ],
  'timeline': [
    {'label': 'Order placed', 'at': '2026-11-12T01:46:00Z'},
  ],
};

http.Response response(
  List<Map<String, dynamic>> orders, {
  bool more = false,
}) => http.Response(
  jsonEncode({
    'success': true,
    'data': {
      'orders': orders,
      'has_more': more,
      'status_counts': {
        'all': 23,
        'to-ship': 0,
        'to-receive': 1,
        'completed': 22,
        'cancelled': 0,
      },
    },
  }),
  200,
  headers: {'content-type': 'application/json'},
);

Widget page({double textScale = 1}) => MaterialApp(
  theme: AppTheme.light,
  home: MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
    child: BuyerOrdersPage(
      token: 'test-token',
      onSessionExpired: () async {},
      onBrowseProducts: () {},
    ),
  ),
);

void main() {
  testWidgets(
    'completed item rating saves stars and comment and refreshes eligibility',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var saved = false;
      var submissions = 0;
      await http.runWithClient(
        () async {
          await tester.pumpWidget(page());
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(find.text('Rate item'), 150);
          await tester.tap(find.text('Rate item'));
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<FilledButton>(
                  find.widgetWithText(FilledButton, 'Submit rating'),
                )
                .onPressed,
            isNull,
          );
          await tester.tap(find.byKey(const ValueKey('rate-star-4')));
          await tester.enterText(find.byType(TextField), 'Good quality');
          await tester.tap(find.text('Submit rating'));
          await tester.pumpAndSettle();
          expect(submissions, 1);
          expect(find.text('Rate your item'), findsNothing);
          await tester.scrollUntilVisible(find.text('★ Your rating: 4/5'), 150);
          expect(find.text('Rate item'), findsNothing);
          expect(tester.takeException(), isNull);
        },
        () => MockClient((request) async {
          if (request.method == 'POST') {
            expect(
              request.url.path,
              '/api/mobile/buyer/orders/1/items/7/review',
            );
            expect(request.headers['authorization'], 'Bearer test-token');
            expect(jsonDecode(request.body), {
              'rating': 4,
              'comment': 'Good quality',
            });
            saved = true;
            submissions++;
            return http.Response('{"success":true,"data":{}}', 200);
          }
          final data = order(1, 'completed');
          (data['items'] as List).first.addAll({
            'id': 7,
            'can_rate': !saved,
            if (saved) 'rating': 4,
          });
          return response([data]);
        }),
      );
    },
  );

  testWidgets(
    'status shortcuts request server filters and view all restores history',
    (tester) async {
      final requests = <Uri>[];
      await http.runWithClient(
        () async {
          await tester.pumpWidget(page());
          await tester.pumpAndSettle();
          expect(find.text('My purchases'), findsOneWidget);
          expect(find.text('To Rate'), findsOneWidget);
          expect(find.text('₱1,005.00'), findsOneWidget);
          await tester.tap(
            find.byKey(const ValueKey('order-filter-to-receive')),
          );
          await tester.pumpAndSettle();
          expect(requests.last.queryParameters['status_group'], 'to-receive');
          expect(find.byKey(const ValueKey('buyer-order-2')), findsOneWidget);
          expect(find.byKey(const ValueKey('buyer-order-1')), findsNothing);
          await tester.tap(find.text('View all'));
          await tester.pumpAndSettle();
          expect(
            requests.last.queryParameters.containsKey('status_group'),
            isFalse,
          );
          expect(find.byKey(const ValueKey('buyer-order-1')), findsOneWidget);
        },
        () => MockClient((request) async {
          requests.add(request.url);
          final filtered =
              request.url.queryParameters['status_group'] == 'to-receive';
          return response([
            order(filtered ? 2 : 1, filtered ? 'to-receive' : 'completed'),
          ]);
        }),
      );
    },
  );

  testWidgets(
    'empty status has a clear recovery and large text does not overflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await http.runWithClient(
        () async {
          await tester.pumpWidget(page(textScale: 1.8));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.tap(
            find.byKey(const ValueKey('order-filter-cancelled')),
          );
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(find.text('View all orders'), 200);
          expect(find.text('No cancelled orders'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
        () => MockClient(
          (request) async => response(
            request.url.queryParameters.containsKey('status_group')
                ? []
                : [order(1, 'completed')],
          ),
        ),
      );
    },
  );

  testWidgets('load more keeps the selected status filter', (tester) async {
    final requests = <Uri>[];
    await http.runWithClient(
      () async {
        await tester.pumpWidget(page());
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('order-filter-completed')));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text('Load more orders'), 250);
        await tester.tap(find.text('Load more orders'));
        await tester.pumpAndSettle();
        expect(requests.last.queryParameters, {
          'page': '2',
          'status_group': 'completed',
        });
      },
      () => MockClient((request) async {
        requests.add(request.url);
        return response([
          order(int.parse(request.url.queryParameters['page']!), 'completed'),
        ], more: request.url.queryParameters['page'] == '1');
      }),
    );
  });
}
