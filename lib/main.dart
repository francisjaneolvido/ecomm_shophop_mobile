import 'package:flutter/material.dart';
import 'package:shophop/core/theme/app_theme.dart';
import 'package:shophop/features/onboarding/presentation/screens/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
      home: const SplashScreen(),
    );
  }
}
