import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shophop/core/theme/app_theme.dart';
import 'package:shophop/shared/widgets/shop_hop_navigation.dart';
import 'package:shophop/shared/widgets/shop_hop_ui.dart';

const destinations = [
  ShopHopNavItem('Home', Icons.home_outlined, Icons.home),
  ShopHopNavItem('Likes', Icons.favorite_outline, Icons.favorite),
  ShopHopNavItem('Orders', Icons.receipt_long_outlined, Icons.receipt_long),
  ShopHopNavItem('Updates', Icons.notifications_none, Icons.notifications),
  ShopHopNavItem('Account', Icons.person_outline, Icons.person),
];

void main() {
  testWidgets('Shared components fit a narrow phone with enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var actionCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.screenPadding),
            child: Column(
              children: [
                ShopHopSectionHeading(
                  title: 'Your account settings',
                  subtitle: 'Manage your ShopHop profile',
                  trailing: TextButton(
                    onPressed: () {},
                    child: const Text('Edit'),
                  ),
                ),
                const SizedBox(height: 16),
                const ShopHopSurface(
                  child: ShopHopStatusPill(
                    icon: Icons.schedule,
                    label: 'Waiting for administrator product approval',
                  ),
                ),
                const SizedBox(height: 16),
                ShopHopEmptyState(
                  icon: Icons.shopping_bag_outlined,
                  title: 'No products yet',
                  description: 'Your approved products will appear here.',
                  actionLabel: 'Browse products',
                  onAction: () => actionCount++,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Browse products'));
    await tester.tap(find.text('Browse products'));
    expect(actionCount, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Shared navigation keeps hover, focus and press clear while supporting counts and tab changes',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var selected = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: Text('Selected: $selected'),
              bottomNavigationBar: RepaintBoundary(
                key: const ValueKey('navigation-paint'),
                child: ShopHopNavigation(
                  items: destinations,
                  index: selected,
                  badges: const {0: -1, 3: 150},
                  onChanged: (value) => setState(() => selected = value),
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('99+'), findsWidgets);
      expect(find.text('-1'), findsNothing);
      await tester.pumpAndSettle();
      final idle = await _navigationPixels(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump(const Duration(milliseconds: 120));
      expect(
        await _navigationPixels(tester),
        orderedEquals(idle),
        reason: 'Keyboard focus must not paint a tab background.',
      );
      // Cache the tab position before hover can show a duplicate tooltip label.
      final accountCenter = tester.getCenter(find.text('Account'));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(accountCenter);
      await tester.pump(const Duration(milliseconds: 120));
      expect(
        await _navigationPixels(tester),
        orderedEquals(idle),
        reason: 'Hover must not paint a tab background.',
      );
      await mouse.down(accountCenter);
      await tester.pump(const Duration(milliseconds: 120));
      expect(
        await _navigationPixels(tester),
        orderedEquals(idle),
        reason: 'Press must not paint a ripple or tab background.',
      );
      await mouse.up();
      await tester.pumpAndSettle();
      expect(selected, 4);
      expect(find.text('Selected: 4'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Both confirmation helpers preserve cancel and confirm results', (
    tester,
  ) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: Column(
              children: [
                TextButton(
                  onPressed: () async {
                    result = await showShopHopConfirmation(
                      context,
                      title: 'Sign out?',
                      message: 'You can sign in again.',
                      destructive: true,
                    );
                  },
                  child: const Text('Account action'),
                ),
                TextButton(
                  onPressed: () async {
                    result = await shopHopConfirm(
                      context,
                      title: 'Update stock?',
                      message: 'Confirm your stock update.',
                    );
                  },
                  child: const Text('Seller action'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    for (final label in ['Account action', 'Seller action']) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result, isFalse);
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
      expect(tester.takeException(), isNull);
    }
  });
}

// Compare the painted bar so hover regressions are caught, not just style values.
Future<List<int>> _navigationPixels(WidgetTester tester) async =>
    (await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('navigation-paint')),
      );
      final image = await boundary.toImage(pixelRatio: 1);
      try {
        final data = await image.toByteData();
        return data!.buffer.asUint8List().toList();
      } finally {
        image.dispose();
      }
    }))!;
