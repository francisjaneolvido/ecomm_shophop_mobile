import 'package:flutter/material.dart';
import 'package:shophop/shared/widgets/shop_hop_navigation.dart';

class BuyerBottomNavigationBar extends StatelessWidget {
  const BuyerBottomNavigationBar({
    super.key, required this.currentIndex, required this.onTap, this.notificationCount = 0,
  });
  final int currentIndex;
  final ValueChanged<int> onTap;
  final int notificationCount;

  @override
  Widget build(BuildContext context) => ShopHopNavigation(
    index: currentIndex,
    onChanged: onTap,
    badges: {3: notificationCount},
    items: const [
      ShopHopNavItem('Home', Icons.home_outlined, Icons.home_rounded),
      ShopHopNavItem('Likes', Icons.favorite_outline_rounded, Icons.favorite_rounded),
      ShopHopNavItem('Orders', Icons.receipt_long_outlined, Icons.receipt_long_rounded),
      ShopHopNavItem('Updates', Icons.notifications_none_rounded, Icons.notifications_rounded),
      ShopHopNavItem('Account', Icons.person_outline_rounded, Icons.person_rounded),
    ],
  );
}
