import 'package:flutter/material.dart';

import '../../../../theme/app_colors.dart';
import 'seller_ui.dart';

class SellerRegistrationHeader
    extends StatelessWidget {
  const SellerRegistrationHeader({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SELLER REGISTRATION',
          style: SellerUi.text(
            color: AppColors.tealDark,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.3,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          'Start selling on ShopHop',
          style: SellerUi.text(
            color: AppColors.navy,
            fontSize: 28,
            fontWeight: FontWeight.w800,
            height: 1.1,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 9),
        Text(
          'Complete five quick steps to submit your seller application.',
          style: SellerUi.text(
            color: AppColors.navy.withValues(alpha: 0.48),
            fontSize: 12,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class SellerRegistrationProgress
    extends StatelessWidget {
  const SellerRegistrationProgress({
    super.key,
    required this.currentStep,
  });

  final int currentStep;

  @override
  Widget build(BuildContext context) {
    const labels = [
      'Personal',
      'Address',
      'Business',
      'Verify',
      'Security',
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 15, 14, 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.grayBorder,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'REGISTRATION PROGRESS',
                style: SellerUi.text(
                  color:
                      AppColors.navy.withValues(alpha: 0.40),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.7,
                ),
              ),
              const Spacer(),
              Text(
                '$currentStep of 5',
                style: SellerUi.text(
                  color: AppColors.tealDark,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: List.generate(
              9,
              (index) {
                if (index.isOdd) {
                  final lineStep =
                      ((index + 1) / 2).floor();

                  return Expanded(
                    child: Container(
                      height: 2,
                      color: lineStep < currentStep
                          ? AppColors.teal
                          : AppColors.grayBorder,
                    ),
                  );
                }

                final step = (index ~/ 2) + 1;
                final completed = step < currentStep;
                final active = step == currentStep;

                return Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: completed || active
                        ? AppColors.teal
                        : Colors.white,
                    border: Border.all(
                      color: completed || active
                          ? AppColors.teal
                          : AppColors.grayBorder,
                    ),
                  ),
                  child: completed
                      ? const Icon(
                          Icons.check_rounded,
                          size: 15,
                          color: Colors.white,
                        )
                      : Text(
                          '$step',
                          style: SellerUi.text(
                            color: active
                                ? Colors.white
                                : AppColors.navy.withValues(
                                    alpha: 0.30,
                                  ),
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                );
              },
            ),
          ),
          const SizedBox(height: 9),
          Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
            children: List.generate(
              labels.length,
              (index) {
                final reached =
                    index + 1 <= currentStep;

                return SizedBox(
                  width: 52,
                  child: Text(
                    labels[index],
                    textAlign: TextAlign.center,
                    style: SellerUi.text(
                      color: reached
                          ? AppColors.navy
                          : AppColors.navy.withValues(
                              alpha: 0.27,
                            ),
                      fontSize: 8.5,
                      fontWeight: reached
                          ? FontWeight.w600
                          : FontWeight.w500,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
