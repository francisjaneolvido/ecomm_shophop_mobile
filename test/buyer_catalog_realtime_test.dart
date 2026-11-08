import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shophop/features/buyer/presentation/pages/buyer_catalog_page.dart';

void main() {
  testWidgets(
    'visible buyer catalog updates after polling without a manual refresh',
    (tester) async {
      var name = 'Original lamp';
      var calls = 0;
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            MaterialApp(
              home: BuyerCatalogPage(
                token: 'test-token',
                onSessionExpired: () async {},
                onOpenProduct: (_) {},
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('Original lamp'), findsOneWidget);
          name = 'Admin approved update';
          await tester.pump(const Duration(seconds: 15));
          await tester.pumpAndSettle();
          expect(calls, 2);
          expect(find.text('Admin approved update'), findsOneWidget);
          expect(find.text('Original lamp'), findsNothing);
          await tester.pumpWidget(const SizedBox());
        },
        () => MockClient((request) async {
          calls++;
          expect(request.headers['Authorization'], 'Bearer test-token');
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'items': [
                  {'id': 1, 'name': name, 'price': 100, 'stock': 10},
                ],
                'pagination': {
                  'current_page': 1,
                  'last_page': 1,
                  'per_page': 20,
                  'total': 1,
                },
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
    },
  );

  testWidgets('background network failure preserves the visible catalog', (
    tester,
  ) async {
    var fail = false;
    await http.runWithClient(
      () async {
        await tester.pumpWidget(
          MaterialApp(
            home: BuyerCatalogPage(
              token: 'test-token',
              onSessionExpired: () async {},
              onOpenProduct: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Saved lamp'), findsOneWidget);
        fail = true;
        await tester.pump(const Duration(seconds: 15));
        await tester.pumpAndSettle();
        expect(find.text('Saved lamp'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      },
      () => MockClient(
        (request) async => fail
            ? http.Response('{"message":"Offline"}', 503)
            : http.Response(
                jsonEncode({
                  'success': true,
                  'data': {
                    'items': [
                      {
                        'id': 1,
                        'name': 'Saved lamp',
                        'price': 100,
                        'stock': 10,
                      },
                    ],
                    'pagination': {
                      'current_page': 1,
                      'last_page': 1,
                      'per_page': 20,
                      'total': 1,
                    },
                  },
                }),
                200,
              ),
      ),
    );
  });
}
