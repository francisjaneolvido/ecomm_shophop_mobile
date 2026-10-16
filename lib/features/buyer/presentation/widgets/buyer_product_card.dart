import 'package:flutter/material.dart';

import 'package:shophop/core/theme/app_colors.dart';
import 'package:shophop/features/buyer/data/services/buyer_catalog_service.dart';

class BuyerProductCard extends StatelessWidget {
  const BuyerProductCard({
    super.key,
    required this.product,
    required this.onTap,
    this.onLike,
    this.compact = false,
  });

  final BuyerProductData product;
  final VoidCallback onTap;
  final VoidCallback? onLike;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final soldLabel = product.sold > 999
        ? '${(product.sold / 1000).toStringAsFixed(product.sold >= 10000 ? 0 : 1)}k sold'
        : '${product.sold} sold';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE7EBF0)),
            boxShadow: [
              BoxShadow(
                color: AppColors.navy.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: compact ? 9 : 8,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _ProductImage(url: product.image, category: product.category),
                    if (product.discountPercent > 0)
                      Positioned(
                        left: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF15A5A),
                            borderRadius: BorderRadius.only(
                              bottomRight: Radius.circular(10),
                            ),
                          ),
                          child: Text(
                            '-${product.discountPercent}% ',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      right: 7,
                      top: 7,
                      child: InkWell(
                        onTap: onLike,
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.95),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFF0F2F5)),
                          ),
                          child: Icon(
                            product.isLiked
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: product.isLiked
                                ? const Color(0xFFE95D6A)
                                : AppColors.navy.withValues(alpha: 0.55),
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                    if (!product.isAvailable)
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          width: double.infinity,
                          color: Colors.black.withValues(alpha: 0.58),
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          child: const Text(
                            'Out of stock',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: compact ? 2 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        height: 1.28,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _price(product.price),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.tealDark,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    if (product.originalPrice != null &&
                        product.originalPrice! > product.price)
                      Text(
                        _price(product.originalPrice!),
                        style: TextStyle(
                          color: AppColors.navy.withValues(alpha: 0.36),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.lineThrough,
                        ),
                      )
                    else
                      const SizedBox(height: 11),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 12,
                          color: Color(0xFFFFC94B),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          product.rating > 0 ? product.rating.toStringAsFixed(1) : 'New',
                          style: TextStyle(
                            color: AppColors.navy.withValues(alpha: 0.6),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Flexible(
                          child: Text(
                            soldLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.navy.withValues(alpha: 0.55),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _price(double value) => '₱${value.toStringAsFixed(value == value.roundToDouble() ? 0 : 2)}';
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({required this.url, required this.category});

  final String url;
  final String category;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return Container(
        color: const Color(0xFFF4F6F8),
        alignment: Alignment.center,
        child: _ImageUnavailable(category: category),
      );
    }

    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: const Color(0xFFF4F6F8),
        alignment: Alignment.center,
        child: _ImageUnavailable(category: category),
      ),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          color: const Color(0xFFF4F6F8),
          alignment: Alignment.center,
          child: const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      },
    );
  }
}

/// Shared peso formatter used by the Buyer product detail screen.
/// Keep this helper available when updating the Buyer product card design.
String buyerPrice(double value) {
  final amount = value.toStringAsFixed(value % 1 == 0 ? 0 : 2);
  final parts = amount.split('.');
  final digits = parts.first;
  final formatted = StringBuffer();

  for (var i = 0; i < digits.length; i++) {
    final remaining = digits.length - i;
    formatted.write(digits[i]);
    if (remaining > 1 && remaining % 3 == 1) {
      formatted.write(',');
    }
  }

  if (parts.length > 1) {
    formatted.write('.${parts[1]}');
  }

  return '₱$formatted';
}


class _ImageUnavailable extends StatelessWidget {
  const _ImageUnavailable({required this.category});

  final String category;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.image_outlined, color: AppColors.navy.withValues(alpha: .24), size: 32),
        const SizedBox(height: 5),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            category.isEmpty ? 'Photo unavailable' : category,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.navy.withValues(alpha: .42),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
