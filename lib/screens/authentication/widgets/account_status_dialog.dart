import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/app_colors.dart';

enum AccountReviewRole {
  buyer,
  seller,
  rider,
}

enum AccountAccessStatus {
  emailUnverified,
  pendingApproval,
  rejected,
}

Future<void> showAccountStatusDialog({
  required BuildContext context,
  required AccountReviewRole role,
  required AccountAccessStatus status,
  String? email,
  String? rejectionReason,
  VoidCallback? onVerifyEmail,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Account status',
    barrierColor: AppColors.navy.withValues(alpha: 0.62),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, animation, secondaryAnimation) {
      return _AccountStatusDialog(
        role: role,
        status: status,
        email: email,
        rejectionReason: rejectionReason,
        onVerifyEmail: onVerifyEmail,
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );

      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(
            begin: 0.94,
            end: 1,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _AccountStatusDialog extends StatelessWidget {
  const _AccountStatusDialog({
    required this.role,
    required this.status,
    required this.email,
    required this.rejectionReason,
    required this.onVerifyEmail,
  });

  final AccountReviewRole role;
  final AccountAccessStatus status;
  final String? email;
  final String? rejectionReason;
  final VoidCallback? onVerifyEmail;

  TextStyle _text({
    Color color = AppColors.navy,
    double fontSize = 13,
    FontWeight fontWeight = FontWeight.w400,
    double? height,
    double? letterSpacing,
  }) {
    return GoogleFonts.poppins(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  IconData get _icon {
    switch (status) {
      case AccountAccessStatus.emailUnverified:
        return Icons.mark_email_unread_outlined;
      case AccountAccessStatus.pendingApproval:
        return Icons.hourglass_top_rounded;
      case AccountAccessStatus.rejected:
        return Icons.info_outline_rounded;
    }
  }

  String get _eyebrow {
    switch (status) {
      case AccountAccessStatus.emailUnverified:
        return 'EMAIL VERIFICATION';
      case AccountAccessStatus.pendingApproval:
        return 'ACCOUNT REVIEW';
      case AccountAccessStatus.rejected:
        return 'APPLICATION UPDATE';
    }
  }

  String get _title {
    switch (status) {
      case AccountAccessStatus.emailUnverified:
        return 'Verify your email first';

      case AccountAccessStatus.pendingApproval:
        switch (role) {
          case AccountReviewRole.buyer:
            return 'Account pending approval';
          case AccountReviewRole.seller:
            return 'Seller account under review';
          case AccountReviewRole.rider:
            return 'Rider application under review';
        }

      case AccountAccessStatus.rejected:
        switch (role) {
          case AccountReviewRole.buyer:
            return 'Account application update';
          case AccountReviewRole.seller:
            return 'Seller application update';
          case AccountReviewRole.rider:
            return 'Rider application update';
        }
    }
  }

  String get _message {
    switch (status) {
      case AccountAccessStatus.emailUnverified:
        return 'Your email address has not been verified yet. '
            'Please complete the email verification step before signing in.';

      case AccountAccessStatus.pendingApproval:
        switch (role) {
          case AccountReviewRole.buyer:
            return 'Your ShopHop account is still awaiting administrator '
                'approval. We’ll notify you through your registered email '
                'once your account is approved.';
          case AccountReviewRole.seller:
            return 'Your seller application and submitted documents are '
                'still being reviewed by the ShopHop administrator. '
                'We’ll notify you through your registered email once '
                'your account is approved.';
          case AccountReviewRole.rider:
            return 'Your rider application is still awaiting approval from '
                'the Logistics / Sorting Center. We’ll notify you through '
                'your registered email once your account is approved.';
        }

      case AccountAccessStatus.rejected:
        switch (role) {
          case AccountReviewRole.buyer:
            return 'Your account application was not approved. '
                'Please review the information sent to your registered email.';
          case AccountReviewRole.seller:
            return 'Your seller application was not approved. '
                'Please review the information sent to your registered email.';
          case AccountReviewRole.rider:
            return 'Your rider application was not approved. '
                'Please review the information sent to your registered email.';
        }
    }
  }

  String get _primaryButtonText {
    switch (status) {
      case AccountAccessStatus.emailUnverified:
        return onVerifyEmail == null ? 'Okay' : 'Verify Email';
      case AccountAccessStatus.pendingApproval:
      case AccountAccessStatus.rejected:
        return 'Okay';
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Material(
        color: Colors.transparent,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 410,
              ),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                    color: AppColors.grayBorder,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.navy.withValues(alpha: 0.20),
                      blurRadius: 40,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 5,
                      color: AppColors.teal,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
                      child: Column(
                        children: [
                          Align(
                            alignment: Alignment.centerRight,
                            child: SizedBox(
                              width: 38,
                              height: 38,
                              child: IconButton(
                                tooltip: 'Close',
                                padding: EdgeInsets.zero,
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                                style: IconButton.styleFrom(
                                  backgroundColor: AppColors.grayBg,
                                ),
                                icon: Icon(
                                  Icons.close_rounded,
                                  size: 19,
                                  color: AppColors.navy.withValues(alpha: 0.48),
                                ),
                              ),
                            ),
                          ),
                          Transform.translate(
                            offset: const Offset(0, -12),
                            child: Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: AppColors.tealLight,
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                  color: AppColors.teal.withValues(alpha: 0.13),
                                ),
                              ),
                              child: Icon(
                                _icon,
                                color: AppColors.tealDark,
                                size: 33,
                              ),
                            ),
                          ),
                          Transform.translate(
                            offset: const Offset(0, -5),
                            child: Column(
                              children: [
                                Text(
                                  _eyebrow,
                                  textAlign: TextAlign.center,
                                  style: _text(
                                    color: AppColors.tealDark,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.35,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _title,
                                  textAlign: TextAlign.center,
                                  style: _text(
                                    color: AppColors.navy,
                                    fontSize: 21,
                                    fontWeight: FontWeight.w800,
                                    height: 1.18,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 11),
                                Text(
                                  _message,
                                  textAlign: TextAlign.center,
                                  style: _text(
                                    color: AppColors.navy.withValues(alpha: 0.53),
                                    fontSize: 11.5,
                                    height: 1.55,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (email != null && email!.trim().isNotEmpty) ...[
                            const SizedBox(height: 14),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.grayBg,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: AppColors.grayBorder,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.alternate_email_rounded,
                                    color: AppColors.tealDark,
                                    size: 17,
                                  ),
                                  const SizedBox(width: 9),
                                  Expanded(
                                    child: Text(
                                      email!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: _text(
                                        color: AppColors.navy,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (status == AccountAccessStatus.rejected &&
                              rejectionReason != null &&
                              rejectionReason!.trim().isNotEmpty) ...[
                            const SizedBox(height: 14),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(13),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF7F2),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(0xFFF2DED2),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.description_outlined,
                                    color: Color(0xFFB56B45),
                                    size: 17,
                                  ),
                                  const SizedBox(width: 9),
                                  Expanded(
                                    child: Text(
                                      rejectionReason!,
                                      style: _text(
                                        color: AppColors.navy.withValues(alpha: 0.62),
                                        fontSize: 10.5,
                                        height: 1.45,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.of(context).pop();

                                if (status ==
                                        AccountAccessStatus.emailUnverified &&
                                    onVerifyEmail != null) {
                                  onVerifyEmail!();
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                elevation: 0,
                                backgroundColor: AppColors.teal,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Text(
                                _primaryButtonText,
                                style: _text(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          if (status ==
                              AccountAccessStatus.pendingApproval) ...[
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.notifications_none_rounded,
                                  size: 14,
                                  color: AppColors.navy.withValues(alpha: 0.32),
                                ),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    'No need to submit another registration.',
                                    textAlign: TextAlign.center,
                                    style: _text(
                                      color:
                                          AppColors.navy.withValues(alpha: 0.38),
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
