import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shophop/core/theme/app_theme.dart';
import 'package:shophop/features/rider/data/models/rider_assignment.dart';
import 'package:shophop/features/rider/presentation/widgets/rider_contact_actions.dart';
import 'package:shophop/features/rider/presentation/widgets/rider_delivery_completion.dart';

RiderAssignment assignment({bool cod = true}) => RiderAssignment.fromJson({
  'id': 101,
  'tracking_code': 'SHP-20261107-000001',
  'status': 'out_for_delivery',
  'assignment_type': 'delivery',
  'can_complete_delivery': true,
  'order': {
    'total_amount': '1005.00',
    'payment_method': cod ? 'cod' : 'wallet',
    'delivery_name': 'Test Buyer',
  },
});

void main() {
  testWidgets(
    'camera cancellation and denied access cannot complete delivery',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RiderDeliveryCompletion(
              assignment: assignment(cod: false),
              captureProof: () async {
                calls++;
                if (calls == 1) return null;
                throw PlatformException(code: 'camera_access_denied');
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open camera'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('delivery-proof-name')), findsNothing);
      await tester.tap(find.text('Open camera'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Camera access is disabled'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Confirm delivered'),
            )
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets('camera proof still requires COD confirmation', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RiderDeliveryCompletion(
            assignment: assignment(),
            captureProof: () async => PlatformFile(
              name: 'camera.jpg',
              size: 4,
              bytes: Uint8List.fromList([1, 2, 3, 4]),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open camera'));
    await tester.pumpAndSettle();
    expect(find.text('camera.jpg'), findsOneWidget);
    final confirm = find.widgetWithText(FilledButton, 'Confirm delivered');
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);
  });

  for (final cod in [true, false]) {
    testWidgets(
      'delivery requires photo and COD confirmation only when applicable ($cod)',
      (tester) async {
        RiderDeliveryConfirmation? result;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async {
                    result =
                        await showModalBottomSheet<RiderDeliveryConfirmation>(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) => RiderDeliveryCompletion(
                            assignment: assignment(cod: cod),
                            pickProof: () async => PlatformFile(
                              name: 'delivery.jpg',
                              size: 4,
                              bytes: Uint8List.fromList([1, 2, 3, 4]),
                            ),
                          ),
                        );
                  },
                  child: const Text('Open delivery'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open delivery'));
        await tester.pumpAndSettle();
        FilledButton submit() => tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Confirm delivered'),
        );
        expect(submit().onPressed, isNull);
        expect(result, isNull);
        await tester.tap(find.text('Choose delivery photo'));
        await tester.pumpAndSettle();
        expect(find.text('delivery.jpg'), findsOneWidget);
        if (cod) {
          expect(submit().onPressed, isNull);
          await tester.tap(find.byType(CheckboxListTile));
          await tester.pumpAndSettle();
        } else {
          expect(find.byType(CheckboxListTile), findsNothing);
          expect(find.textContaining('Do not collect payment'), findsOneWidget);
        }
        expect(submit().onPressed, isNotNull);
        await tester.tap(find.text('Confirm delivered'));
        await tester.pumpAndSettle();
        expect(result?.proof.name, 'delivery.jpg');
        expect(result?.cashCollected, cod);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'oversized proof cannot confirm delivery and cancellation has no result',
    (tester) async {
      RiderDeliveryConfirmation? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result =
                      await showModalBottomSheet<RiderDeliveryConfirmation>(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => RiderDeliveryCompletion(
                          assignment: assignment(),
                          pickProof: () async => PlatformFile(
                            name: 'large.jpg',
                            size: 6 * 1024 * 1024,
                          ),
                        ),
                      );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose delivery photo'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Choose a JPG'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Confirm delivered'),
            )
            .onPressed,
        isNull,
      );
      await tester.ensureVisible(find.text('Cancel'));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(find.text('Complete delivery'), findsNothing);
    },
  );

  testWidgets(
    'contact buttons open dialer and encoded map location on request',
    (tester) async {
      final opened = <Uri>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RiderContactActions(
              phone: '0912 345 6789',
              address: '123 Street, Calamba & Laguna',
              openLink: (uri) async {
                opened.add(uri);
                return true;
              },
            ),
          ),
        ),
      );
      expect(opened, isEmpty);
      await tester.tap(find.text('Call buyer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open map'));
      await tester.pumpAndSettle();
      expect(opened[0].scheme, 'tel');
      expect(opened[0].path, '09123456789');
      expect(opened[1].scheme, 'https');
      expect(opened[1].host, 'www.google.com');
      expect(
        opened[1].queryParameters['query'],
        '123 Street, Calamba & Laguna',
      );
    },
  );
}
