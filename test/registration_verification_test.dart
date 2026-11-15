import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shophop/features/auth/domain/registration_role.dart';
import 'package:shophop/features/auth/presentation/screens/email_verification_screen.dart';

void main() {
  testWidgets(
    'OTP failure keeps verification open and never completes registration',
    (tester) async {
      var completed = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: EmailVerificationScreen(
            email: 'applicant@example.test',
            role: RegistrationRole.rider,
            onVerifyCode: (_) async => 'The verification code is incorrect.',
            onResendCode: () async => null,
            onVerified: () => completed++,
          ),
        ),
      );
      await tester.enterText(find.byType(TextField).first, '123456');
      await tester.pump();
      await tester.ensureVisible(find.text('Verify Rider Email'));
      await tester.tap(find.text('Verify Rider Email'));
      await tester.pump();
      expect(completed, 0);
      expect(find.text('The verification code is incorrect.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('confirmed OTP completes once and blocks repeated verification', (
    tester,
  ) async {
    var requests = 0;
    var completed = 0;
    final response = Completer<String?>();
    await tester.pumpWidget(
      MaterialApp(
        home: EmailVerificationScreen(
          email: 'applicant@example.test',
          role: RegistrationRole.seller,
          onVerifyCode: (_) {
            requests++;
            return response.future;
          },
          onResendCode: () async => null,
          onVerified: () => completed++,
        ),
      ),
    );
    await tester.enterText(find.byType(TextField).first, '123456');
    await tester.pump();
    await tester.ensureVisible(find.text('Verify Seller Email'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Verify Seller Email'));
    await tester.pump();
    expect(requests, 1);
    expect(completed, 0);
    response.complete(null);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(completed, 1);
    await tester.tap(find.text('Verify Seller Email'));
    await tester.pump();
    expect(requests, 1);
    expect(completed, 1);
    await tester.pumpWidget(const SizedBox());
  });
}
