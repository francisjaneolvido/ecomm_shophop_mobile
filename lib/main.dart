import 'package:flutter/material.dart';
import 'package:shophop/core/theme/app_theme.dart';
import 'package:shophop/features/onboarding/presentation/screens/splash_screen.dart';
import 'package:shophop/shared/widgets/shop_hop_scan_feedback.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ShopHopScanFeedback.loadPreferences().timeout(
    const Duration(seconds: 2),
    onTimeout: () {},
  );
  runApp(const ShopHopApp());
}

class ShopHopApp extends StatelessWidget {
  const ShopHopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ShopHop',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      themeMode: ThemeMode.light,
      home: const SplashScreen(),
    );
  }
}
