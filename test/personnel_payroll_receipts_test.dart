import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shophop/shared/widgets/personnel_payroll_receipts.dart';

void main() {
  final payment = <String, dynamic>{
    'id': 7,
    'reference': 'PAY-TEST-7',
    'amount': '50.00',
    'payment_reference': 'BANK-123',
    'received_at': null,
  };

  testWidgets(
    'receipt confirmation requires explicit recipient acknowledgment',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PersonnelPayrollReceipts(
                receipts: [payment],
                onConfirm: (id) async {
                  expect(id, 7);
                  calls++;
                  return null;
                },
              ),
            ),
          ),
        ),
      );
      expect(find.text('₱50.00'), findsOneWidget);
      await tester.tap(find.text('Confirm funds received'));
      await tester.pumpAndSettle();
      expect(calls, 0);
      expect(find.textContaining('BANK-123'), findsNWidgets(2));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(calls, 0);
      await tester.tap(find.text('Confirm funds received'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('I received it'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.text('Payroll receipt confirmed.'), findsOneWidget);
    },
  );

  testWidgets(
    'confirmed receipts have no action and failures remain retryable',
    (tester) async {
      var received = false;
      Future<void> render() => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PersonnelPayrollReceipts(
                key: ValueKey(received),
                receipts: [
                  {...payment, 'received_at': received ? '2026-11-16' : null},
                ],
                onConfirm: (_) async =>
                    'Unable to confirm. Refresh and try again.',
              ),
            ),
          ),
        ),
      );
      await render();
      await tester.tap(find.text('Confirm funds received'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('I received it'));
      await tester.pumpAndSettle();
      expect(
        find.text('Unable to confirm. Refresh and try again.'),
        findsOneWidget,
      );
      received = true;
      await render();
      await tester.pumpAndSettle();
      expect(find.text('Receipt confirmed'), findsOneWidget);
      expect(find.text('Confirm funds received'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
