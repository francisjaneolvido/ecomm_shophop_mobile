import 'package:flutter/material.dart';
import 'package:shophop/core/theme/app_colors.dart';

/// Compact, touch-friendly building blocks shared by logistics, branch, hub,
/// rider and linehaul. Counters are supplied by the caller (never fabricated).
class ShopHopOpsAction extends StatelessWidget {
  const ShopHopOpsAction({super.key, required this.icon, required this.title,
    required this.subtitle, required this.onTap, this.trailing, this.enabled = true});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: const BorderSide(color: AppColors.grayBorder)),
    child: InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        child: Row(children: [
          Container(width: 39, height: 39,
            decoration: BoxDecoration(color: AppColors.tealLight,
              borderRadius: BorderRadius.circular(6)),
            child: Icon(icon, size: 21, color: AppColors.tealDark)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800,
                color: AppColors.navy, fontSize: 13)),
              const SizedBox(height: 2),
              Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF607084), fontSize: 11)),
            ])),
          const SizedBox(width: 8),
          trailing ?? const Icon(Icons.chevron_right_rounded,
            size: 21, color: AppColors.navy),
        ]),
      ),
    ),
  );
}

class ShopHopOpsHeading extends StatelessWidget {
  const ShopHopOpsHeading({super.key, required this.title, this.subtitle,
    this.trailing});
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
      children: [Text(title, style: const TextStyle(fontSize: 16,
        fontWeight: FontWeight.w800, color: AppColors.navy)),
        if (subtitle != null) ...[
          const SizedBox(height: 3),
          Text(subtitle!, style: const TextStyle(fontSize: 11,
            color: Color(0xFF607084))),
        ],
      ])),
    if (trailing != null) trailing!,
  ]);
}

class ShopHopOpsCount extends StatelessWidget {
  const ShopHopOpsCount({super.key, required this.label, required this.value,
    this.icon = Icons.inventory_2_outlined});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: Colors.white,
      border: Border.all(color: AppColors.grayBorder),
      borderRadius: BorderRadius.circular(8)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: AppColors.tealDark, size: 19),
      const SizedBox(height: 8),
      Text(value, style: const TextStyle(color: AppColors.navy,
        fontSize: 22, fontWeight: FontWeight.w800)),
      Text(label, style: const TextStyle(color: Color(0xFF607084), fontSize: 11)),
    ]),
  );
}
