import 'package:flutter/foundation.dart';
import 'package:shophop/features/buyer/presentation/widgets/buyer_card_carousel.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:shophop/core/theme/app_colors.dart';
import 'package:shophop/features/buyer/data/services/buyer_catalog_service.dart';

part 'buyer_product_grid.dart';

/// Shared by Home, catalog, Likes, and related products.
class BuyerProductCard extends StatelessWidget {
  const BuyerProductCard({
    super.key,
    required this.product,
    required this.onTap,
    this.compact = false,
  });
  final BuyerProductData product;
  final VoidCallback onTap;
  final bool compact;

  static bool hasVideo(BuyerProductData product) =>
      product.videoFirst && product.videoUrl.isNotEmpty;

  static double contentExtent(BuildContext context) =>
      148 * MediaQuery.textScalerOf(context).scale(12) / 12;

  static double extent(
    BuildContext context,
    double width, {
    bool video = false,
  }) => width / (video ? .75 : 1) + contentExtent(context);

  static SliverGridDelegate gridDelegate(
    BuildContext context,
    double width,
    List<BuyerProductData> products,
  ) => _ProductGridDelegate(
    columns: width >= 1050
        ? 5
        : width >= 780
        ? 4
        : width >= 560
        ? 3
        : 2,
    contentHeight: contentExtent(context),
    videos: products.map(hasVideo).toList(),
  );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final discounted =
        product.originalPrice != null && product.originalPrice! > product.price;
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colors.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: hasVideo(product) ? .75 : 1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  BuyerCardCarousel(product: product, onOpen: onTap),
                  if (product.discountPercent > 0 || product.stock <= 5)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: product.discountPercent > 0
                              ? AppColors.commercePink
                              : colors.onSurface,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          product.discountPercent > 0
                              ? '-${product.discountPercent}%'
                              : 'LOW STOCK',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: Colors.white, fontSize: 10),
                        ),
                      ),
                    ),
                  if (product.videoUrl.isNotEmpty)
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.navy.withValues(alpha: .8),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.play_arrow_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                            SizedBox(width: 3),
                            Text(
                              'Video',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (!product.isAvailable)
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        width: double.infinity,
                        color: colors.onSurface.withValues(alpha: .8),
                        padding: const EdgeInsets.all(6),
                        child: Text(
                          'Currently unavailable',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: colors.surface),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(
              height: contentExtent(context),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        height: 1.3,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: MediaQuery.textScalerOf(context).scale(12) * 3,
                      child: Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.5,
                          fontWeight: FontWeight.w500,
                          color: colors.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      buyerPrice(product.price),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.3,
                        color: AppColors.commercePink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (discounted)
                      Text(
                        buyerPrice(product.originalPrice!),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          height: 1.2,
                          color: colors.onSurfaceVariant,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Icon(
                          product.reviews > 0
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          size: 13,
                          color: product.reviews > 0
                              ? const Color(0xFFF4AA23)
                              : colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            product.reviews > 0
                                ? '${product.rating.toStringAsFixed(1)} (${product.reviews})'
                                : 'No reviews yet',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              height: 1.2,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.sold > 0
                          ? '${product.sold} sold'
                          : '${product.stock} in stock',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        height: 1.2,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String buyerPrice(double value) {
  final parts = value.toStringAsFixed(2).split('.');
  final digits = parts.first;
  final formatted = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    formatted.write(digits[i]);
    final remaining = digits.length - i;
    if (remaining > 1 && remaining % 3 == 1) formatted.write(',');
  }
  return '\u20b1$formatted.${parts.last}';
}
