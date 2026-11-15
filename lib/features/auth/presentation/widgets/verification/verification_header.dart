import 'package:flutter/material.dart';

import 'package:shophop/core/theme/app_colors.dart';
import 'package:shophop/features/auth/domain/registration_role.dart';
import 'package:shophop/features/auth/presentation/widgets/verification/verification_ui.dart';

class VerificationHeader extends StatelessWidget {
  const VerificationHeader({super.key, required this.role});

  final RegistrationRole role;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.tealLight,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.teal.withValues(alpha: 0.13)),
          ),
          child: const Icon(
            Icons.mark_email_read_outlined,
            color: AppColors.tealDark,
            size: 22,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          role.eyebrow,
          textAlign: TextAlign.start,
          style: VerificationUi.text(
            color: AppColors.tealDark,
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.3,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          role.title,
          textAlign: TextAlign.start,
          style: VerificationUi.text(
            color: AppColors.navy,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            height: 1.12,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          role.subtitle,
          textAlign: TextAlign.start,
          style: VerificationUi.text(
            color: AppColors.navy.withValues(alpha: 0.48),
            fontSize: 12,
            height: 1.55,
          ),
        ),
      ],
    );
  }
}
