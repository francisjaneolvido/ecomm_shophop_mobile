import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shophop/features/auth/presentation/screens/login_screen.dart';

void main() {
  testWidgets('Google button starts sign-in and reports missing OAuth setup', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    final googleButton = find.text('Continue with Google');
    expect(googleButton, findsOneWidget);

    await tester.ensureVisible(googleButton);
    await tester.tap(googleButton);
    await tester.pump();

    expect(find.textContaining('Google sign-in is not configured'), findsOneWidget);
  });
}
