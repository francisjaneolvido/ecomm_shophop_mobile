import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shophop/features/buyer/data/services/buyer_catalog_service.dart';
import 'package:shophop/features/buyer/presentation/widgets/buyer_product_card.dart';
import 'package:shophop/features/buyer/presentation/widgets/buyer_product_gallery.dart';

int buyerSelectionStock(
  BuyerProductDetailData detail,
  BuyerVariantData? variant,
) {
  if (!detail.product.isAvailable || detail.product.stock <= 0) return 0;
  if (!detail.product.hasVariants) return detail.product.stock;
  if (variant == null || !variant.inStock || variant.status != 'active') {
    return 0;
  }
  return math.max(0, math.min(detail.product.stock, variant.stock));
}

class BuyerVariantSelection {
  const BuyerVariantSelection({required this.variant, required this.quantity});
  final BuyerVariantData? variant;
  final int quantity;
}

Future<BuyerVariantSelection?> showBuyerVariantSheet(
  BuildContext context, {
  required BuyerProductDetailData detail,
  required BuyerVariantData? selected,
  required int quantity,
}) => showModalBottomSheet<BuyerVariantSelection>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) =>
      BuyerVariantSheet(detail: detail, selected: selected, quantity: quantity),
);

class BuyerVariantSheet extends StatefulWidget {
  const BuyerVariantSheet({
    super.key,
    required this.detail,
    required this.selected,
    required this.quantity,
  });
  final BuyerProductDetailData detail;
  final BuyerVariantData? selected;
  final int quantity;
  @override
  State<BuyerVariantSheet> createState() => _BuyerVariantSheetState();
}

class _BuyerVariantSheetState extends State<BuyerVariantSheet> {
  BuyerVariantData? _variant;
  int _quantity = 1;
  int get _stock => buyerSelectionStock(widget.detail, _variant);
  @override
  void initState() {
    super.initState();
    final available = widget.detail.variants.where(
      (v) => buyerSelectionStock(widget.detail, v) > 0,
    );
    final previous = available.where((v) => v.id == widget.selected?.id);
    _variant = previous.isNotEmpty ? previous.first : available.firstOrNull;
    _quantity = widget.quantity.clamp(1, math.max(1, _stock));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final product = widget.detail.product;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .85,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 4, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox.square(
                      dimension: 64,
                      child: BuyerMediaImage(url: product.image),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          buyerPrice(_variant?.price ?? product.price),
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: colors.primary,
                          ),
                        ),
                        Text(
                          '$_stock available',
                          key: const ValueKey('selection-stock'),
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cancel selection',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(CupertinoIcons.xmark, size: 19),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (product.hasVariants) ...[
                      const Text(
                        'Variation',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (widget.detail.variants.isEmpty)
                        Text(
                          'No available variations.',
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          for (final variant in widget.detail.variants)
                            ChoiceChip(
                              label: Text(
                                variant.label.isEmpty
                                    ? variant.name
                                    : variant.label,
                              ),
                              selected: _variant?.id == variant.id,
                              showCheckmark: false,
                              labelStyle: TextStyle(
                                fontSize: 12,
                                color:
                                    buyerSelectionStock(
                                          widget.detail,
                                          variant,
                                        ) >
                                        0
                                    ? colors.onSurface
                                    : colors.onSurfaceVariant,
                              ),
                              onSelected:
                                  buyerSelectionStock(widget.detail, variant) <=
                                      0
                                  ? null
                                  : (_) => setState(() {
                                      _variant = variant;
                                      _quantity = _quantity.clamp(1, _stock);
                                    }),
                            ),
                        ],
                      ),
                      const Divider(height: 24),
                    ],
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Quantity',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Decrease quantity',
                          onPressed: _quantity > 1
                              ? () => setState(() => _quantity--)
                              : null,
                          icon: const Icon(CupertinoIcons.minus, size: 18),
                        ),
                        SizedBox(
                          width: 38,
                          child: Text(
                            '$_quantity',
                            key: const ValueKey('selection-quantity'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Increase quantity',
                          onPressed: _quantity < _stock
                              ? () => setState(() => _quantity++)
                              : null,
                          icon: const Icon(CupertinoIcons.plus, size: 18),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _stock <= 0
                      ? null
                      : () => Navigator.pop(
                          context,
                          BuyerVariantSelection(
                            variant: _variant,
                            quantity: _quantity,
                          ),
                        ),
                  child: Text(
                    _stock <= 0 ? 'Currently unavailable' : 'Confirm selection',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
