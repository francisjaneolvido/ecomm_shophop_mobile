import 'package:flutter/material.dart';
import 'package:shophop/core/theme/app_colors.dart';
import 'package:shophop/features/auth/presentation/screens/login_screen.dart';
import 'package:shophop/features/auth/presentation/screens/account_type_screen.dart';
import 'package:shophop/shared/widgets/shop_hop_brand.dart';

/// Clean, full-height ShopHop welcome screen. No floating cards or gradients.
class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  void _openLogin(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );

  void _openRegistration(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AccountTypeScreen()),
      );

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compact = size.height < 690 || size.width < 350;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: size.width >= 600 ? 32 : 20,
              vertical: compact ? 16 : 23,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight - (compact ? 32 : 46)),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Align(alignment: Alignment.centerLeft, child: ShopHopBrand(compact: true)),
                        SizedBox(height: compact ? 27 : 46),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                            decoration: BoxDecoration(color: AppColors.tealLight, borderRadius: BorderRadius.circular(100)),
                            child: const Text('SHOP   •   SELL   •   DELIVER', style: TextStyle(color: AppColors.tealDark, fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.w800)),
                          ),
                        ),
                        const SizedBox(height: 19),
                        Text.rich(
                          TextSpan(children: const [
                            TextSpan(text: 'Everything you love,\n', style: TextStyle(color: AppColors.navy)),
                            TextSpan(text: 'just a hop away.', style: TextStyle(color: AppColors.tealDark)),
                          ]),
                          style: TextStyle(fontSize: size.width < 370 ? 30 : 35, fontWeight: FontWeight.w800, height: 1.16, letterSpacing: -1.2),
                        ),
                        const SizedBox(height: 15),
                        Text(
                          'Discover everyday finds, connect with local shops, and follow each order from checkout to delivery.',
                          style: TextStyle(color: AppColors.navy.withValues(alpha: .61), fontSize: 13, height: 1.65),
                        ),
                        SizedBox(height: compact ? 25 : 36),
                        const Row(
                          children: [
                            Expanded(child: _Pillar(icon: Icons.shopping_bag_outlined, name: 'Shop')),
                            SizedBox(width: 8),
                            Expanded(child: _Pillar(icon: Icons.storefront_outlined, name: 'Sell')),
                            SizedBox(width: 8),
                            Expanded(child: _Pillar(icon: Icons.local_shipping_outlined, name: 'Deliver')),
                          ],
                        ),
                        const Spacer(),
                        SizedBox(height: compact ? 22 : 32),
                        SizedBox(height: 52, child: FilledButton(
                          onPressed: () => _openLogin(context),
                          child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text('Sign in to ShopHop'), SizedBox(width: 10), Icon(Icons.arrow_forward_rounded, size: 18)]),
                        )),
                        const SizedBox(height: 11),
                        SizedBox(height: 52, child: OutlinedButton(
                          onPressed: () => _openRegistration(context),
                          child: const Text('Create an account'),
                        )),
                        const SizedBox(height: 17),
                        Text('Your marketplace, connected from checkout to delivery.', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: AppColors.navy.withValues(alpha: .46))),
                        const SizedBox(height: 4),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Pillar extends StatelessWidget {
  const _Pillar({required this.icon, required this.name});
  final IconData icon;
  final String name;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        width: 52, height: 52,
        decoration: BoxDecoration(color: AppColors.grayBg, border: Border.all(color: AppColors.grayBorder), borderRadius: BorderRadius.circular(16)),
        child: Icon(icon, size: 23, color: AppColors.navy),
      ),
      const SizedBox(height: 8),
      Text(name, style: const TextStyle(color: AppColors.navy, fontSize: 12, fontWeight: FontWeight.w700)),
    ],
  );
}
