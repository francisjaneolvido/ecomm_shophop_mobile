import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shophop/core/session/auth_session_service.dart';
import 'package:shophop/features/rider/data/models/rider_cod_overview.dart';
import 'package:shophop/features/rider/presentation/screens/rider_cod_remittance_screen.dart';

void main() {
  test('submitted cash is pending until independently verified', () {
    expect(
      RiderCodOverview.receiptStatus({'status': 'remitted'}),
      'Awaiting verification',
    );
    expect(
      RiderCodOverview.receiverDescription({'status': 'remitted'}),
      contains('not recorded'),
    );
    expect(
      RiderCodOverview.receiptStatus({
        'status': 'reconciled',
        'receipt_verified': true,
      }),
      'Receipt verified',
    );
    expect(
      RiderCodOverview.receiptStatus({
        'status': 'discrepancy',
        'receipt_verified': true,
      }),
      'Under review',
    );
  });

  testWidgets(
    'handover requires receiving branch and reference before submitting cash',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      await AuthSessionService.saveSession(
        token: 'rider-test',
        email: 'rider@example.test',
        accountType: 'rider',
        rememberMe: false,
      );
      tester.view.physicalSize = const Size(320, 950);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final submissions = <Map<String, dynamic>>[];
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            const MaterialApp(
              home: RiderCodRemittanceScreen(initialCollectionId: 10),
            ),
          );
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('Hand over selected COD'));
          await tester.tap(find.text('Hand over selected COD'));
          await tester.pumpAndSettle();
          expect(submissions, isEmpty);
          await tester.tap(find.text('Submit handover'));
          await tester.pumpAndSettle();
          expect(submissions, isEmpty);
          expect(find.textContaining('Choose a facility'), findsOneWidget);
          await tester.tap(find.byType(DropdownButtonFormField<int>));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Calamba Branch').last);
          await tester.pumpAndSettle();
          await tester.enterText(
            find.widgetWithText(TextField, 'Receipt / evidence reference'),
            'CASH-1005',
          );
          await tester.ensureVisible(find.text('Submit handover'));
          await tester.tap(find.text('Submit handover'));
          await tester.pumpAndSettle();
          expect(submissions, hasLength(1));
          expect(submissions.single['sorting_center_id'], 3);
          expect(submissions.single['reference'], 'CASH-1005');
          expect(submissions.single['items'], [
            {'collection_id': 10, 'amount': '1005.00'},
          ]);
          expect(tester.takeException(), isNull);
        },
        () => MockClient((request) async {
          if (request.method == 'POST') {
            submissions.add(jsonDecode(request.body) as Map<String, dynamic>);
          }
          return http.Response(
            jsonEncode({
              'success': true,
              'message': 'Handover submitted; awaiting receipt.',
              'data': {
                'summary': {
                  'collected': '1005.00',
                  'outstanding': '1005.00',
                  'remitted': '0.00',
                },
                'facilities': [
                  {'id': 3, 'name': 'Calamba Branch'},
                ],
                'collections': [
                  {
                    'collection_id': 10,
                    'order_id': 1,
                    'amount': '1005.00',
                    'received_amount': '0.00',
                    'outstanding': '1005.00',
                    'status': 'collected',
                    'can_remit': true,
                  },
                ],
                'batches': [],
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
    },
  );
}
