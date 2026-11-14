import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shophop/core/theme/app_theme.dart';
import 'package:shophop/features/buyer/presentation/pages/buyer_account_page.dart';
import 'package:shophop/features/buyer/presentation/pages/buyer_orders_page.dart';

void main() {
  testWidgets(
    'account shortcuts open real destinations and fit enlarged text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final groups = <String?>[];
      var likes = 0;
      var cart = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
              child: BuyerAccountPage(
                displayName: 'Test Buyer With A Long Name',
                token: 'test',
                email: 'buyer@example.com',
                loggingOut: false,
                onLogout: () {},
                onOpenOrders: groups.add,
                onOpenLikes: () => likes++,
                onOpenCart: () => cart++,
              ),
            ),
          ),
        ),
      );
      for (final group in ['to-ship', 'to-receive', 'to-rate', 'completed']) {
        final target = find.byKey(ValueKey('account-$group'));
        await tester.ensureVisible(target);
        await tester.tap(target);
        await tester.pump();
      }
      expect(groups, ['to-ship', 'to-receive', 'to-rate', 'completed']);
      await tester.ensureVisible(find.text('View all orders'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('View all orders'));
      expect(groups.last, isNull);
      await tester.ensureVisible(find.text('My likes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('My likes'));
      await tester.ensureVisible(find.text('My cart'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('My cart'));
      expect(likes, 1);
      expect(cart, 1);
      await tester.ensureVisible(find.text('Account settings'));
      await tester.pumpAndSettle();
      expect(find.text('Messages'), findsOneWidget);
      expect(find.text('Help & support'), findsOneWidget);
      expect(find.text('Account settings'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('purchase destination requests the selected group immediately', (
    tester,
  ) async {
    final requested = <String?>[];
    await http.runWithClient(
      () async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BuyerOrdersPage(
                token: 'test',
                initialStatusGroup: 'to-rate',
                onSessionExpired: () async {},
                onBrowseProducts: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(requested, ['to-rate']);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BuyerOrdersPage(
                token: 'test',
                initialStatusGroup: 'completed',
                onSessionExpired: () async {},
                onBrowseProducts: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(requested, ['to-rate', 'completed']);
        expect(tester.takeException(), isNull);
      },
      () => MockClient((request) async {
        requested.add(request.url.queryParameters['status_group']);
        return http.Response(
          '{"success":true,"data":{"orders":[],"has_more":false,"status_counts":{}}}',
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
  });
}
