// Path in your project: test/widget_test.dart
//
// Basic smoke test for the ShopHop app. The default Flutter template test
// referenced `MyApp` and a counter/+ icon, which no longer exist now that
// the root widget is `ShopHopApp` (see lib/main.dart) with a splash +
// landing flow instead. This test just checks the app builds and renders
// its first screen (the splash screen) without throwing.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shophop/main.dart';

void main() {
  testWidgets('ShopHop app builds and shows the splash screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ShopHopApp());

    // The splash screen should render immediately.
    expect(find.byType(Scaffold), findsOneWidget);

    // Let a few animation frames pass. We intentionally don't use
    // pumpAndSettle() here since the splash screen's hop animation +
    // delayed navigation keeps timers active for a couple of seconds.
    await tester.pump(const Duration(milliseconds: 200));
  });
}