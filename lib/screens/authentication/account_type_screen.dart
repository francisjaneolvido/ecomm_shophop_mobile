import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'buyer/buyer_registration_screen.dart';
import 'rider/rider_registration_screen.dart';
import 'seller/seller_registration_screen.dart';

enum AccountRole {
  buyer,
  rider,
  seller,
}

class AccountTypeScreen extends StatefulWidget {
  const AccountTypeScreen({super.key});

  @override
  State<AccountTypeScreen> createState() =>
      _AccountTypeScreenState();
}

class _AccountTypeScreenState
    extends State<AccountTypeScreen> {
  AccountRole? _selectedRole;

  void _selectRole(AccountRole role) {
    setState(() {
      _selectedRole = role;
    });
  }

  void _continue() {
    final role = _selectedRole;

    if (role == null) {
      return;
    }

    switch (role) {
      case AccountRole.buyer:
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) =>
          const BuyerRegistrationScreen(),
    ),
  );
  break;

      case AccountRole.rider:
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) =>
          const RiderRegistrationScreen(),
    ),
  );
  break;

      case AccountRole.seller:
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) =>
          const SellerRegistrationScreen(),
    ),
  );
  break;
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.navy,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grayBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),

            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  22,
                  10,
                  22,
                  24,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),

                    const SizedBox(height: 28),

                    _buildRoleCard(
                      role: AccountRole.buyer,
                      icon: Icons.shopping_bag_outlined,
                      title: 'Buyer',
                      description:
                          'Shop products, manage your orders, and track deliveries.',
                    ),

                    const SizedBox(height: 14),

                    _buildRoleCard(
                      role: AccountRole.rider,
                      icon:
                          Icons.delivery_dining_outlined,
                      title: 'Rider / Courier',
                      description:
                          'Pick up parcels and complete assigned deliveries.',
                    ),

                    const SizedBox(height: 14),

                    _buildRoleCard(
                      role: AccountRole.seller,
                      icon: Icons.storefront_outlined,
                      title: 'Seller',
                      description:
                          'List products, manage orders, and grow your ShopHop store.',
                    ),

                    const SizedBox(height: 26),

                    _buildInfoNotice(),
                  ],
                ),
              ),
            ),

            _buildBottomAction(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        18,
        12,
        18,
        0,
      ),
      child: Row(
        children: [
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: () {
                Navigator.pop(context);
              },
              borderRadius:
                  BorderRadius.circular(14),
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  borderRadius:
                      BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.grayBorder,
                  ),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 18,
                  color: AppColors.navy,
                ),
              ),
            ),
          ),

          const Spacer(),

          Row(
            children: [
              Image.asset(
                'assets/images/logo.png',
                width: 31,
                height: 31,
                fit: BoxFit.contain,
              ),

              const SizedBox(width: 8),

              const Text(
                'ShopHop',
                style: TextStyle(
                  color: AppColors.navy,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.tealLight,
            borderRadius:
                BorderRadius.circular(15),
          ),
          child: const Icon(
            Icons.group_outlined,
            color: AppColors.tealDark,
            size: 23,
          ),
        ),

        const SizedBox(height: 20),

        const Text(
          'JOIN SHOPHOP',
          style: TextStyle(
            color: AppColors.tealDark,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.3,
          ),
        ),

        const SizedBox(height: 7),

        const Text(
          'How will you use\nShopHop?',
          style: TextStyle(
            color: AppColors.navy,
            fontSize: 30,
            height: 1.12,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.7,
          ),
        ),

        const SizedBox(height: 12),

        Text(
          'Choose the account type that best matches what you want to do.',
          style: TextStyle(
            color: AppColors.navy.withValues(
              alpha: 0.52,
            ),
            fontSize: 13,
            height: 1.55,
          ),
        ),
      ],
    );
  }

  Widget _buildRoleCard({
    required AccountRole role,
    required IconData icon,
    required String title,
    required String description,
  }) {
    final isSelected =
        _selectedRole == role;

    return Semantics(
      button: true,
      selected: isSelected,
      label: '$title account',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            _selectRole(role);
          },
          borderRadius:
              BorderRadius.circular(20),
          child: AnimatedContainer(
            duration:
                const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            width: double.infinity,
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.tealLight
                      .withValues(alpha: 0.72)
                  : Colors.white,
              borderRadius:
                  BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? AppColors.teal
                    : AppColors.grayBorder,
                width:
                    isSelected ? 1.6 : 1,
              ),
              boxShadow: [
                if (!isSelected)
                  BoxShadow(
                    color: AppColors.navy
                        .withValues(
                      alpha: 0.035,
                    ),
                    blurRadius: 18,
                    offset:
                        const Offset(0, 7),
                  ),
              ],
            ),
            child: Row(
              crossAxisAlignment:
                  CrossAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(
                    milliseconds: 180,
                  ),
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.teal
                        : AppColors.tealLight,
                    borderRadius:
                        BorderRadius.circular(15),
                  ),
                  child: Icon(
                    icon,
                    size: 23,
                    color: isSelected
                        ? Colors.white
                        : AppColors.tealDark,
                  ),
                ),

                const SizedBox(width: 15),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontSize: 15,
                          fontWeight:
                              FontWeight.w700,
                        ),
                      ),

                      const SizedBox(height: 5),

                      Text(
                        description,
                        style: TextStyle(
                          color: AppColors.navy
                              .withValues(
                            alpha: 0.48,
                          ),
                          fontSize: 11,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                AnimatedContainer(
                  duration: const Duration(
                    milliseconds: 180,
                  ),
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? AppColors.teal
                        : Colors.transparent,
                    border: Border.all(
                      color: isSelected
                          ? AppColors.teal
                          : AppColors.grayBorder,
                      width: 1.4,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: Colors.white,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(17),
        border: Border.all(
          color: AppColors.grayBorder,
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.tealLight,
              borderRadius:
                  BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.info_outline_rounded,
              size: 18,
              color: AppColors.tealDark,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Text(
              'Your account type determines the registration requirements and the features available after approval.',
              style: TextStyle(
                color: AppColors.navy
                    .withValues(
                  alpha: 0.48,
                ),
                fontSize: 11,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomAction() {
    final canContinue =
        _selectedRole != null;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        22,
        14,
        22,
        18,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: AppColors.grayBorder
                .withValues(alpha: 0.8),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed:
                    canContinue ? _continue : null,
                style: ElevatedButton.styleFrom(
  elevation: 0,
  backgroundColor: AppColors.teal,
                  disabledBackgroundColor:
                      AppColors.grayBorder,
                  foregroundColor:
                      Colors.white,
                  disabledForegroundColor:
                      AppColors.navy
                          .withValues(
                    alpha: 0.30,
                  ),
                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Continue',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),

                    if (canContinue) ...[
                      const SizedBox(width: 9),

                      const Icon(
                        Icons
                            .arrow_forward_rounded,
                        size: 19,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            Row(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                Text(
                  'Already have an account? ',
                  style: TextStyle(
                    color: AppColors.navy
                        .withValues(
                      alpha: 0.46,
                    ),
                    fontSize: 11,
                    fontWeight:
                        FontWeight.w500,
                  ),
                ),

                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                  },
                  child: const Padding(
                    padding:
                        EdgeInsets.symmetric(
                      vertical: 5,
                    ),
                    child: Text(
                      'Sign in',
                      style: TextStyle(
                        color:
                            AppColors.tealDark,
                        fontSize: 11,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}