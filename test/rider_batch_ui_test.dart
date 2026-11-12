import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shophop/core/session/auth_session_service.dart';
import 'package:shophop/features/rider/presentation/screens/rider_home_screen.dart';
import 'package:shophop/shared/widgets/shop_hop_navigation.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shophop/core/theme/app_theme.dart';
import 'package:shophop/features/rider/data/services/rider_batch_service.dart';
import 'package:shophop/features/rider/presentation/screens/rider_batch_detail_screen.dart';

http.Response ok(Map<String, dynamic> data) => http.Response(
  jsonEncode({'success': true, 'data': data}),
  200,
  headers: {'content-type': 'application/json'},
);
Map<String, dynamic> batch({
  String status = 'in_progress',
  bool failed = false,
}) => {
  'id': 1,
  'code': 'RB-TEST',
  'type': 'pickup',
  'status': status,
  'branch': 'Calamba Branch',
  'scheduled_start': '2026-11-08T01:00:00Z',
  'scheduled_end': '2026-11-08T03:00:00Z',
  'capacity': {
    'totals': {'stops': 2, 'weight_kg': 4, 'volume_m3': 0.1, 'minutes': 90},
  },
  'progress': {'settled': failed ? 1 : 0, 'total': 2},
  'items': [
    {
      'id': 10,
      'delivery_id': 101,
      'tracking_code': 'SHP-20261108-000101',
      'stop_sequence': 1,
      'stop': {
        'name': 'Seller One',
        'address': 'Real, Calamba',
        'phone': '09123456789',
      },
      'status': failed ? 'pickup_failed' : 'pickup_assigned',
      'settled': failed,
      'cod_amount': 100,
      if (failed) 'reason': 'Seller unavailable',
    },
    {
      'id': 11,
      'delivery_id': 102,
      'tracking_code': 'SHP-20261108-000102',
      'stop_sequence': 2,
      'stop': {'name': 'Seller Two', 'address': 'Real, Calamba'},
      'status': 'pickup_assigned',
      'settled': false,
      'cod_amount': null,
    },
  ],
};
Future<void> mount(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(320, 950);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: child));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'home and Tasks show assigned routes without duplicate parcel task cards',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      await AuthSessionService.saveSession(
        token: 'test',
        email: 'rider@example.test',
        accountType: 'rider',
        rememberMe: false,
      );
      await http.runWithClient(
        () async {
          await mount(tester, const RiderHomeScreen());
          expect(find.text('Pickup route'), findsOneWidget);
          expect(find.text('Seller Pickup'), findsNothing);
          await tester.tap(
            find.descendant(
              of: find.byType(ShopHopNavigation),
              matching: find.text('Tasks'),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('Pickup route'), findsOneWidget);
          expect(find.text('Seller Pickup'), findsNothing);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
        () => MockClient((request) async {
          if (request.url.path.endsWith('/me')) {
            return http.Response(
              jsonEncode({
                'success': true,
                'status': 'approved',
                'data': {
                  'name': 'Batch Rider',
                  'sorting_center_name': 'Calamba Branch',
                },
              }),
              200,
            );
          }
          if (request.url.path.endsWith('/rider/batches')) {
            return ok({
              'enabled': true,
              'batches': [batch()],
              'next_page': null,
            });
          }
          if (request.url.path.endsWith('/assignments')) {
            return ok({
              'assignments': [
                {
                  'id': 101,
                  'rider_batch_id': 1,
                  'assignment_type': 'pickup',
                  'status': 'pickup_assigned',
                  'status_label': 'Pickup assigned',
                  'can_confirm_pickup': true,
                  'tracking_code': 'SHP-20261108-000101',
                  'order': {
                    'id': 101,
                    'seller': {'business_name': 'Seller One'},
                  },
                },
              ],
            });
          }
          return ok({});
        }),
      );
    },
  );

  testWidgets(
    'queued batch shows stops without parcel mutation or scan actions',
    (tester) async {
      await http.runWithClient(() async {
        await mount(
          tester,
          RiderBatchDetailScreen(
            token: 'test',
            initial: batch(status: 'queued'),
          ),
        );
        expect(find.text('Seller One'), findsOneWidget);
        expect(find.text('Seller Two'), findsOneWidget);
        expect(
          find.textContaining('Waiting for Branch dispatch'),
          findsOneWidget,
        );
        expect(find.text('Scan parcel QR'), findsNothing);
        expect(find.text('Could not collect'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }, () => MockClient((r) async => ok({'batch': batch(status: 'queued')})));
    },
  );
  testWidgets(
    'one unsuccessful pickup updates only its outcome and keeps route active',
    (tester) async {
      var failed = false;
      await http.runWithClient(
        () async {
          await mount(
            tester,
            RiderBatchDetailScreen(token: 'test', initial: batch()),
          );
          await tester.tap(find.text('Could not collect').first);
          await tester.pumpAndSettle();
          await tester.enterText(
            find.byType(TextFormField),
            'Seller unavailable',
          );
          await tester.tap(find.text('Save outcome'));
          await tester.pumpAndSettle();
          expect(failed, isTrue);
          expect(
            find.text('0/2 collected \u2022 0/2 received at branch'),
            findsOneWidget,
          );
          expect(find.text('Pickup Failed'), findsOneWidget);
          expect(find.text('Could not collect'), findsOneWidget);
          expect(find.text('Scan parcel QR'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
        () => MockClient((request) async {
          if (request.method == 'POST') {
            expect(
              request.url.path,
              endsWith('/batches/1/items/10/pickup-failure'),
            );
            expect(jsonDecode(request.body)['reason'], 'Seller unavailable');
            failed = true;
          }
          return ok({'batch': batch(failed: failed)});
        }),
      );
    },
  );
  testWidgets('visible batch refreshes and pauses in background', (
    tester,
  ) async {
    var calls = 0;
    await http.runWithClient(
      () async {
        await mount(
          tester,
          RiderBatchDetailScreen(token: 'test', initial: batch()),
        );
        expect(calls, 1);
        await tester.pump(const Duration(seconds: 16));
        await tester.pumpAndSettle();
        expect(calls, 2);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump(const Duration(seconds: 16));
        expect(calls, 2);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        expect(calls, 3);
        await tester.pumpWidget(const SizedBox.shrink());
      },
      () => MockClient((request) async {
        calls++;
        return ok({'batch': batch()});
      }),
    );
  });
  test(
    'pagination preserves routes without limiting parcel quantity',
    () async {
      final calls = <int>[];
      await http.runWithClient(
        () async {
          final result = await RiderBatchService.batches('test', pages: 2);
          expect(result.success, isTrue);
          expect((result.data['batches'] as List).length, 2);
          expect(calls, [1, 2]);
        },
        () => MockClient((request) async {
          final page = int.parse(request.url.queryParameters['page']!);
          calls.add(page);
          return ok({
            'enabled': true,
            'batches': [
              {
                'id': page,
                'items': List.generate(35, (i) => {'id': i}),
              },
            ],
            'next_page': page == 1 ? 2 : null,
          });
        }),
      );
    },
  );
  testWidgets('completed batch history is read only', (tester) async {
    await http.runWithClient(
      () async {
        await mount(
          tester,
          RiderBatchDetailScreen(
            token: 'test',
            initial: batch(status: 'completed', failed: true),
          ),
        );
        expect(find.textContaining('This route is closed'), findsOneWidget);
        expect(find.text('Parcel actions'), findsNothing);
        expect(find.text('Scan parcel QR'), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
      },
      () => MockClient(
        (request) async =>
            ok({'batch': batch(status: 'completed', failed: true)}),
      ),
    );
  });
  testWidgets(
    'collected pickup directs the rider to branch receipt without another pickup scan',
    (tester) async {
      final route = batch();
      route['items'] = [
        {
          ...((route['items'] as List).first as Map<String, dynamic>),
          'status': 'picked_up',
          'settled': false,
        },
      ];
      route['progress'] = {'settled': 0, 'total': 1};
      await http.runWithClient(() async {
        await mount(
          tester,
          RiderBatchDetailScreen(token: 'test', initial: route),
        );
        expect(find.text('Return to branch'), findsOneWidget);
        expect(
          find.text('1/1 collected \u2022 0/1 received at branch'),
          findsOneWidget,
        );
        expect(
          find.textContaining('Bring collected parcels to Calamba Branch'),
          findsWidgets,
        );
        expect(
          find.text('Collected - awaiting branch receipt'),
          findsOneWidget,
        );
        expect(find.text('Scan parcel QR'), findsNothing);
        expect(find.text('Parcel actions'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }, () => MockClient((_) async => ok({'batch': route})));
    },
  );

  testWidgets(
    'branch receipt completes pickup progress and removes return instructions',
    (tester) async {
      final route = batch();
      route['items'] = [
        {
          ...((route['items'] as List).first as Map<String, dynamic>),
          'status': 'received_at_branch',
          'settled': true,
        },
      ];
      route['progress'] = {'settled': 1, 'total': 1};
      await http.runWithClient(() async {
        await mount(
          tester,
          RiderBatchDetailScreen(token: 'test', initial: route),
        );
        expect(
          find.text('1/1 collected \u2022 1/1 received at branch'),
          findsOneWidget,
        );
        expect(find.text('Return to branch'), findsNothing);
        expect(find.textContaining('Bring collected parcels to'), findsNothing);
        expect(
          find.text('All outcomes resolved. Branch can complete this route.'),
          findsOneWidget,
        );
        expect(find.text('Scan parcel QR'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }, () => MockClient((_) async => ok({'batch': route})));
    },
  );
  for (final size in [const Size(320, 640), const Size(430, 932)]) {
    testWidgets(
      'out for delivery has direct completion without a scan at ${size.width}',
      (tester) async {
        final route = batch();
        route['type'] = 'delivery';
        route['progress'] = {'settled': 0, 'total': 1};
        route['items'] = [
          {
            ...((route['items'] as List).first as Map<String, dynamic>),
            'status': 'out_for_delivery',
            'settled': false,
            'stop': {
              'name': 'Test Buyer',
              'address': '123 Street, Calamba',
              'phone': '09123456789',
            },
          },
        ];
        final actions = <String>[];
        await http.runWithClient(() async {
          await mount(
            tester,
            RiderBatchDetailScreen(
              token: 'test',
              initial: route,
              onDeliveryAction: (id, action) async {
                actions.add('$id:$action');
                (route['items'] as List).first['status'] = 'delivered';
                (route['items'] as List).first['settled'] = true;
                route['progress'] = {'settled': 1, 'total': 1};
              },
            ),
          );
          tester.view.physicalSize = size;
          await tester.pumpAndSettle();
          expect(find.text('Deliver to Test Buyer'), findsOneWidget);
          expect(find.text('Call buyer'), findsOneWidget);
          expect(find.text('Open map'), findsOneWidget);
          expect(find.text('0/1 delivered'), findsOneWidget);
          expect(find.text('Scan parcel QR'), findsNothing);
          expect(find.text('Scan & collect'), findsNothing);
          expect(find.text('Parcel actions'), findsNothing);
          await tester.ensureVisible(find.text('Complete delivery'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Complete delivery'));
          await tester.pumpAndSettle();
          expect(actions, ['101:complete']);
          expect(find.text('1/1 delivered'), findsOneWidget);
          expect(find.text('Complete delivery'), findsNothing);
          expect(find.byType(RiderBatchDetailScreen), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        }, () => MockClient((_) async => ok({'batch': route})));
      },
    );
  }

  testWidgets(
    'mixed delivery route shows collection only for the parcel still at branch',
    (tester) async {
      final route = batch();
      route['type'] = 'delivery';
      (route['items'] as List)[0]['status'] = 'delivery_assigned';
      (route['items'] as List)[1]['status'] = 'out_for_delivery';
      await http.runWithClient(() async {
        await mount(
          tester,
          RiderBatchDetailScreen(
            token: 'test',
            initial: route,
            onDeliveryAction: (_, _) async {},
          ),
        );
        expect(find.text('Scan parcel QR'), findsNothing);
        expect(find.text('Scan & collect'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('Complete delivery'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Complete delivery'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }, () => MockClient((_) async => ok({'batch': route})));
    },
  );
}
