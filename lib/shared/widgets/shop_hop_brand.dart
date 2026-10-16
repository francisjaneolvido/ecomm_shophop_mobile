import 'package:flutter/material.dart';
import 'package:shophop/core/theme/app_colors.dart';

class ShopHopBrand extends StatelessWidget {
  const ShopHopBrand({super.key, this.compact = false, this.light = false});

  final bool compact;
  final bool light;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset('assets/images/logo.png', height: compact ? 34 : 44, width: compact ? 34 : 44, fit: BoxFit.contain),
        const SizedBox(width: 9),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text.rich(TextSpan(children: [
              TextSpan(text: 'Shop', style: TextStyle(color: light ? Colors.white : AppColors.navy)),
              const TextSpan(text: 'Hop', style: TextStyle(color: AppColors.tealDark)),
            ]), style: TextStyle(fontWeight: FontWeight.w800, fontSize: compact ? 18 : 22, letterSpacing: -.8, height: 1.1)),
            const SizedBox(height: 2),
            Text('HOP IN. SHOP MORE.', style: TextStyle(color: light ? Colors.white70 : AppColors.navy.withValues(alpha: .5), fontSize: compact ? 7 : 8, fontWeight: FontWeight.w700, letterSpacing: 1.4)),
          ],
        ),
      ],
    );
  }
}
