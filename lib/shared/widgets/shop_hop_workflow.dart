import 'package:flutter/material.dart';
import 'package:shophop/core/theme/app_colors.dart';
import 'package:shophop/shared/widgets/shop_hop_ui.dart';

/// Shared compact operational layout, aligned with ShopHop Web navy/teal styles.
class ShopHopWorkflowHeader extends StatelessWidget {
  const ShopHopWorkflowHeader({super.key, required this.title, required this.subtitle, this.icon = Icons.route_outlined, this.badge});
  final String title;
  final String subtitle;
  final IconData icon;
  final String? badge;

  @override
  Widget build(BuildContext context) => ShopHopSurface(
    padding: const EdgeInsets.all(14),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 42, height: 42,
        decoration: BoxDecoration(color: AppColors.tealLight, borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: AppColors.tealDark)),
      const SizedBox(width: 11),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.navy)),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(fontSize: 11.5, height: 1.4, color: Color(0xFF64748B))),
        if (badge != null) ...[
          const SizedBox(height: 8),
          ShopHopStatusPill(label: badge!),
        ],
      ])),
    ]),
  );
}

class ShopHopWorkflowAction extends StatelessWidget {
  const ShopHopWorkflowAction({super.key, required this.title, required this.subtitle,
    required this.icon, this.onTap, this.active = true});
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) => ShopHopSurface(
    padding: EdgeInsets.zero,
    child: ListTile(
      enabled: active && onTap != null, onTap: active ? onTap : null,
      dense: true,
      minLeadingWidth: 32,
      leading: Icon(icon, color: AppColors.tealDark, size: 24),
      title: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.navy)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
      trailing: const Icon(Icons.chevron_right_rounded, size: 20),
    ),
  );
}
