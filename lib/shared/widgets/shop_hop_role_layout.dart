import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shophop/core/theme/app_colors.dart';
import 'package:shophop/shared/widgets/shop_hop_navigation.dart';

enum ShopHopRole { seller, logistics, linehaul, rider }

extension ShopHopRoleNavigation on ShopHopRole {
  String get label => switch (this) {
    ShopHopRole.seller => 'Seller',
    ShopHopRole.logistics => 'Logistics',
    ShopHopRole.linehaul => 'Linehaul',
    ShopHopRole.rider => 'Rider',
  };

  List<ShopHopNavItem> get destinations => switch (this) {
    ShopHopRole.seller => const [
      ShopHopNavItem('Home', CupertinoIcons.house, CupertinoIcons.house_fill),
      ShopHopNavItem(
        'Orders',
        CupertinoIcons.doc_text,
        CupertinoIcons.doc_text_fill,
      ),
      ShopHopNavItem(
        'Products',
        CupertinoIcons.cube_box,
        CupertinoIcons.cube_box_fill,
      ),
      ShopHopNavItem(
        'Earnings',
        CupertinoIcons.money_dollar_circle,
        CupertinoIcons.money_dollar_circle_fill,
      ),
      ShopHopNavItem(
        'Account',
        CupertinoIcons.person,
        CupertinoIcons.person_fill,
      ),
    ],
    ShopHopRole.logistics => const [
      ShopHopNavItem('Home', CupertinoIcons.house, CupertinoIcons.house_fill),
      ShopHopNavItem(
        'Manifests',
        CupertinoIcons.cube_box,
        CupertinoIcons.cube_box_fill,
      ),
      ShopHopNavItem(
        'Scan',
        CupertinoIcons.qrcode_viewfinder,
        CupertinoIcons.qrcode_viewfinder,
      ),
      ShopHopNavItem(
        'Activity',
        CupertinoIcons.clock,
        CupertinoIcons.clock_fill,
      ),
      ShopHopNavItem(
        'Account',
        CupertinoIcons.person,
        CupertinoIcons.person_fill,
      ),
    ],
    ShopHopRole.linehaul => const [
      ShopHopNavItem('Trips', CupertinoIcons.map, CupertinoIcons.map_fill),
      ShopHopNavItem(
        'Vehicle',
        CupertinoIcons.car_detailed,
        CupertinoIcons.car_detailed,
      ),
      ShopHopNavItem(
        'Scan',
        CupertinoIcons.qrcode_viewfinder,
        CupertinoIcons.qrcode_viewfinder,
      ),
      ShopHopNavItem(
        'History',
        CupertinoIcons.clock,
        CupertinoIcons.clock_fill,
      ),
      ShopHopNavItem(
        'Account',
        CupertinoIcons.person,
        CupertinoIcons.person_fill,
      ),
    ],
    ShopHopRole.rider => const [
      ShopHopNavItem('Home', CupertinoIcons.house, CupertinoIcons.house_fill),
      ShopHopNavItem(
        'Tasks',
        CupertinoIcons.doc_text,
        CupertinoIcons.doc_text_fill,
      ),
      ShopHopNavItem(
        'Scan',
        CupertinoIcons.qrcode_viewfinder,
        CupertinoIcons.qrcode_viewfinder,
      ),
      ShopHopNavItem(
        'Wallet',
        CupertinoIcons.money_dollar_circle,
        CupertinoIcons.money_dollar_circle_fill,
      ),
      ShopHopNavItem(
        'Account',
        CupertinoIcons.person,
        CupertinoIcons.person_fill,
      ),
    ],
  };
}

/// Operational headers use the same teal palette as the web theme.
class ShopHopRoleAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ShopHopRoleAppBar({
    super.key,
    required this.role,
    required this.index,
    required this.onRefresh,
    this.refreshing = false,
  });
  final ShopHopRole role;
  final int index;
  final VoidCallback? onRefresh;
  final bool refreshing;
  @override
  Size get preferredSize => const Size.fromHeight(64);
  @override
  Widget build(BuildContext context) => AppBar(
    automaticallyImplyLeading: false,
    toolbarHeight: 64,
    titleSpacing: 14,
    backgroundColor: AppColors.tealDark,
    foregroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    systemOverlayStyle: SystemUiOverlayStyle.light,
    title: Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .18),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(
            role.destinations[index].icon,
            size: 21,
            color: AppColors.tealLight,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (MediaQuery.textScalerOf(context).scale(11) <= 15.4)
                Text(
                  'ShopHop ${role.label}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: Colors.white,
                  ),
                ),
              Text(
                role.destinations[index].label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
    actions: [
      if (refreshing)
        const Padding(
          padding: EdgeInsets.all(16),
          child: SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.tealLight,
            ),
          ),
        )
      else
        IconButton(
          tooltip: 'Refresh ${role.label} data',
          onPressed: onRefresh,
          icon: const Icon(
            CupertinoIcons.arrow_clockwise,
            size: 21,
            color: Colors.white,
          ),
        ),
      const SizedBox(width: 4),
    ],
  );
}

class ShopHopRoleIntro extends StatelessWidget {
  const ShopHopRoleIntro({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon = CupertinoIcons.house,
    this.badge,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final String? badge;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [AppColors.tealDark, AppColors.teal],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(14),
      boxShadow: [
        BoxShadow(
          color: AppColors.tealDark.withValues(alpha: .12),
          blurRadius: 16,
          offset: const Offset(0, 5),
        ),
      ],
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .18),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 21, color: AppColors.tealLight),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  height: 1.5,
                  fontWeight: FontWeight.w400,
                  color: Colors.white,
                ),
              ),
              if (badge != null) ...[
                const SizedBox(height: 9),
                Text(
                  badge!,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.tealLight,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

class ShopHopRoleMetric extends StatelessWidget {
  const ShopHopRoleMetric({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.accent = false,
    this.hint,
    this.onTap,
  });
  final String label;
  final String value;
  final IconData icon;
  final bool accent;
  final String? hint;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(11),
      side: const BorderSide(color: AppColors.border),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 17, color: AppColors.tealDark),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                if (onTap != null)
                  const Icon(
                    CupertinoIcons.chevron_right,
                    size: 11,
                    color: AppColors.textMuted,
                  ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              value,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 21,
                fontWeight: FontWeight.w700,
                color: accent ? AppColors.tealDark : AppColors.navy,
              ),
            ),
            if (hint != null)
              Text(
                hint!,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 10,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textMuted,
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
