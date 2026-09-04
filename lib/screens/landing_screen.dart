// Path in your project: lib/screens/landing_screen.dart

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Decorative teal blobs — same visual language as the web hero/auth panels
          Positioned(
            top: -60,
            right: -60,
            child: _blob(180, AppColors.tealLight.withValues(alpha: 0.6)),
          ),
          Positioned(
            top: 120,
            left: -80,
            child: _blob(160, AppColors.grayBg),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const Spacer(flex: 3),

                  Image.asset('assets/images/logo.png', width: 110),

                  const SizedBox(height: 32),

                  Text(
                    'Everything You Love,\nJust a Hop Away.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: AppColors.navy,
                      height: 1.3,
                    ),
                  ),

                  const SizedBox(height: 14),

                  Text(
                    "Discover everyday essentials, trending finds, and products you'll love — all in one place.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.navy.withValues(alpha: 0.6),
                      height: 1.5,
                    ),
                  ),

                  const Spacer(flex: 3),

                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: () {
                        // TODO: navigate to onboarding / account-type selection
                        // once the login & registration screens are built.
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.teal,
                        foregroundColor: AppColors.navy,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      child: const Text(
                        'Get Started',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  TextButton(
                    onPressed: () {
                      // TODO: navigate to sign in screen
                    },
                    child: RichText(
                      text: TextSpan(
                        text: 'Already have an account? ',
                        style: TextStyle(
                          color: AppColors.navy.withValues(alpha: 0.6),
                          fontSize: 13,
                        ),
                        children: [
                          TextSpan(
                            text: 'Sign In',
                            style: TextStyle(
                              color: AppColors.tealDark,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _blob(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}