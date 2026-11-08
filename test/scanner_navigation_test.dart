import 'package:shophop/features/logistics/presentation/screens/manifest_loading_screen.dart';
import 'package:shophop/features/logistics/presentation/screens/manifest_receiving_screen.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shophop/core/session/auth_session_service.dart';
import 'package:shophop/core/theme/app_colors.dart';
import 'package:shophop/core/theme/app_theme.dart';
import 'package:shophop/features/logistics/presentation/screens/logistics_scanner_screen.dart';
import 'package:shophop/features/linehaul/presentation/screens/linehaul_driver_home_screen.dart';
import 'package:shophop/shared/widgets/shop_hop_navigation.dart';
import 'package:shophop/shared/widgets/shop_hop_role_layout.dart';
import 'package:shophop/shared/widgets/shop_hop_scan_feedback.dart';
import 'package:shophop/shared/widgets/shop_hop_scanner.dart';

class _FeedbackOutput implements ScanFeedbackOutput {
  final events = <ScanFeedbackEvent>[];
  @override
  Future<void> play(ScanFeedbackEvent event) async {
    events.add(event);
  }

  @override
  Future<void> vibrate(ScanFeedbackEvent event) async {}
}

http.Response _ok(Map<String, dynamic> data, {bool success = true}) =>
    http.Response(
      jsonEncode({
        'success': success,
        'status': success ? 'ok' : 'error',
        'message': success
            ? 'Operation confirmed.'
            : 'Recheck before retrying.',
        'data': data,
      }),
      success ? 200 : 503,
      headers: {'content-type': 'application/json'},
    );
Future<void> _session(String role) => AuthSessionService.saveSession(
  token: 'scan-test',
  email: 'test@example.test',
  accountType: role,
  rememberMe: false,
);
Future<void> _mount(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: home));
  await tester.pumpAndSettle();
}

Future<void> _tab(WidgetTester tester, String label) async {
  await tester.tap(
    find
        .descendant(
          of: find.byType(ShopHopNavigation),
          matching: find.text(label),
        )
        .last,
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String text) async {
  final finder = find.text(text).last;
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _FeedbackOutput output;
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    output = _FeedbackOutput();
    ShopHopScanFeedback.instance = ShopHopScanFeedback(output: output);
    ShopHopScanFeedback.soundEnabled.value = true;
    ShopHopScanFeedback.vibrationEnabled.value = true;
  });

  testWidgets(
    'Every operational Scan tab is centered, raised and tappable at large text sizes',
    (tester) async {
      for (final role in ShopHopRole.values) {
        final raised = role == ShopHopRole.seller ? null : 2;
        var selected = 0;
        await _mount(
          tester,
          StatefulBuilder(
            builder: (context, setState) => Scaffold(
              appBar: ShopHopRoleAppBar(
                role: role,
                index: selected,
                onRefresh: () {},
              ),
              body: const SizedBox(),
              bottomNavigationBar: MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.7)),
                child: ShopHopNavigation(
                  raisedIndex: raised,
                  items: role.destinations,
                  index: selected,
                  onChanged: (value) => setState(() => selected = value),
                ),
              ),
            ),
          ),
        );
        expect(
          tester.widget<AppBar>(find.byType(AppBar)).backgroundColor,
          AppColors.tealDark,
        );
        if (raised != null) {
          expect(role.destinations[2].label, 'Scan');
          final scan = find.byKey(const ValueKey('raised-scan-button'));
          expect(
            tester.getTopLeft(scan).dy,
            lessThan(tester.getTopLeft(find.byType(ShopHopNavigation)).dy + 17),
          );
          await tester.tap(scan);
          await tester.pumpAndSettle();
          expect(selected, 2);
        } else {
          expect(
            find.byKey(const ValueKey('raised-scan-button')),
            findsNothing,
          );
        }
        final label = tester.widget<Text>(find.text('Account').last);
        expect(label.style!.fontFamily, 'Poppins');
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Logistics verification is distinct from receipt; failed writes preserve details and require recheck',
    (tester) async {
      await _session('logistics_staff');
      var writes = 0;
      var allowReceipt = false;
      await http.runWithClient(
        () async {
          await _mount(tester, const LogisticsScannerScreen());
          await _tab(tester, 'Manifests');
          expect(find.text('Receive inbound manifest'), findsOneWidget);
          expect(find.text('Load outbound manifest'), findsOneWidget);
          await _tab(tester, 'Scan');
          await tester.enterText(find.byType(TextField), 'SHP-20261108-000001');
          await _tap(tester, 'Check parcel details');
          expect(output.events, [ScanFeedbackEvent.verified]);
          expect(writes, 0);
          await _tap(tester, 'Confirm parcel received');
          await _tap(tester, 'Cancel');
          expect(output.events, [ScanFeedbackEvent.verified]);
          expect(writes, 0);
          await _tap(tester, 'Confirm parcel received');
          await _tap(tester, 'Confirm received');
          expect(writes, 1);
          expect(output.events.last, ScanFeedbackEvent.error);
          expect(find.text('Receiving at: Calamba Branch'), findsOneWidget);
          final confirm = find
              .ancestor(
                of: find.text('Confirm parcel received'),
                matching: find.byWidgetPredicate((w) => w is FilledButton),
              )
              .first;
          expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
          allowReceipt = true;
          await _tap(tester, 'Recheck parcel');
          await _tap(tester, 'Confirm parcel received');
          await _tap(tester, 'Confirm received');
          expect(writes, 2);
          expect(output.events.last, ScanFeedbackEvent.complete);
          expect(find.text('Scan next'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        },
        () => MockClient((request) async {
          if (request.method == 'POST') {
            writes++;
            return _ok({}, success: allowReceipt);
          }
          if (request.url.path.endsWith('/branches')) {
            return _ok({
              'branch_locked': true,
              'branches': [
                {'id': 4, 'name': 'Calamba Branch', 'code': 'CAL'},
              ],
            });
          }
          if (request.url.path.endsWith('/preview')) {
            return _ok({
              'parcel': {
                'tracking_code': 'SHP-20261108-000001',
                'branch': 'Calamba Branch',
                'next_action': 'Receive parcel',
                'delivery_status': 'picked_up',
              },
            });
          }
          return _ok({});
        }),
      );
    },
  );

  testWidgets(
    'Linehaul Scan keeps manual input and plays completion only after departure confirmation',
    (tester) async {
      await _session('linehaul_driver');
      var writes = 0;
      await http.runWithClient(
        () async {
          await _mount(tester, const LinehaulDriverHomeScreen());
          await _tab(tester, 'Vehicle');
          expect(find.text('No active vehicle assignment.'), findsOneWidget);
          await _tab(tester, 'Scan');
          await tester.enterText(find.byType(TextField), 'MF-TEST');
          await tester.pumpAndSettle();
          await _tap(tester, 'Review manifest details');
          expect(output.events, [ScanFeedbackEvent.verified]);
          expect(writes, 0);
          await _tap(tester, 'Confirm custody');
          await _tap(tester, 'Cancel');
          expect(writes, 0);
          await _tap(tester, 'Confirm custody');
          await _tap(tester, 'Accept & depart');
          expect(writes, 1);
          expect(output.events.last, ScanFeedbackEvent.complete);
          expect(find.text('Scan next'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        },
        () => MockClient((request) async {
          if (request.method == 'POST') {
            writes++;
            expect(request.url.path, endsWith('/linehaul/manifest/confirm'));
            return _ok({});
          }
          if (request.url.path.endsWith('/preview')) {
            return _ok({
              'manifest': {
                'manifest_code': 'MF-TEST',
                'action': 'depart',
                'trip_status': 'scheduled',
                'trip_code': 'TRIP-1',
                'from': 'Calamba',
                'to': 'Pila',
                'vehicle_code': 'VAN-1',
                'plate_number': 'ABC1234',
                'loaded': 3,
                'expected': 3,
                'received': 0,
              },
            });
          }
          return _ok({});
        }),
      );
    },
  );

  testWidgets(
    'Inbound arrival and intact receipt produce separate confirmed outcomes',
    (tester) async {
      var arrived = false;
      var completed = false;
      var writes = 0;
      Map<String, dynamic> manifest() => {
        'manifest_code': 'MF-TEST',
        'from': 'Calamba',
        'to': 'Pila',
        'transport_mode': 'road',
        'trip_status': arrived ? 'arrived' : 'in_transit',
        'trip_code': 'TRIP-1',
        'vehicle_code': 'VAN-1',
        'plate_number': 'ABC1234',
        'driver': 'Juan',
        'expected': 3,
        'received': completed ? 3 : 0,
        'arrival_acknowledged': arrived,
        'completed': completed,
      };
      await http.runWithClient(
        () async {
          await _mount(
            tester,
            const ManifestReceivingScreen(
              token: 'test',
              branchId: 4,
              branchName: 'Pila Branch',
            ),
          );
          await tester.drag(find.byType(ListView), const Offset(0, -400));
          await tester.pumpAndSettle();
          await tester.enterText(find.byType(TextField).first, 'MF-TEST');
          await tester.pumpAndSettle();
          await _tap(tester, 'Verify manifest');
          expect(output.events, [ScanFeedbackEvent.verified]);
          expect(writes, 0);
          await _tap(tester, 'Confirm destination arrival');
          await _tap(tester, 'Confirm arrival');
          expect(writes, 1);
          expect(output.events.last, ScanFeedbackEvent.complete);
          await tester.drag(find.byType(ListView), const Offset(0, -700));
          await tester.pumpAndSettle();
          final count = find.byWidgetPredicate(
            (w) => w is TextField && w.keyboardType == TextInputType.number,
          );
          await tester.ensureVisible(count);
          await tester.pumpAndSettle();
          await tester.enterText(count, '3');
          await tester.pumpAndSettle();
          await _tap(tester, 'Receive all intact');
          await _tap(tester, 'Receive all intact');
          expect(writes, 2);
          expect(
            output.events.where((e) => e == ScanFeedbackEvent.complete).length,
            2,
          );
          expect(find.text('Scan next manifest'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        },
        () => MockClient((request) async {
          if (request.method == 'POST') {
            writes++;
            if (request.url.path.endsWith('/arrive')) arrived = true;
            if (request.url.path.endsWith('/receive-all')) completed = true;
          }
          return _ok({'manifest': manifest()});
        }),
      );
    },
  );

  testWidgets(
    'Outbound count mismatch makes no write; matching count keeps the confirmation result after refresh',
    (tester) async {
      var writes = 0;
      var loaded = false;
      await http.runWithClient(
        () async {
          await _mount(
            tester,
            const ManifestLoadingScreen(
              token: 'test',
              branchId: 4,
              branchName: 'Calamba Branch',
            ),
          );
          await tester.drag(find.byType(ListView), const Offset(0, -450));
          await tester.pumpAndSettle();
          final count = find.byWidgetPredicate(
            (w) => w is TextField && w.keyboardType == TextInputType.number,
          );
          await tester.ensureVisible(count);
          await tester.pumpAndSettle();
          await tester.enterText(count, '2');
          await tester.pumpAndSettle();
          await _tap(tester, 'STEP 3  Confirm complete load');
          expect(writes, 0);
          expect(output.events.last, ScanFeedbackEvent.error);
          await tester.drag(find.byType(ListView), const Offset(0, -500));
          await tester.pumpAndSettle();
          await tester.ensureVisible(count);
          await tester.pumpAndSettle();
          await tester.enterText(count, '3');
          await tester.pumpAndSettle();
          await _tap(tester, 'STEP 3  Confirm complete load');
          await _tap(tester, 'Confirm batch');
          expect(writes, 1);
          expect(output.events.last, ScanFeedbackEvent.complete);
          expect(find.text('Confirmed'), findsOneWidget);
          expect(find.text('Continue loading'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        },
        () => MockClient((request) async {
          if (request.method == 'POST') {
            writes++;
            loaded = true;
            return _ok({});
          }
          return _ok({
            'manifests': [
              {
                'id': 1,
                'code': 'MF-TEST',
                'to': 'Pila Branch',
                'expected': 3,
                'loaded': loaded ? 3 : 0,
                'status': loaded ? 'ready' : 'loading',
              },
            ],
          });
        }),
      );
    },
  );

  testWidgets(
    'Opening another Linehaul trip clears the previous manifest review',
    (tester) async {
      await _session('linehaul_driver');
      await http.runWithClient(
        () async {
          await _mount(tester, const LinehaulDriverHomeScreen());
          await _tab(tester, 'Scan');
          await tester.enterText(find.byType(TextField), 'MF-OLD');
          await tester.pumpAndSettle();
          await _tap(tester, 'Review manifest details');
          expect(find.text('MF-OLD'), findsOneWidget);
          await _tab(tester, 'Trips');
          await _tap(tester, 'Review / scan manifest');
          expect(
            tester.widget<TextField>(find.byType(TextField)).controller!.text,
            'MF-NEW',
          );
          expect(find.text('MF-OLD'), findsNothing);
          expect(find.text('Confirm custody'), findsNothing);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        },
        () => MockClient((request) async {
          expect(request.method, 'GET');
          if (request.url.path.endsWith('/trips')) {
            return _ok({
              'trips': [
                {
                  'id': 2,
                  'code': 'TRIP-NEW',
                  'status': 'scheduled',
                  'manifest_code': 'MF-NEW',
                  'from': 'Calamba',
                  'to': 'Pila',
                  'parcel_count': 3,
                  'vehicle_code': 'VAN-2',
                  'plate_number': 'ABC2345',
                },
              ],
            });
          }
          if (request.url.path.endsWith('/preview')) {
            return _ok({
              'manifest': {
                'manifest_code': 'MF-OLD',
                'action': 'depart',
                'trip_status': 'scheduled',
                'trip_code': 'TRIP-OLD',
                'from': 'Calamba',
                'to': 'Pila',
                'vehicle_code': 'VAN-1',
                'plate_number': 'ABC1234',
                'loaded': 3,
                'expected': 3,
                'received': 0,
              },
            });
          }
          return _ok({});
        }),
      );
    },
  );

  testWidgets('Scanner sound preferences work without changing the workflow', (
    tester,
  ) async {
    await _mount(
      tester,
      const Scaffold(
        body: Column(
          children: [ShopHopScanPreferences(), ShopHopScanSteps(step: 1)],
        ),
      ),
    );
    await _tap(tester, 'Sound on');
    expect(ShopHopScanFeedback.soundEnabled.value, isFalse);
    await _tap(tester, 'Vibration on');
    expect(ShopHopScanFeedback.vibrationEnabled.value, isFalse);
    expect(find.text('Sound off'), findsOneWidget);
    expect(find.text('Vibration off'), findsOneWidget);
    expect(output.events, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
