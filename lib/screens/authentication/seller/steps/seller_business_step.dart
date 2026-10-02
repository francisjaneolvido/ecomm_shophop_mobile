import 'package:flutter/material.dart';

import '../../../../theme/app_colors.dart';
import '../widgets/seller_ui.dart';

class SellerBusinessStep extends StatelessWidget {
  const SellerBusinessStep({
    super.key,
    required this.businessNameController,
    required this.businessCategoryController,
  });

  final TextEditingController businessNameController;
  final TextEditingController businessCategoryController;

  static const List<String> _businessCategories = [
    'Pet Supplies',
    'Electronics and Gadgets',
    "Women's Apparel",
    "Men's Apparel",
    'Kids and Baby',
    'Home and Garden',
    'Sports and Outdoors',
    'Health and Beauty',
    'Books and Media',
    'Food and Gourmet',
    'Automotive & Motorcycle',
    'Furniture and Office Equipment',
    'Jewelry and Watches',
    'Office and School Supplies',
  ];

  @override
  Widget build(BuildContext context) {
    final currentCategory =
        _businessCategories.contains(
          businessCategoryController.text,
        )
            ? businessCategoryController.text
            : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SellerUi.sectionHeader(
          icon: Icons.storefront_outlined,
          title: 'Business details',
          subtitle:
              'Tell us about the business you will use for your ShopHop seller account.',
        ),

        const SizedBox(height: 24),

        _buildBusinessNameField(),

        const SizedBox(height: 18),

        _buildBusinessCategoryField(
          currentCategory,
        ),

        const SizedBox(height: 18),

        _buildInfoNotice(),
      ],
    );
  }

  Widget _buildBusinessNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SellerUi.requiredLabel(
          'Business name',
        ),

        const SizedBox(height: 8),

        TextFormField(
          controller:
              businessNameController,
          textCapitalization:
              TextCapitalization.words,
          textInputAction:
              TextInputAction.next,
          validator: (value) {
            if (value == null ||
                value.trim().isEmpty) {
              return 'Business name is required.';
            }

            return null;
          },
          style: SellerUi.text(
            color: AppColors.navy,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          decoration:
              SellerUi.inputDecoration(
            hint:
                'Enter your registered business name',
            icon:
                Icons.store_outlined,
          ),
        ),
      ],
    );
  }

  Widget _buildBusinessCategoryField(
    String? currentCategory,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SellerUi.requiredLabel(
          'Line of Business (Category)',
        ),

        const SizedBox(height: 8),

        DropdownButtonFormField<String>(
          initialValue: currentCategory,
          isExpanded: true,
          menuMaxHeight: 360,
          icon: Icon(
            Icons
                .keyboard_arrow_down_rounded,
            color: AppColors.navy
                .withValues(
              alpha: 0.40,
            ),
          ),
          hint: Text(
            'Select line of business',
            style: SellerUi.text(
              color: AppColors.navy
                  .withValues(
                alpha: 0.28,
              ),
              fontSize: 12,
            ),
          ),
          style: SellerUi.text(
            color: AppColors.navy,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          decoration:
              SellerUi.inputDecoration(
            hint:
                'Select line of business',
            icon: Icons.sell_outlined,
          ).copyWith(
            hintText: null,
          ),
          items:
              _businessCategories
                  .map(
                    (category) =>
                        DropdownMenuItem<
                            String>(
                      value: category,
                      child: Text(
                        category,
                        overflow:
                            TextOverflow
                                .ellipsis,
                        style:
                            SellerUi.text(
                          color:
                              AppColors.navy,
                          fontSize: 12,
                          fontWeight:
                              FontWeight.w500,
                        ),
                      ),
                    ),
                  )
                  .toList(),
          onChanged: (value) {
            businessCategoryController
                    .text =
                value ?? '';
          },
          validator: (value) {
            if (value == null ||
                value.trim().isEmpty) {
              return 'Please select a line of business.';
            }

            return null;
          },
        ),
      ],
    );
  }

  Widget _buildInfoNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.tealLight
            .withValues(
          alpha: 0.45,
        ),
        borderRadius:
            BorderRadius.circular(15),
        border: Border.all(
          color: AppColors.teal
              .withValues(
            alpha: 0.14,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.tealDark,
            size: 18,
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Text(
              'Choose the category that best matches your business. Use the same business information that appears on your supporting documents.',
              style: SellerUi.text(
                color: AppColors.navy
                    .withValues(
                  alpha: 0.55,
                ),
                fontSize: 10.5,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
