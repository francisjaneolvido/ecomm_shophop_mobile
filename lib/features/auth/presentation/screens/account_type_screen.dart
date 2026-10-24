import 'package:flutter/material.dart';
import 'package:shophop/core/theme/app_colors.dart';
import 'package:shophop/features/auth/presentation/screens/login_screen.dart';
import 'package:shophop/features/buyer/registration/screens/buyer_registration_screen.dart';
import 'package:shophop/features/rider/registration/screens/rider_registration_screen.dart';
import 'package:shophop/features/seller/registration/screens/seller_registration_screen.dart';

enum AccountRole { buyer, seller, rider }

class AccountTypeScreen extends StatefulWidget {
  const AccountTypeScreen({super.key});

  @override
  State<AccountTypeScreen> createState() => _AccountTypeScreenState();
}

class _AccountTypeScreenState extends State<AccountTypeScreen> {
  AccountRole? _selectedRole;

  void _selectRole(AccountRole role) {
    setState(() => _selectedRole = role);
  }

  void _continue() {
    switch (_selectedRole) {
      case AccountRole.buyer:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const BuyerRegistrationScreen()),
        );
        return;
      case AccountRole.seller:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SellerRegistrationScreen()),
        );
        return;
      case AccountRole.rider:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const RiderRegistrationScreen()),
        );
        return;
      case null:
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compact = size.height < 700;

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
                    padding: EdgeInsets.fromLTRB(
                      20,
                      compact ? 18 : 24,
                      20,
                      20,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: compact ? 54 : 60,
                            height: compact ? 54 : 60,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.tealLight.withValues(alpha: .55),
                              shape: BoxShape.circle,
                            ),
                            child: Image.asset(
                              'assets/images/logo.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        SizedBox(height: compact ? 24 : 30),
                        const Center(
                          child: Text(
                            'Choose your role',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.navy,
                              fontSize: 28,
                              letterSpacing: -.8,
                              fontWeight: FontWeight.w800,
                              height: 1.15,
                            ),
                          ),
                        ),
                        const SizedBox(height: 9),
                        Center(
                          child: Text(
                            "Select how you'd like to use ShopHop.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.5,
                              color: AppColors.navy.withValues(alpha: .58),
                            ),
                          ),
                        ),
                        SizedBox(height: compact ? 24 : 30),
                        _RoleOption(
                          selected: _selectedRole == AccountRole.buyer,
                          icon: Icons.shopping_bag_outlined,
                          title: 'Buyer',
                          subtitle: 'Shop products and track your orders.',
                          onTap: () => _selectRole(AccountRole.buyer),
                        ),
                        const SizedBox(height: 12),
                        _RoleOption(
                          selected: _selectedRole == AccountRole.seller,
                          icon: Icons.storefront_outlined,
                          title: 'Seller',
                          subtitle: 'Create your shop and sell products.',
                          onTap: () => _selectRole(AccountRole.seller),
                        ),
                        const SizedBox(height: 12),
                        _RoleOption(
                          selected: _selectedRole == AccountRole.rider,
                          icon: Icons.local_shipping_outlined,
                          title: 'Rider',
                          subtitle: 'Accept deliveries and manage orders.',
                          onTap: () => _selectRole(AccountRole.rider),
                        ),
                        SizedBox(height: compact ? 18 : 22),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 13,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.tealLight.withValues(alpha: .38),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.teal.withValues(alpha: .18),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.info_outline_rounded,
                                color: AppColors.tealDark,
                                size: 18,
                              ),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Text(
                                  'Some roles require verification before your account is approved.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    height: 1.5,
                                    color: AppColors.navy.withValues(alpha: .62),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      top: BorderSide(color: AppColors.grayBorder),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: FilledButton(
                            onPressed:
                                _selectedRole == null ? null : _continue,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.teal,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor:
                                  const Color(0xFFE7EBEE),
                              disabledForegroundColor:
                                  AppColors.navy.withValues(alpha: .48),
                              elevation: 0,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text(
                              'Continue',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 7),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Already have an account?',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.navy.withValues(alpha: .58),
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context)
                                  .pushReplacement(
                                MaterialPageRoute(
                                  builder: (_) => const LoginScreen(),
                                ),
                              ),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.tealDark,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 7,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'Sign in',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
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
  const _RoleOption({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$title. $subtitle',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.tealLight.withValues(alpha: .38)
              : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppColors.teal : AppColors.grayBorder,
            width: selected ? 1.6 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.teal.withValues(alpha: .08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 15,
                vertical: 16,
              ),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.teal.withValues(alpha: .16)
                          : AppColors.tealLight.withValues(alpha: .72),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      icon,
                      size: 22,
                      color:
                          selected ? AppColors.tealDark : AppColors.tealDark,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 15,
                            color: AppColors.navy,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1.45,
                            color: AppColors.navy.withValues(alpha: .56),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 160),
                    child: Icon(
                      selected
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      key: ValueKey(selected),
                      size: 23,
                      color: selected
                          ? AppColors.teal
                          : const Color(0xFFB9C6CE),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
