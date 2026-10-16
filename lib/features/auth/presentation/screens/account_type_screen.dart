import 'package:flutter/material.dart';
import 'package:shophop/core/theme/app_colors.dart';
import 'package:shophop/features/buyer/registration/screens/buyer_registration_screen.dart';
import 'package:shophop/features/auth/presentation/screens/login_screen.dart';
import 'package:shophop/features/rider/registration/screens/rider_registration_screen.dart';
import 'package:shophop/features/seller/registration/screens/seller_registration_screen.dart';
import 'package:shophop/shared/widgets/shop_hop_brand.dart';

enum AccountRole { buyer, rider, seller }

class AccountTypeScreen extends StatefulWidget {
  const AccountTypeScreen({super.key});

  @override
  State<AccountTypeScreen> createState() => _AccountTypeScreenState();
}

class _AccountTypeScreenState extends State<AccountTypeScreen> {
  AccountRole? _selectedRole;

  void _continue() {
    switch (_selectedRole) {
      case AccountRole.buyer:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BuyerRegistrationScreen()));
        return;
      case AccountRole.rider:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RiderRegistrationScreen()));
        return;
      case AccountRole.seller:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SellerRegistrationScreen()));
        return;
      case null:
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).height < 670;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(18, compact ? 16 : 22, 18, 20),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const ShopHopBrand(compact: true),
                      SizedBox(height: compact ? 29 : 43),
                      const Text('Create your account', style: TextStyle(color: AppColors.navy, fontSize: 29, letterSpacing: -.8, fontWeight: FontWeight.w800, height: 1.2)),
                      const SizedBox(height: 9),
                      Text('How would you like to use ShopHop? Select a role to get started.', style: TextStyle(fontSize: 12.5, height: 1.6, color: AppColors.navy.withValues(alpha: .58))),
                      SizedBox(height: compact ? 23 : 32),
                      _RoleOption(
                        selected: _selectedRole == AccountRole.buyer,
                        icon: Icons.shopping_bag_outlined,
                        title: 'Buyer',
                        subtitle: 'Discover products and track your purchases.',
                        onTap: () => setState(() => _selectedRole = AccountRole.buyer),
                      ),
                      const SizedBox(height: 12),
                      _RoleOption(
                        selected: _selectedRole == AccountRole.seller,
                        icon: Icons.storefront_outlined,
                        title: 'Seller',
                        subtitle: 'Register your shop and grow your business.',
                        onTap: () => setState(() => _selectedRole = AccountRole.seller),
                      ),
                      const SizedBox(height: 12),
                      _RoleOption(
                        selected: _selectedRole == AccountRole.rider,
                        icon: Icons.local_shipping_outlined,
                        title: 'Rider / Courier',
                        subtitle: 'Join a logistics partner and deliver orders.',
                        onTap: () => setState(() => _selectedRole = AccountRole.rider),
                      ),
                      SizedBox(height: compact ? 19 : 26),
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Icon(Icons.verified_user_outlined, color: AppColors.tealDark, size: 18),
                        const SizedBox(width: 10),
                        Expanded(child: Text('Registration requirements depend on your role. Accounts are verified before approval.', style: TextStyle(fontSize: 11, height: 1.6, color: AppColors.navy.withValues(alpha: .53)))),
                      ]),
                    ]),
                  ),
                ),
                Container(
                  decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: AppColors.grayBorder))),
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
                  child: SafeArea(top: false, child: Column(mainAxisSize: MainAxisSize.min, children: [
                    SizedBox(width: double.infinity, height: 52, child: FilledButton(
                      onPressed: _selectedRole == null ? null : _continue,
                      child: const Text('Continue'),
                    )),
                    const SizedBox(height: 5),
                    TextButton(
                      onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen())),
                      child: const Text('Already have an account? Sign in'),
                    ),
                  ])),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleOption extends StatelessWidget {
  const _RoleOption({required this.selected, required this.icon, required this.title, required this.subtitle, required this.onTap});
  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: Material(
      color: selected ? AppColors.tealLight.withValues(alpha: .48) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: selected ? AppColors.tealDark : AppColors.grayBorder, width: selected ? 1.6 : 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 17),
          child: Row(children: [
            Container(width: 45, height: 45, decoration: BoxDecoration(color: AppColors.tealLight, borderRadius: BorderRadius.circular(13)), child: Icon(icon, size: 22, color: AppColors.tealDark)),
            const SizedBox(width: 13),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 15, color: AppColors.navy, fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(subtitle, style: TextStyle(fontSize: 11.5, height: 1.5, color: AppColors.navy.withValues(alpha: .55))),
            ])),
            const SizedBox(width: 10),
            Icon(selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, size: 23, color: selected ? AppColors.tealDark : const Color(0xFFB9C6CE)),
          ]),
        ),
      ),
    ),
  );
}
