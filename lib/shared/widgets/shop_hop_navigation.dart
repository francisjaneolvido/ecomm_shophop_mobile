import 'package:flutter/material.dart';
import 'package:shophop/core/theme/app_colors.dart';

/// Shared navigation for Buyer, Seller, Rider, Linehaul and Logistics.
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
    this.raisedIndex,
  });
  final List<ShopHopNavItem> items;
  final int index;
  final ValueChanged<int> onChanged;
  final Map<int, int> badges;
  final int? raisedIndex;

  @override
  Widget build(BuildContext context) {
    final selected = index.clamp(0, items.length - 1);
    final hasRaised = raisedIndex != null;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    // Text layout rounds line heights up; reserve the same space at every scale.
    final labelHeight = (MediaQuery.textScalerOf(context).scale(10.5) * 1.5)
        .ceilToDouble();
    const scanLift = 17.0;
    // Keep the white bar itself the same height for every role.
    final contentHeight =
        42 + 3 + labelHeight + 14 + (hasRaised ? scanLift : 0);
    return SizedBox(
      height: contentHeight + bottomInset,
      child: Stack(
        children: [
          Positioned(
            top: hasRaised ? scanLift : 0,
            left: 10,
            right: 10,
            bottom: bottomInset + 6,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.tealDark.withValues(alpha: .10),
                    blurRadius: 18,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < items.length; i++)
                    Expanded(
                      child: Semantics(
                        selected: selected == i,
                        button: true,
                        label:
                            '${items[i].label}, tab ${i + 1} of ${items.length}',
                        excludeSemantics: true,
                        child: Tooltip(
                          message: items[i].label,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              // Selection lives on the icon/label, never on a tab backdrop.
                              overlayColor: const WidgetStatePropertyAll(
                                Colors.transparent,
                              ),
                              splashFactory: NoSplash.splashFactory,
                              onTap: () {
                                FocusManager.instance.primaryFocus?.unfocus();
                                onChanged(i);
                              },
                              borderRadius: BorderRadius.circular(24),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (i == raisedIndex) ...[
                                    AnimatedContainer(
                                      key: const ValueKey('raised-scan-button'),
                                      duration: const Duration(
                                        milliseconds: 180,
                                      ),
                                      width: 56,
                                      height: 56,
                                      decoration: BoxDecoration(
                                        color: selected == i
                                            ? AppColors.tealDark
                                            : AppColors.teal,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 4,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.tealDark
                                                .withValues(alpha: .28),
                                            blurRadius: 14,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        items[i].activeIcon,
                                        size: 27,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    _roleLabel(i, selected),
                                  ] else
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 4,
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          SizedBox(
                                            height: 31,
                                            child: Center(
                                              child: Badge.count(
                                                count: (badges[i] ?? 0).clamp(
                                                  0,
                                                  9999,
                                                ),
                                                isLabelVisible:
                                                    (badges[i] ?? 0) > 0,
                                                child: Icon(
                                                  selected == i
                                                      ? items[i].activeIcon
                                                      : items[i].icon,
                                                  size: 23,
                                                  color: selected == i
                                                      ? AppColors.tealDark
                                                      : AppColors.textMuted,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          _roleLabel(i, selected),
                                        ],
                                      ),
                                    ),
                                  const SizedBox(height: 14),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _roleLabel(int itemIndex, int selected) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 3),
    child: Text(
      items[itemIndex].label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 10.5,
        height: 1.5,
        fontWeight: selected == itemIndex ? FontWeight.w600 : FontWeight.w400,
        color: selected == itemIndex ? AppColors.tealDark : AppColors.textMuted,
      ),
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
    builder: (dialogContext) {
      final colors = Theme.of(dialogContext).colorScheme;
      return AlertDialog(
        title: Row(
          children: [
            Icon(
              destructive
                  ? Icons.warning_amber_rounded
                  : Icons.check_circle_outline_rounded,
              color: destructive ? colors.error : colors.primary,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(title)),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: colors.error,
                    foregroundColor: colors.onError,
                  )
                : null,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return result == true;
}
