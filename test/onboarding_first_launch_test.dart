import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shophop/core/session/auth_session_service.dart';
import 'package:shophop/core/theme/app_colors.dart';
import 'package:shophop/core/theme/app_theme.dart';
import 'package:shophop/features/onboarding/presentation/screens/splash_screen.dart';

void main() {
  testWidgets(
    'Get Started appears once, then a signed-out reopen goes to login',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      await AuthSessionService.clearSession();

      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light, home: const SplashScreen()),
      );
      final wordmark = tester.widget<RichText>(
        find.text('ShopHop', findRichText: true),
      );
      final span = wordmark.text as TextSpan;
      expect(span.style?.fontFamily, 'Poppins');
      expect(span.children![0].style?.color, Colors.white);
      expect(span.children![1].style?.color, AppColors.pink);

      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.text('Get Started'), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.text('Your marketplace,\none hop away.'))
            .style
            ?.fontFamily,
        'Poppins',
      );
      expect(await AuthSessionService.hasCompletedWelcome(), isFalse);

      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();
      expect(await AuthSessionService.hasCompletedWelcome(), isTrue);
      expect(find.text('Sign in'), findsWidgets);

      await AuthSessionService.clearSession();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light, home: const SplashScreen()),
      );
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.text('Get Started'), findsNothing);
      expect(find.text('Sign in'), findsWidgets);
    },
  );
}
