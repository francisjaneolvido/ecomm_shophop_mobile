import 'package:flutter/material.dart';
import 'package:shophop/core/theme/app_colors.dart';
import 'package:shophop/shared/widgets/shop_hop_ui.dart';

/// Explicit placeholder; does not pretend that a missing backend is connected.
class BuyerEmptyFeaturePage extends StatelessWidget {
  const BuyerEmptyFeaturePage({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String description;
  final IconData icon;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ShopHopEmptyState(
                  icon: icon,
                  title: title,
                  description: description,
                  actionLabel: actionLabel,
                  onAction: onAction,
                ),
                const SizedBox(height: 12),
                Text(
                  'More ShopHop mobile features are on the way.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.navy.withValues(alpha: .43),
                    fontSize: 10.5,
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
