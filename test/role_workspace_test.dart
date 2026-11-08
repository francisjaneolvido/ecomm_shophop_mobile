import 'package:shophop/shared/widgets/shop_hop_scan_feedback.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shophop/core/session/auth_session_service.dart';
import 'package:shophop/core/theme/app_theme.dart';
import 'package:shophop/features/seller/presentation/screens/seller_workspace_screen.dart';
import 'package:shophop/features/rider/presentation/screens/rider_home_screen.dart';
import 'package:shophop/features/logistics/presentation/screens/logistics_scanner_screen.dart';
import 'package:shophop/features/linehaul/presentation/screens/linehaul_driver_home_screen.dart';
import 'package:shophop/shared/widgets/shop_hop_navigation.dart';
import 'package:shophop/shared/widgets/shop_hop_role_layout.dart';

http.Response ok(Map<String, dynamic> data, {String status = 'ok'}) =>
    http.Response(
      jsonEncode({
        'success': true,
        'status': status,
        'message': 'Loaded.',
        'data': data,
      }),
      200,
      headers: {'content-type': 'application/json'},
    );

Future<void> session(String type) => AuthSessionService.saveSession(
  token: 'role-test',
  email: '$type@example.test',
  accountType: type,
  rememberMe: false,
);

Future<void> mount(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(320, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: screen));
  await tester.pumpAndSettle();
}

Future<void> tab(WidgetTester tester, String label) async {
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

Map<String, dynamic> sellerOrder({bool accepted = false}) => {
  'id': 7,
  'display_id': 'SHP-000007',
  'buyer': 'Maria Cruz',
  'status': accepted ? 'confirmed' : 'to-ship',
  'status_label': accepted ? 'Confirmed' : 'To ship',
  'can_accept': !accepted,
  'can_prepare': accepted,
  'total_amount': 250,
  'items_count': 1,
};
Map<String, dynamic> sellerData(String path, {bool accepted = false}) {
  if (path.endsWith('/dashboard')) {
    return {'business_name': 'Test Store', 'new_orders': accepted ? 0 : 1};
  }
  if (path.endsWith('/orders')) {
    return {
      'orders': [sellerOrder(accepted: accepted)],
    };
  }
  if (path.endsWith('/inventory')) {
    return {
      'products': [
        {
          'id': 1,
          'name': 'Desk lamp',
          'sku': 'LAMP',
          'stock': 4,
          'price': 250,
          'status': 'active',
          'compliance_status': 'pending_review',
        },
      ],
    };
  }
  return {};
}

Map<String, dynamic> assignment(
  int id, {
  bool pickup = true,
  bool delivered = false,
}) => {
  'id': id,
  'tracking_code': 'SHP-20261108-00000$id',
  'status': delivered
      ? 'delivered'
      : pickup
      ? 'pickup_assigned'
      : 'out_for_delivery',
  'status_label': delivered
      ? 'Delivered'
      : pickup
      ? 'Pickup assigned'
      : 'Out for delivery',
  'assignment_type': delivered
      ? 'history'
      : pickup
      ? 'pickup'
      : 'delivery',
  'can_confirm_pickup': pickup && !delivered,
  'can_complete_delivery': !pickup && !delivered,
  'can_fail_delivery': !pickup && !delivered,
  'order': {
    'id': id,
    'total_amount': 250,
    'payment_method': 'cod',
    'delivery_name': 'Maria Cruz',
    'delivery_address': 'Calamba City',
    'seller': {
      'name': 'Luis',
      'business_name': 'Lamp Store',
      'address': 'Pila Laguna',
    },
  },
};
Map<String, dynamic> trip(int id, String status) => {
  'id': id,
  'code': 'TRIP-00$id',
  'status': status,
  'from': 'Calamba Branch',
  'to': 'Pila Branch',
  'manifest_code': 'MF-00$id',
  'parcel_count': 3,
  'vehicle_code': 'VAN-01',
  'plate_number': 'ABC1234',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    ShopHopScanFeedback.soundEnabled.value = false;
    ShopHopScanFeedback.vibrationEnabled.value = false;
  });

  testWidgets(
    'Seller filters survive tab switches and silent refresh; approval remains visible',
    (tester) async {
      await session('seller');
      var dashboardReads = 0;
      await http.runWithClient(
        () async {
          await mount(tester, const SellerWorkspaceScreen());
          expect(dashboardReads, 1);
          await tab(tester, 'Orders');
          await tester.enterText(
            find.byKey(const ValueKey('seller-order-search')),
            'Maria',
          );
          await tab(tester, 'Products');
          expect(
            find.textContaining('Awaiting Admin approval'),
            findsOneWidget,
          );
          await tester.enterText(
            find.byKey(const ValueKey('seller-product-search')),
            'lamp',
          );
          await tab(tester, 'Orders');
          expect(
            tester
                .widget<TextFormField>(
                  find.byKey(const ValueKey('seller-order-search')),
                )
                .initialValue,
            'Maria',
          );
          await tester.pump(const Duration(seconds: 15));
          await tester.pumpAndSettle();
          expect(dashboardReads, 2);
          expect(
            find.byKey(const ValueKey('seller-order-search')),
            findsOneWidget,
          );
          expect(find.text('SHP-000007'), findsOneWidget);
          await tab(tester, 'Products');
          expect(
            tester
                .widget<TextFormField>(
                  find.byKey(const ValueKey('seller-product-search')),
                )
                .initialValue,
            'lamp',
          );
          await tab(tester, 'Account');
          expect(find.text('Account & store'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
        () => MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.headers['Authorization'], 'Bearer role-test');
          if (request.url.path.endsWith('/dashboard')) dashboardReads++;
          return ok(sellerData(request.url.path));
        }),
      );
    },
  );

  testWidgets(
    'Seller confirmation submits one owned order action and refreshes its status',
    (tester) async {
      await session('seller');
      var accepted = false;
      var writes = 0;
      await http.runWithClient(
        () async {
          await mount(tester, const SellerWorkspaceScreen());
          await tab(tester, 'Orders');
          await tester.ensureVisible(find.text('Accept order'));
          await tester.tap(find.text('Accept order'));
          await tester.pumpAndSettle();
          expect(writes, 0);
          await tester.tap(find.widgetWithText(FilledButton, 'Accept'));
          await tester.pumpAndSettle();
          expect(writes, 1);
          expect(find.text('Start preparing'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
        () => MockClient((request) async {
          if (request.method == 'POST') {
            expect(request.url.path, endsWith('/seller/orders/7/accept'));
            writes++;
            accepted = true;
            return ok({});
          }
          return ok(sellerData(request.url.path, accepted: accepted));
        }),
      );
    },
  );

  testWidgets(
    'Rider searches assigned work, refreshes status and pauses in background',
    (tester) async {
      await session('rider');
      var reads = 0;
      var delivered = false;
      await http.runWithClient(
        () async {
          await mount(tester, const RiderHomeScreen());
          expect(reads, 1);
          await tab(tester, 'Tasks');
          await tester.enterText(
            find.byKey(const ValueKey('rider-task-search')),
            'Pila',
          );
          await tester.pumpAndSettle();
          expect(find.text('SHP-20261108-000001'), findsOneWidget);
          delivered = true;
          await tester.pump(const Duration(seconds: 15));
          await tester.pumpAndSettle();
          expect(reads, 2);
          expect(find.text('No matching tasks'), findsOneWidget);
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.inactive,
          );
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.hidden,
          );
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.paused,
          );
          await tester.pump(const Duration(seconds: 30));
          expect(reads, 2);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.hidden,
          );
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.inactive,
          );
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          await tester.pumpAndSettle();
        },
        () => MockClient((request) async {
          expect(request.method, 'GET');
          final path = request.url.path;
          if (path.endsWith('/me')) {
            return ok({
              'name': 'Juan',
              'status': 'approved',
              'sorting_center_name': 'Calamba',
            }, status: 'approved');
          }
          if (path.endsWith('/assignments')) {
            reads++;
            return ok({
              'assignments': [assignment(1, delivered: delivered)],
            });
          }
          return ok({});
        }),
      );
    },
  );

  testWidgets(
    'Delivery rider sees proof and failed-attempt actions from API permissions',
    (tester) async {
      await session('rider');
      await http.runWithClient(
        () async {
          await mount(tester, const RiderHomeScreen());
          expect(find.text('Delivered'), findsOneWidget);
          expect(find.text('Failed'), findsOneWidget);
          expect(find.text('Scan waybill at Seller'), findsNothing);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
        () => MockClient((request) async {
          if (request.url.path.endsWith('/me')) {
            return ok({
              'name': 'Juan',
              'status': 'approved',
            }, status: 'approved');
          }
          if (request.url.path.endsWith('/assignments')) {
            return ok({
              'assignments': [assignment(2, pickup: false)],
            });
          }
          return ok({});
        }),
      );
    },
  );

  testWidgets(
    'Logistics refreshes activity and preserves staff branch restrictions',
    (tester) async {
      await session('logistics_staff');
      var reads = 0;
      await http.runWithClient(
        () async {
          await mount(tester, const LogisticsScannerScreen());
          final beforeTab = reads;
          await tab(tester, 'Activity');
          expect(reads, greaterThan(beforeTab));
          final before = reads;
          await tester.pump(const Duration(seconds: 15));
          await tester.pumpAndSettle();
          expect(reads, greaterThan(before));
          expect(find.text('SHP-20261108-000001'), findsOneWidget);
          await tab(tester, 'Account');
          expect(find.text('Search city / branch'), findsNothing);
          final accountReads = reads;
          await tester.pump(const Duration(seconds: 15));
          await tester.pumpAndSettle();
          expect(reads, accountReads);

          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        },
        () => MockClient((request) async {
          expect(request.method, 'GET');
          if (request.url.path.endsWith('/branches')) {
            return ok({
              'branch_locked': true,
              'company': 'Test Logistics',
              'branches': [
                {'id': 4, 'name': 'Calamba Branch', 'code': 'CAL'},
              ],
            });
          }
          if (request.url.path.endsWith('/history')) {
            reads++;
            expect(request.url.queryParameters['sorting_center_id'], '4');
            return ok({
              'events': [
                {
                  'tracking_code': 'SHP-20261108-000001',
                  'event': 'pickup_received',
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
    'Linehaul shows active custody first, polls trips and pauses on Scan',
    (tester) async {
      await session('linehaul_driver');
      var reads = 0;
      var completed = false;
      await http.runWithClient(
        () async {
          await mount(tester, const LinehaulDriverHomeScreen());
          expect(find.text('TRIP-001'), findsOneWidget);
          expect(find.text('Current trip'), findsOneWidget);
          completed = true;
          await tester.pump(const Duration(seconds: 10));
          await tester.pumpAndSettle();
          expect(reads, 2);
          expect(find.text('TRIP-001'), findsNothing);
          await tab(tester, 'Scan');
          await tester.enterText(find.byType(TextField), 'MAN-002');
          await tester.pump(const Duration(seconds: 20));
          await tester.pumpAndSettle();
          expect(reads, 2);
          expect(
            tester.widget<TextField>(find.byType(TextField)).controller!.text,
            'MAN-002',
          );
          await tab(tester, 'History');
          expect(find.text('TRIP-001'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        },
        () => MockClient((request) async {
          expect(request.method, 'GET');
          if (request.url.path.endsWith('/trips')) {
            reads++;
            return ok({
              'trips': [
                trip(2, 'scheduled'),
                trip(1, completed ? 'completed' : 'in_transit'),
              ],
            });
          }
          return ok({});
        }),
      );
    },
  );

  testWidgets(
    'Linehaul read failure is visible outside scanner and Retry recovers',
    (tester) async {
      await session('linehaul_driver');
      var offline = true;
      await http.runWithClient(
        () async {
          await mount(tester, const LinehaulDriverHomeScreen());
          expect(find.text('Temporarily offline'), findsOneWidget);
          offline = false;
          await tester.tap(find.text('Retry'));
          await tester.pumpAndSettle();
          expect(find.text('Temporarily offline'), findsNothing);
          expect(find.text('TRIP-001'), findsOneWidget);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
        () => MockClient((request) async {
          if (offline) {
            return http.Response(
              jsonEncode({'success': false, 'message': 'Temporarily offline'}),
              503,
            );
          }
          if (request.url.path.endsWith('/trips')) {
            return ok({
              'trips': [trip(1, 'scheduled')],
            });
          }
          return ok({});
        }),
      );
    },
  );

  testWidgets(
    'Logistics manual preview stays open without automatic custody writes',
    (tester) async {
      await session('logistics_staff');
      var branchReads = 0;
      await http.runWithClient(
        () async {
          await mount(tester, const LogisticsScannerScreen());
          await tab(tester, 'Scan');
          await tester.enterText(find.byType(TextField), 'SHP-20261108-000001');
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('Check parcel details'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Check parcel details'));
          await tester.pumpAndSettle();
          expect(find.text('Confirm parcel received'), findsOneWidget);
          final before = branchReads;
          await tester.pump(const Duration(seconds: 30));
          await tester.pumpAndSettle();
          expect(branchReads, before);
          expect(find.text('Confirm parcel received'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        },
        () => MockClient((request) async {
          expect(request.method, 'GET');
          if (request.url.path.endsWith('/branches')) {
            branchReads++;
            return ok({
              'branch_locked': true,
              'branches': [
                {'id': 4, 'name': 'Calamba Branch', 'code': 'CAL'},
              ],
            });
          }
          if (request.url.path.endsWith('/preview')) {
            return ok({
              'parcel': {
                'tracking_code': 'SHP-20261108-000001',
                'branch': 'Calamba Branch',
                'next_action': 'Receive pickup parcel',
                'delivery_status': 'picked_up',
              },
            });
          }
          return ok({});
        }),
      );
    },
  );

  testWidgets('Role headers and metrics fit enlarged text on a narrow phone', (
    tester,
  ) async {
    for (final role in ShopHopRole.values) {
      await mount(
        tester,
        Scaffold(
          appBar: ShopHopRoleAppBar(role: role, index: 0, onRefresh: () {}),
          body: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
            child: const SingleChildScrollView(
              child: Column(
                children: [
                  ShopHopRoleIntro(
                    title: 'Assigned Calamba Sorting Center',
                    subtitle:
                        'Review the next physical handoff before confirming custody.',
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: ShopHopRoleMetric(
                          label: 'Pending earnings',
                          value: 'PHP 100,000.00',
                          icon: Icons.wallet_outlined,
                        ),
                      ),
                      Expanded(
                        child: ShopHopRoleMetric(
                          label: 'Awaiting pickup',
                          value: '100',
                          icon: Icons.inventory_2_outlined,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          bottomNavigationBar: ShopHopNavigation(
            items: role.destinations,
            index: 0,
            onChanged: (_) {},
          ),
        ),
      );
      expect(role.destinations.last.label, 'Account');
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
  });
}
