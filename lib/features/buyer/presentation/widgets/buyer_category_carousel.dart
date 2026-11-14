import 'package:flutter/material.dart';
import 'package:shophop/core/theme/app_colors.dart';
import 'package:shophop/features/buyer/data/services/buyer_catalog_service.dart';
import 'package:shophop/features/buyer/presentation/widgets/buyer_category_icon.dart';

/// A single row of categories in the exact order returned by Laravel.
class BuyerCategoryCarousel extends StatefulWidget {
  const BuyerCategoryCarousel({
    super.key,
    required this.categories,
    required this.onCategory,
    required this.onRetry,
    this.refreshing = false,
  });

  final List<BuyerCategoryData> categories;
  final ValueChanged<BuyerCategoryData> onCategory;
  final VoidCallback onRetry;
  final bool refreshing;

  @override
  State<BuyerCategoryCarousel> createState() => _BuyerCategoryCarouselState();
}

class _BuyerCategoryCarouselState extends State<BuyerCategoryCarousel> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (widget.categories.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Text(
              'No categories available right now.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
            TextButton.icon(
              onPressed: widget.refreshing ? null : widget.onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: Text(
                widget.refreshing ? 'Refreshing…' : 'Refresh categories',
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final textScaler = MediaQuery.textScalerOf(context);
        final scale = textScaler.scale(12) / 12;
        // Four items plus a small peek on a typical phone. Larger text receives
        // wider items and extra label height rather than another row.
        final itemWidth =
            (constraints.maxWidth / 4.2).clamp(84.0, 112.0) *
            scale.clamp(1.0, 1.5);
        final labelHeight = textScaler.scale(12) * 1.3 * 2;
        return SizedBox(
          key: const ValueKey('buyer-category-carousel'),
          height: 40 + 8 + labelHeight + 20,
          child: Scrollbar(
            controller: _scrollController,
            thumbVisibility: true,
            thickness: 3,
            radius: const Radius.circular(3),
            child: ListView.builder(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              primary: false,
              padding: const EdgeInsets.only(bottom: 12),
              itemExtent: itemWidth,
              itemCount: widget.categories.length,
              itemBuilder: (context, index) {
                final category = widget.categories[index];
                return Tooltip(
                  message: category.name,
                  excludeFromSemantics: true,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      key: ValueKey('buyer-category-${category.slug}'),
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => widget.onCategory(category),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: const BoxDecoration(
                                color: AppColors.pinkSoft,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                buyerCategoryIcon(category.icon),
                                size: 22,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: labelHeight,
                              child: Center(
                                child: Text(
                                  category.name,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontSize: 12,
                                    height: 1.3,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
