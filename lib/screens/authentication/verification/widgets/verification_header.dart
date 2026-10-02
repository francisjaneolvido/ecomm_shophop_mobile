import 'package:flutter/material.dart';

import '../../../../theme/app_colors.dart';
import '../registration_role.dart';
import 'verification_ui.dart';

class VerificationHeader extends StatelessWidget {
  const VerificationHeader({
    super.key,
    required this.role,
  });

  final RegistrationRole role;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.tealLight,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: AppColors.teal.withValues(alpha: 0.13),
            ),
          ),
          child: const Icon(
            Icons.mark_email_read_outlined,
            color: AppColors.tealDark,
            size: 32,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          role.eyebrow,
          textAlign: TextAlign.center,
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
          textAlign: TextAlign.center,
          style: VerificationUi.text(
            color: AppColors.navy,
            fontSize: 27,
            fontWeight: FontWeight.w800,
            height: 1.12,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          role.subtitle,
          textAlign: TextAlign.center,
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
