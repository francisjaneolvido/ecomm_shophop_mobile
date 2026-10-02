import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

enum BuyerNavigationTab {
  home,
  likes,
  orders,
  notifications,
  account,
}

class BuyerBottomNavigationBar extends StatelessWidget {
  const BuyerBottomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.notificationCount = 0,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final int notificationCount;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: AppColors.grayBorder.withValues(alpha: 0.75)),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: onTap,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: AppColors.tealDark,
          unselectedItemColor: AppColors.navy.withValues(alpha: 0.45),
          selectedFontSize: 11,
          unselectedFontSize: 11,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
          elevation: 0,
          items: [
            BottomNavigationBarItem(
              icon: _NavIcon(
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                selected: currentIndex == 0,
              ),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: _NavIcon(
                icon: Icons.favorite_border_rounded,
                activeIcon: Icons.favorite_rounded,
                selected: currentIndex == 1,
              ),
              label: 'Likes',
            ),
            BottomNavigationBarItem(
              icon: _NavIcon(
                icon: Icons.receipt_long_outlined,
                activeIcon: Icons.receipt_long_rounded,
                selected: currentIndex == 2,
              ),
              label: 'Orders',
            ),
            BottomNavigationBarItem(
              icon: _NotificationIcon(
                count: notificationCount,
                selected: currentIndex == 3,
              ),
              label: 'Notifications',
            ),
            BottomNavigationBarItem(
              icon: _NavIcon(
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                selected: currentIndex == 4,
              ),
              label: 'Account',
            ),
          ],
        ),
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  const _NavIcon({
    required this.icon,
    required this.activeIcon,
    required this.selected,
  });

  final IconData icon;
  final IconData activeIcon;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 38,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? AppColors.tealLight.withValues(alpha: 0.7) : null,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(selected ? activeIcon : icon, size: 23),
    );
  }
}

class _NotificationIcon extends StatelessWidget {
  const _NotificationIcon({
    required this.count,
    required this.selected,
  });

  final int count;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _NavIcon(
          icon: Icons.notifications_none_rounded,
          activeIcon: Icons.notifications_rounded,
          selected: selected,
        ),
        if (count > 0)
          Positioned(
            right: -4,
            top: -4,
            child: Container(
              constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE94D57),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              alignment: Alignment.center,
              child: Text(
                count > 99 ? '99+' : '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
