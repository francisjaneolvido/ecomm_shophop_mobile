import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shophop/core/session/auth_session_service.dart';
import 'package:shophop/features/rider/data/models/rider_cod_overview.dart';
import 'package:shophop/features/rider/data/services/rider_delivery_service.dart';
import 'package:shophop/features/rider/presentation/screens/rider_cod_remittance_screen.dart';
import 'package:shophop/features/rider/presentation/screens/rider_transit_earnings_screen.dart';

http.Response response(Map<String, dynamic> data) => http.Response(
  jsonEncode({'success': true, 'message': 'Loaded', 'data': data}),
  200,
  headers: {'content-type': 'application/json'},
);

void main() {
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await AuthSessionService.clearSession();
    await AuthSessionService.saveSession(
      token: 'rider-token',
      email: 'rider@test.example',
      accountType: 'rider',
      rememberMe: false,
    );
  });

  tearDown(() async => AuthSessionService.clearSession());

  test('COD overview preserves server amounts and signed centavo history', () {
    final overview = RiderCodOverview.fromJson({
      'summary': {
        'collected': '1100.00',
        'remitted': '1050.00',
        'outstanding': '50.00',
        'discrepancies': 1,
      },
      'collections': [
        {'order_id': 12, 'amount': '1100.00'},
      ],
      'batches': [
        {'difference_minor': -5000},
      ],
    });
    expect(overview.outstanding, '50.00');
    expect(overview.collected, '1100.00');
    expect(overview.discrepancies, 1);
    expect(RiderCodOverview.minorDisplay(-5000), '-50.00');
    expect(RiderCodOverview.minorDisplay(2000), '20.00');
    expect(RiderCodOverview.minorDisplay(null), 'Pending');
  });

  test(
    'batch API sends authenticated decimal cash per order without earnings deductions',
    () async {
      await http.runWithClient(
        () async {
          final result = await RiderDeliveryService.submitCodBatch(
            token: 'rider-token',
            facilityId: 3,
            idempotencyKey: 'stable-key',
            reference: 'RECEIPT-1100',
            items: [
              {'collection_id': 1, 'amount': '1100.00'},
              {'collection_id': 2, 'amount': '750.00'},
            ],
          );
          expect(result.success, isTrue);
        },
        () => MockClient((request) async {
          expect(request.url.path, endsWith('/rider/cod/batches'));
          expect(request.headers['Authorization'], 'Bearer rider-token');
          final body = jsonDecode(request.body) as Map;
          expect(body['idempotency_key'], 'stable-key');
          expect(body['items'], [
            {'collection_id': 1, 'amount': '1100.00'},
            {'collection_id': 2, 'amount': '750.00'},
          ]);
          expect(body.containsKey('earnings'), isFalse);
          return response({});
        }),
      );
    },
  );

  testWidgets(
    'COD screen renders loading then shortage and immutable receipt history',
    (tester) async {
      final pending = Completer<http.Response>();
      await http.runWithClient(() async {
        await tester.pumpWidget(
          const MaterialApp(home: RiderCodRemittanceScreen()),
        );
        await tester.pump();
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        pending.complete(
          response({
            'summary': {
              'collected': '1100.00',
              'remitted': '1050.00',
              'outstanding': '50.00',
              'discrepancies': 1,
            },
            'batches': [
              {
                'reference': 'BATCH-1100',
                'status': 'discrepancy',
                'sorting_center_id': 3,
                'expected_minor': 110000,
                'submitted_minor': 105000,
                'verified_minor': 105000,
                'difference_minor': -5000,
                'receipt_reference': 'RECEIPT-1',
                'created_at': '2026-11-09 09:00',
                'items': [
                  {'cod_settlement_id': 1, 'submitted_minor': 105000},
                ],
              },
            ],
          }),
        );
        await tester.pumpAndSettle();
        expect(find.text('Outstanding cash: ₱50.00'), findsOneWidget);
        await tester.scrollUntilVisible(find.text('BATCH-1100'), 200);
        expect(find.text('BATCH-1100'), findsOneWidget);
        expect(find.text('Difference -50.00'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      }, () => MockClient((request) => pending.future));
    },
  );

  testWidgets(
    'COD API error leaves refresh available and never invents a successful receipt',
    (tester) async {
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            const MaterialApp(home: RiderCodRemittanceScreen()),
          );
          await tester.pumpAndSettle();
          expect(find.text('Cash records unavailable'), findsOneWidget);
          expect(find.byTooltip('Refresh'), findsOneWidget);
          expect(find.text('Confirm counted cash receipt'), findsNothing);
          await tester.pumpWidget(const SizedBox.shrink());
        },
        () => MockClient(
          (_) async => http.Response(
            jsonEncode({
              'success': false,
              'message': 'Cash records unavailable',
            }),
            503,
          ),
        ),
      );
    },
  );

  testWidgets('cash handover form submits full COD to its chosen facility', (
    tester,
  ) async {
    var submissions = 0;
    await http.runWithClient(
      () async {
        await tester.pumpWidget(
          const MaterialApp(home: RiderCodRemittanceScreen()),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byType(CheckboxListTile));
        await tester.pump();
        await tester.ensureVisible(find.text('Hand over selected COD'));
        await tester.tap(find.text('Hand over selected COD'));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(DropdownButtonFormField<int>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Receiving branch').last);
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).first, 'RECEIPT-1100');
        await tester.ensureVisible(find.text('Submit handover'));
        await tester.tap(find.text('Submit handover'));
        await tester.pumpAndSettle();
        expect(submissions, 1);
        await tester.pumpWidget(const SizedBox.shrink());
      },
      () => MockClient((request) async {
        if (request.method == 'POST') {
          submissions++;
          final body = jsonDecode(request.body) as Map;
          expect(body['sorting_center_id'], 3);
          expect(body['reference'], 'RECEIPT-1100');
          expect(body['items'], [
            {'collection_id': 1, 'amount': '1100.00'},
          ]);
          return response({});
        }
        return response({
          'summary': {
            'collected': '1100.00',
            'remitted': '0.00',
            'outstanding': '1100.00',
            'discrepancies': 0,
          },
          'collections': [
            {
              'collection_id': 1,
              'order_id': 12,
              'amount': '1100.00',
              'received_amount': '0.00',
              'outstanding': '1100.00',
              'status': 'collected',
              'can_remit': true,
            },
          ],
          'facilities': [
            {'id': 3, 'name': 'Receiving branch'},
          ],
        });
      }),
    );
  });

  testWidgets('rider earnings display independent partner compensation', (
    tester,
  ) async {
    await http.runWithClient(
      () async {
        await tester.pumpWidget(
          const MaterialApp(home: RiderTransitEarningsScreen()),
        );
        await tester.pumpAndSettle();
        expect(find.text('₱25.00'), findsWidgets);
        expect(
          find.textContaining('Earnings never reduce collected COD'),
          findsOneWidget,
        );
        expect(find.text('delivery:12'), findsWidgets);
        await tester.pumpWidget(const SizedBox.shrink());
      },
      () => MockClient(
        (_) async => response({
          'pending': 0,
          'available': 0,
          'paid': 0,
          'entries': [],
          'partner_compensation': {
            'pending': '25.00',
            'available': '0.00',
            'paid': '0.00',
            'entries': [
              {
                'event_key': 'delivery:12',
                'kind': 'delivery:12',
                'amount': '25.00',
                'status': 'pending',
              },
            ],
          },
        }),
      ),
    );
  });
}
