import 'dart:async';

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

Future<void> showAccountStatusToast({
  required BuildContext context,
  required AccountReviewRole role,
  required AccountAccessStatus status,
  String? email,
  String? rejectionReason,
  VoidCallback? onVerifyEmail,
}) async {
  final overlay = Overlay.of(
    context,
    rootOverlay: true,
  );

  final completer = Completer<void>();
  late OverlayEntry entry;
  var removed = false;

  void removeToast() {
    if (removed) {
      return;
    }

    removed = true;
    entry.remove();

    if (!completer.isCompleted) {
      completer.complete();
    }
  }

  final duration = switch (status) {
    AccountAccessStatus.emailUnverified =>
      const Duration(seconds: 8),
    AccountAccessStatus.pendingApproval =>
      const Duration(seconds: 6),
    AccountAccessStatus.rejected =>
      const Duration(seconds: 8),
  };

  entry = OverlayEntry(
    builder: (context) {
      final top =
          MediaQuery.paddingOf(context).top +
              12;

      return Positioned(
        top: top,
        left: 14,
        right: 14,
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(
              maxWidth: 460,
            ),
            child: _AccountStatusToastCard(
              role: role,
              status: status,
              email: email,
              rejectionReason:
                  rejectionReason,
              onClose: removeToast,
              onVerifyEmail:
                  onVerifyEmail == null
                      ? null
                      : () {
                          removeToast();
                          onVerifyEmail();
                        },
            ),
          ),
        ),
      );
    },
  );

  overlay.insert(entry);

  await Future.any([
    Future<void>.delayed(duration),
    completer.future,
  ]);

  removeToast();
}

class _AccountStatusToastCard
    extends StatelessWidget {
  const _AccountStatusToastCard({
    required this.role,
    required this.status,
    required this.email,
    required this.rejectionReason,
    required this.onClose,
    required this.onVerifyEmail,
  });

  final AccountReviewRole role;
  final AccountAccessStatus status;
  final String? email;
  final String? rejectionReason;
  final VoidCallback onClose;
  final VoidCallback? onVerifyEmail;

  TextStyle _text({
    Color color = AppColors.navy,
    double fontSize = 12,
    FontWeight fontWeight =
        FontWeight.w400,
    double? height,
  }) {
    return GoogleFonts.poppins(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
    );
  }

  IconData get _icon {
    switch (status) {
      case AccountAccessStatus
            .emailUnverified:
        return Icons
            .mark_email_unread_outlined;
      case AccountAccessStatus
            .pendingApproval:
        return Icons.hourglass_top_rounded;
      case AccountAccessStatus.rejected:
        return Icons
            .info_outline_rounded;
    }
  }

  String get _title {
    switch (status) {
      case AccountAccessStatus
            .emailUnverified:
        return 'Verify your email first';

      case AccountAccessStatus
            .pendingApproval:
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
      case AccountAccessStatus
            .emailUnverified:
        return 'Complete email verification before signing in.';

      case AccountAccessStatus
            .pendingApproval:
        switch (role) {
          case AccountReviewRole.buyer:
            return 'Your account is still waiting for administrator approval.';
          case AccountReviewRole.seller:
            return 'Your seller application and documents are still being reviewed.';
          case AccountReviewRole.rider:
            return 'Your rider application is still waiting for Logistics / Sorting Center approval.';
        }

      case AccountAccessStatus.rejected:
        switch (role) {
          case AccountReviewRole.buyer:
            return 'Your account application was not approved.';
          case AccountReviewRole.seller:
            return 'Your seller application was not approved.';
          case AccountReviewRole.rider:
            return 'Your rider application was not approved.';
        }
    }
  }

  Color get _iconBackground {
    if (status ==
        AccountAccessStatus.rejected) {
      return const Color(0xFFFFF1E8);
    }

    return AppColors.tealLight;
  }

  Color get _iconColor {
    if (status ==
        AccountAccessStatus.rejected) {
      return const Color(0xFFB56B45);
    }

    return AppColors.tealDark;
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration:
          const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      tween: Tween<double>(
        begin: 0,
        end: 1,
      ),
      builder: (
        context,
        value,
        child,
      ) {
        return Transform.translate(
          offset: Offset(
            0,
            -14 * (1 - value),
          ),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.grayBorder,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.navy
                    .withValues(
                  alpha: 0.16,
                ),
                blurRadius: 28,
                offset:
                    const Offset(0, 10),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,
              children: [
              Container(
                width: 4,
                color:
                    status ==
                            AccountAccessStatus
                                .rejected
                        ? const Color(
                            0xFFD89068,
                          )
                        : AppColors.teal,
              ),
              Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.fromLTRB(
                    14,
                    12,
                    8,
                    12,
                  ),
                  child: Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration:
                            BoxDecoration(
                          color:
                              _iconBackground,
                          borderRadius:
                              BorderRadius.circular(
                            12,
                          ),
                        ),
                        child: Icon(
                          _icon,
                          color: _iconColor,
                          size: 21,
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          mainAxisSize:
                              MainAxisSize.min,
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            Text(
                              _title,
                              style: _text(
                                fontSize: 13,
                                fontWeight:
                                    FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _message,
                              style: _text(
                                color: AppColors
                                    .navy
                                    .withValues(
                                  alpha: 0.56,
                                ),
                                fontSize: 10.5,
                                height: 1.4,
                              ),
                            ),
                            if (email != null &&
                                email!
                                    .trim()
                                    .isNotEmpty) ...[
                              const SizedBox(
                                height: 5,
                              ),
                              Text(
                                email!,
                                maxLines: 1,
                                overflow:
                                    TextOverflow
                                        .ellipsis,
                                style: _text(
                                  color: AppColors
                                      .tealDark,
                                  fontSize: 9.5,
                                  fontWeight:
                                      FontWeight
                                          .w600,
                                ),
                              ),
                            ],
                            if (status ==
                                    AccountAccessStatus
                                        .rejected &&
                                rejectionReason !=
                                    null &&
                                rejectionReason!
                                    .trim()
                                    .isNotEmpty) ...[
                              const SizedBox(
                                height: 6,
                              ),
                              Text(
                                rejectionReason!,
                                maxLines: 2,
                                overflow:
                                    TextOverflow
                                        .ellipsis,
                                style: _text(
                                  color: AppColors
                                      .navy
                                      .withValues(
                                    alpha: 0.62,
                                  ),
                                  fontSize: 9.5,
                                  height: 1.35,
                                ),
                              ),
                            ],
                            if (status ==
                                    AccountAccessStatus
                                        .emailUnverified &&
                                onVerifyEmail !=
                                    null) ...[
                              const SizedBox(
                                height: 8,
                              ),
                              SizedBox(
                                height: 32,
                                child:
                                    FilledButton(
                                  onPressed:
                                      onVerifyEmail,
                                  style:
                                      FilledButton
                                          .styleFrom(
                                    backgroundColor:
                                        AppColors
                                            .teal,
                                    foregroundColor:
                                        Colors.white,
                                    padding:
                                        const EdgeInsets
                                            .symmetric(
                                      horizontal: 13,
                                    ),
                                    shape:
                                        RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius
                                              .circular(
                                        9,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    'Verify Email',
                                    style: _text(
                                      color:
                                          Colors.white,
                                      fontSize: 10,
                                      fontWeight:
                                          FontWeight
                                              .w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: IconButton(
                          tooltip: 'Dismiss',
                          padding: EdgeInsets.zero,
                          onPressed: onClose,
                          style:
                              IconButton.styleFrom(
                            backgroundColor:
                                AppColors.grayBg,
                          ),
                          icon: Icon(
                            Icons.close_rounded,
                            size: 17,
                            color: AppColors.navy
                                .withValues(
                              alpha: 0.42,
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
        ),
        ),
      ),
    );
  }
}
