import 'package:flutter/material.dart';
import 'package:shophop/core/theme/app_colors.dart';

/// Identical navigation chrome for Buyer, Seller, Rider, Linehaul, and Logistics.
/// Each role supplies its own destinations; Scan always uses the same icon.
class ShopHopNavItem {
  const ShopHopNavItem(this.label, this.icon, this.activeIcon);
  final String label;
  final IconData icon;
  final IconData activeIcon;
}

class ShopHopNavigation extends StatelessWidget {
  const ShopHopNavigation({
    super.key,
    required this.items,
    required this.index,
    required this.onChanged,
    this.badges = const {},
  });
  final List<ShopHopNavItem> items;
  final int index;
  final ValueChanged<int> onChanged;
  final Map<int, int> badges;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: AppColors.grayBorder)),
        boxShadow: [BoxShadow(
          color: AppColors.navy.withValues(alpha: 0.06),
          blurRadius: 18,
          offset: const Offset(0, -5),
        )],
      ),
      child: SafeArea(
        top: false,
        child: BottomNavigationBar(
          currentIndex: index < 0 ? 0 : (index >= items.length ? items.length - 1 : index),
          onTap: onChanged,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          backgroundColor: Colors.white,
          selectedItemColor: AppColors.tealDark,
          unselectedItemColor: const Color(0xFF64748B),
          selectedFontSize: 11,
          unselectedFontSize: 10.5,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w800),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
          items: [
            for (var i = 0; i < items.length; i++)
              BottomNavigationBarItem(
                label: items[i].label,
                icon: _IconBadge(icon: items[i].icon, count: badges[i] ?? 0),
                activeIcon: _IconBadge(icon: items[i].activeIcon, count: badges[i] ?? 0),
              ),
          ],
        ),
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon, required this.count});
  final IconData icon;
  final int count;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 38,
        height: 30,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Icon(icon, size: 24),
            if (count > 0)
              Positioned(
                top: -2,
                right: -1,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE44D57),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white, width: 1.3),
                  ),
                  alignment: Alignment.center,
                  child: Text(count > 99 ? '99+' : '$count',
                      style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.w800)),
                ),
              ),
          ],
        ),
      );
}

/// Shared confirmation pattern for order, inventory and custody actions.
Future<bool> shopHopConfirm(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Row(children: [
        Icon(destructive ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
            color: destructive ? const Color(0xFFC83939) : AppColors.tealDark),
        const SizedBox(width: 10),
        Expanded(child: Text(title)),
      ]),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
        FilledButton(
          style: destructive ? FilledButton.styleFrom(backgroundColor: const Color(0xFFC83939)) : null,
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result == true;
}
