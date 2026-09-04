// Path in your project: lib/screens/splash_screen.dart

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'landing_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hopController;
  late final Animation<double> _hopHeight;
  late final Animation<double> _shadowScale;

  static const int _totalHops = 3;
  int _completedHops = 0;
  bool _showWordmark = false;

  @override
  void initState() {
    super.initState();

    _hopController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );

    // Vertical hop: quick rise, bouncy landing — feels like an actual jump
    _hopHeight = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: -46.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween(begin: -46.0, end: 0.0)
            .chain(CurveTween(curve: Curves.bounceOut)),
        weight: 55,
      ),
    ]).animate(_hopController);

    // Shadow shrinks mid-air, grows again on landing
    _shadowScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.45), weight: 45),
      TweenSequenceItem(tween: Tween(begin: 0.45, end: 1.0), weight: 55),
    ]).animate(_hopController);

    _hopController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _completedHops++;
        if (_completedHops < _totalHops) {
          _hopController.forward(from: 0);
        } else {
          setState(() => _showWordmark = true);
          _goToLanding();
        }
      }
    });

    _hopController.forward();
  }

  void _goToLanding() {
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 500),
          pageBuilder: (_, animation, __) =>
              FadeTransition(opacity: animation, child: const LandingScreen()),
        ),
      );
    });
  }

  @override
  void dispose() {
    _hopController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _hopController,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, _hopHeight.value),
                  child: child,
                );
              },
              child: Image.asset(
                'assets/images/logo.png',
                width: 150,
              ),
            ),
            const SizedBox(height: 14),
            AnimatedBuilder(
              animation: _hopController,
              builder: (context, child) {
                return Opacity(
                  opacity: _shadowScale.value.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scaleX: _shadowScale.value,
                    child: Container(
                      width: 64,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(50),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 28),
            AnimatedOpacity(
              opacity: _showWordmark ? 1 : 0,
              duration: const Duration(milliseconds: 400),
              child: Column(
                children: [
                  const Text(
                    'ShopHop',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'HOP IN. SHOP MORE.',
                    style: TextStyle(
                      color: AppColors.teal,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}