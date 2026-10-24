import 'package:flutter/material.dart';
import 'package:shophop/core/theme/app_colors.dart';
import 'package:shophop/features/auth/presentation/screens/login_screen.dart';

/// Compact ShopHop welcome screen with a single primary action.
class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  void _getStarted(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compact = size.height < 700;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                compact ? 20 : 30,
                20,
                compact ? 18 : 24,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - (compact ? 38 : 54),
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Spacer(),
                          _HeroMark(compact: compact),
                          SizedBox(height: compact ? 26 : 32),
                          const Text(
                            'Your marketplace,\none hop away.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.navy,
                              fontSize: 30,
                              height: 1.12,
                              letterSpacing: -1.05,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Text(
                              'Shop local finds, grow your store, and keep every delivery connected in one place.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.navy.withValues(alpha: .55),
                                fontSize: 12.5,
                                height: 1.6,
                              ),
                            ),
                          ),
                          SizedBox(height: compact ? 20 : 26),
                          const _FeatureLine(),
                          const Spacer(),
                          SizedBox(height: compact ? 28 : 38),
                          SizedBox(
                            height: 54,
                            child: FilledButton(
                              onPressed: () => _getStarted(context),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.teal,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text(
                                'Get Started',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HeroMark extends StatelessWidget {
  const _HeroMark({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final heroSize = compact ? 174.0 : 194.0;
    final ringSize = compact ? 138.0 : 154.0;
    final centerSize = compact ? 94.0 : 104.0;
    final logoSize = compact ? 69.0 : 76.0;

    return Center(
      child: SizedBox(
        width: heroSize,
        height: heroSize,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Outer orbit.
            Container(
              width: heroSize - 20,
              height: heroSize - 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.navy.withValues(alpha: .08),
                  width: 1.2,
                ),
              ),
            ),

            // Soft mint hero ring.
            Container(
              width: ringSize,
              height: ringSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.tealLight.withValues(alpha: .72),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.teal.withValues(alpha: .08),
                    blurRadius: 30,
                    spreadRadius: 3,
                  ),
                ],
              ),
            ),

            // Small orbit accents.
            Positioned(
              top: compact ? 12 : 14,
              left: compact ? 49 : 56,
              child: _dot(8),
            ),
            Positioned(
              right: compact ? 6 : 8,
              top: compact ? 78 : 86,
              child: _dot(7),
            ),
            Positioned(
              bottom: compact ? 18 : 20,
              left: compact ? 48 : 54,
              child: _dot(5),
            ),

            // Main logo disc.
            Container(
              width: centerSize,
              height: centerSize,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.grayBorder.withValues(alpha: .75),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.navy.withValues(alpha: .09),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Center(
                child: Image.asset(
                  'assets/images/logo.png',
                  width: logoSize,
                  height: logoSize,
                  fit: BoxFit.contain,
                ),
              ),
            ),

            // Sell / store bubble.
            Positioned(
              left: 0,
              top: compact ? 64 : 72,
              child: const _FloatingBubble(
                icon: Icons.storefront_outlined,
                iconColor: AppColors.navy,
                size: 43,
              ),
            ),

            // Shop bubble.
            Positioned(
              right: compact ? 7 : 8,
              top: compact ? 14 : 16,
              child: const _FloatingBubble(
                icon: Icons.shopping_bag_outlined,
                iconColor: AppColors.tealDark,
                size: 40,
              ),
            ),

            // Delivery bubble.
            Positioned(
              right: 0,
              bottom: compact ? 14 : 16,
              child: const _FloatingBubble(
                icon: Icons.local_shipping_outlined,
                iconColor: AppColors.navy,
                size: 45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dot(double size) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppColors.teal,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _FloatingBubble extends StatelessWidget {
  const _FloatingBubble({
    required this.icon,
    required this.iconColor,
    required this.size,
  });

  final IconData icon;
  final Color iconColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.grayBorder.withValues(alpha: .9),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: .07),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Icon(
        icon,
        size: size * .43,
        color: iconColor,
      ),
    );
  }
}

class _FeatureLine extends StatelessWidget {
  const _FeatureLine();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.grayBg.withValues(alpha: .78),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.grayBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const _MiniFeature(icon: Icons.shopping_bag_outlined, label: 'Shop'),
          _divider(),
          const _MiniFeature(icon: Icons.storefront_outlined, label: 'Sell'),
          _divider(),
          const _MiniFeature(
            icon: Icons.local_shipping_outlined,
            label: 'Deliver',
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 18,
      margin: const EdgeInsets.symmetric(horizontal: 14),
      color: AppColors.grayBorder,
    );
  }
}

class _MiniFeature extends StatelessWidget {
  const _MiniFeature({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.tealDark),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.navy,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
