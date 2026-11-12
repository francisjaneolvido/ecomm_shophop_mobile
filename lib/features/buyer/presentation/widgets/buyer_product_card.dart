import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shophop/core/theme/app_colors.dart';
import 'package:shophop/core/theme/app_theme.dart';
import 'package:shophop/features/buyer/data/services/buyer_catalog_service.dart';

/// Shared by Home, catalog, Likes, and related products.
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

  /// A square photo plus enough room for actual content and enlarged text.
  static double extent(BuildContext context, double width) =>
      width + 142 * MediaQuery.textScalerOf(context).scale(12) / 12;

  static SliverGridDelegate gridDelegate(BuildContext context, double width) {
    final columns = width >= 1050
        ? 5
        : width >= 780
        ? 4
        : width >= 560
        ? 3
        : 2;
    final cellWidth = (width - (columns - 1) * 12) / columns;
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: columns,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      mainAxisExtent: extent(context, cellWidth),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final discounted =
        product.originalPrice != null && product.originalPrice! > product.price;
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        side: BorderSide(color: colors.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(
                    color: colors.surfaceContainerLow,
                    child: product.image.isEmpty
                        ? _PhotoUnavailable(category: product.category)
                        : Image.network(
                            product.image,
                            webHtmlElementStrategy:
                                WebHtmlElementStrategy.fallback,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) =>
                                _PhotoUnavailable(category: product.category),
                            loadingBuilder: (context, child, progress) =>
                                progress == null
                                ? child
                                : Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: colors.primary,
                                    ),
                                  ),
                          ),
                  ),
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
                          color: colors.onSurface,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          product.discountPercent > 0
                              ? '-${product.discountPercent}%'
                              : 'LOW STOCK',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colors.surface,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                  if (onLike != null)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: IconButton(
                        onPressed: onLike,
                        tooltip:
                            '${product.isLiked ? 'Remove' : 'Save'} ${product.name} ${product.isLiked ? 'from' : 'to'} Likes',
                        style: IconButton.styleFrom(
                          backgroundColor: colors.surface.withValues(
                            alpha: .95,
                          ),
                          foregroundColor: product.isLiked
                              ? colors.primary
                              : colors.onSurfaceVariant,
                        ),
                        icon: Icon(
                          product.isLiked
                              ? CupertinoIcons.heart_fill
                              : CupertinoIcons.heart,
                          size: 21,
                        ),
                      ),
                    ),
                  if (product.videoFirst && product.videoUrl.isNotEmpty)
                    const Center(
                      child: Icon(CupertinoIcons.play_circle_fill, size: 36),
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
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colors.surface,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.category,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 10,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    buyerPrice(product.price),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: AppColors.pink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    discounted ? buyerPrice(product.originalPrice!) : ' ',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 10,
                      color: colors.onSurfaceVariant,
                      decoration: discounted
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    product.reviews > 0
                        ? '\u2605 ${product.rating.toStringAsFixed(1)} \u00b7 ${product.reviews} reviews'
                        : product.sold > 0
                        ? '${product.sold} completed sales'
                        : '${product.stock} in stock',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 10,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
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

class _PhotoUnavailable extends StatelessWidget {
  const _PhotoUnavailable({required this.category});
  final String category;
  @override
  Widget build(BuildContext context) => Center(
    child: Icon(
      Icons.image_outlined,
      size: 34,
      color: Theme.of(context).colorScheme.outline,
    ),
  );
}
