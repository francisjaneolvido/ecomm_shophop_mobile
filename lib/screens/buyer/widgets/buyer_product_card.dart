import 'package:flutter/material.dart';

import '../../../services/buyer_catalog_service.dart';
import '../../../theme/app_colors.dart';

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
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE9EDF0)),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x090F1B3D),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: compact ? 7 : 6,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _ProductImage(url: product.image),
                    if (!product.isAvailable)
                      Container(
                        color: Colors.white.withValues(alpha: 0.55),
                        alignment: Alignment.bottomCenter,
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.navy.withValues(alpha: 0.86),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Unavailable',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    if (product.discountPercent > 0)
                      Positioned(
                        left: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF5C5C),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '-${product.discountPercent}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      right: 7,
                      top: 7,
                      child: InkWell(
                        onTap: onLike,
                        customBorder: const CircleBorder(),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.94),
                            shape: BoxShape.circle,
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x19000000),
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            product.isLiked
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            size: 17,
                            color: const Color(0xFFED647C),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: compact ? 5 : 5,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontSize: 12.2,
                          height: 1.2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      if (product.originalPrice != null &&
                          product.originalPrice! > product.price)
                        Text(
                          _price(product.originalPrice!),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF9AA2AC),
                            fontSize: 9.5,
                            decoration: TextDecoration.lineThrough,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Text(
                              _price(product.price),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFEC526A),
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          if (product.sold > 0)
                            Text(
                              '${_compactCount(product.sold)} sold',
                              style: const TextStyle(
                                color: Color(0xFF8A929E),
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          if (product.rating > 0) ...[
                            const Icon(
                              Icons.star_rounded,
                              color: Color(0xFFFFB02E),
                              size: 13,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              product.rating.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Color(0xFF6F7782),
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Expanded(
                            child: Text(
                              product.seller.municipality.isNotEmpty
                                  ? product.seller.municipality
                                  : product.seller.businessName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF9299A3),
                                fontSize: 9.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return const _ProductImageFallback();
    }

    return Image.network(
      url,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const _ProductImageFallback(showLoader: true);
      },
      errorBuilder: (_, __, ___) => const _ProductImageFallback(),
    );
  }
}

class _ProductImageFallback extends StatelessWidget {
  const _ProductImageFallback({this.showLoader = false});

  final bool showLoader;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF0F5F5),
      alignment: Alignment.center,
      child: showLoader
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.teal,
              ),
            )
          : const Icon(
              Icons.image_outlined,
              size: 40,
              color: Color(0xFFB7C2C7),
            ),
    );
  }
}

String buyerPrice(double value) => _price(value);

String _price(double value) {
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

String _compactCount(int value) {
  if (value >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(value >= 10000000 ? 0 : 1)}M';
  }
  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(value >= 10000 ? 0 : 1)}k';
  }
  return '$value';
}
