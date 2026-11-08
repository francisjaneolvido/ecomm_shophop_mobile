import 'package:flutter/cupertino.dart';
import 'package:shophop/shared/widgets/shop_hop_navigation.dart';

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
  Widget build(BuildContext context) => ShopHopNavigation(
    index: currentIndex,
    onChanged: onTap,
    badges: {3: notificationCount},
    items: const [
      ShopHopNavItem('Home', CupertinoIcons.house, CupertinoIcons.house_fill),
      ShopHopNavItem('Likes', CupertinoIcons.heart, CupertinoIcons.heart_fill),
      ShopHopNavItem(
        'Orders',
        CupertinoIcons.doc_text,
        CupertinoIcons.doc_text_fill,
      ),
      ShopHopNavItem('Updates', CupertinoIcons.bell, CupertinoIcons.bell_fill),
      ShopHopNavItem(
        'Account',
        CupertinoIcons.person,
        CupertinoIcons.person_fill,
      ),
    ],
  );
}
