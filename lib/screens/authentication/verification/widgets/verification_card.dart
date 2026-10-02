import 'package:flutter/material.dart';

import '../../../../theme/app_colors.dart';
import '../registration_role.dart';
import 'otp_code_field.dart';
import 'verification_ui.dart';

class VerificationCard extends StatelessWidget {
  const VerificationCard({
    super.key,
    required this.email,
    required this.role,
    required this.codeController,
    required this.enabled,
    required this.canVerify,
    required this.isVerifying,
    required this.isResending,
    required this.secondsRemaining,
    required this.errorMessage,
    required this.successMessage,
    required this.onCodeChanged,
    required this.onVerify,
    required this.onResend,
  });

  final String email;
  final RegistrationRole role;
  final TextEditingController codeController;

  final bool enabled;
  final bool canVerify;
  final bool isVerifying;
  final bool isResending;
  final int secondsRemaining;

  final String? errorMessage;
  final String? successMessage;

  final ValueChanged<String> onCodeChanged;
  final VoidCallback onVerify;
  final VoidCallback onResend;

  bool get _canResend =>
      secondsRemaining == 0 && !isResending && enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.grayBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.045),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Code sent to',
            style: VerificationUi.text(
              color: AppColors.navy.withValues(alpha: 0.40),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 7),
          _emailCard(),
          const SizedBox(height: 22),
          Text(
            'Verification code',
            style: VerificationUi.text(
              color: AppColors.navy,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 9),
          OtpCodeField(
            controller: codeController,
            enabled: enabled,
            onChanged: onCodeChanged,
          ),
          const SizedBox(height: 12),
          _expiryNote(),
          if (errorMessage != null) ...[
            const SizedBox(height: 15),
            _messageCard(
              errorMessage!,
              isError: true,
            ),
          ],
          if (successMessage != null) ...[
            const SizedBox(height: 15),
            _messageCard(
              successMessage!,
              isError: false,
            ),
          ],
          const SizedBox(height: 20),
          _verifyButton(),
          const SizedBox(height: 18),
          _resendRow(),
          const SizedBox(height: 18),
          _approvalNote(),
          const SizedBox(height: 12),
          _securityNote(),
        ],
      ),
    );
  }

  Widget _emailCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 13,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.grayBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.grayBorder),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.alternate_email_rounded,
            size: 17,
            color: AppColors.tealDark,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              email,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: VerificationUi.text(
                color: AppColors.navy,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _expiryNote() {
    return Row(
      children: [
        Icon(
          Icons.schedule_rounded,
          size: 15,
          color: AppColors.navy.withValues(alpha: 0.34),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'The code expires after 10 minutes.',
            style: VerificationUi.text(
              color: AppColors.navy.withValues(alpha: 0.40),
              fontSize: 10,
            ),
          ),
        ),
      ],
    );
  }

  Widget _verifyButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: canVerify ? onVerify : null,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: AppColors.teal,
          foregroundColor: Colors.white,
          disabledBackgroundColor:
              AppColors.teal.withValues(alpha: 0.35),
          disabledForegroundColor:
              Colors.white.withValues(alpha: 0.85),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: isVerifying
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                role.verifyButtonLabel,
                style: VerificationUi.text(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }

  Widget _resendRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Didn’t receive the code?',
          style: VerificationUi.text(
            color: AppColors.navy.withValues(alpha: 0.43),
            fontSize: 10.5,
          ),
        ),
        const SizedBox(width: 6),
        TextButton(
          onPressed: _canResend ? onResend : null,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(
              horizontal: 4,
              vertical: 6,
            ),
            minimumSize: Size.zero,
            tapTargetSize:
                MaterialTapTargetSize.shrinkWrap,
          ),
          child: isResending
              ? const SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.8,
                    color: AppColors.tealDark,
                  ),
                )
              : Text(
                  secondsRemaining > 0
                      ? 'Resend in ${secondsRemaining}s'
                      : 'Resend code',
                  style: VerificationUi.text(
                    color: secondsRemaining > 0
                        ? AppColors.navy.withValues(alpha: 0.28)
                        : AppColors.tealDark,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _approvalNote() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.tealLight.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.teal.withValues(alpha: 0.13),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.shield_outlined,
            color: AppColors.tealDark,
            size: 18,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              role.approvalMessage,
              style: VerificationUi.text(
                color: AppColors.navy.withValues(alpha: 0.54),
                fontSize: 10.5,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _securityNote() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.lock_outline_rounded,
          size: 15,
          color: AppColors.navy.withValues(alpha: 0.30),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            'For your security, ShopHop will never ask you to share this verification code with another person.',
            style: VerificationUi.text(
              color: AppColors.navy.withValues(alpha: 0.36),
              fontSize: 9.5,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _messageCard(
    String message, {
    required bool isError,
  }) {
    final foreground = isError
        ? const Color(0xFFC55353)
        : AppColors.tealDark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isError
            ? const Color(0xFFFFF4F4)
            : AppColors.tealLight.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: isError
              ? const Color(0xFFF0CECE)
              : AppColors.teal.withValues(alpha: 0.16),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError
                ? Icons.error_outline_rounded
                : Icons.check_circle_outline_rounded,
            color: foreground,
            size: 17,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: VerificationUi.text(
                color: foreground,
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
