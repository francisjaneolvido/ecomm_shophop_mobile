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

class _VariantPhotoCard extends StatelessWidget {
  const _VariantPhotoCard({
    required this.label,
    required this.image,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String image;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      enabled: onTap != null,
      label: onTap == null ? '$label, out of stock' : label,
      excludeSemantics: true,
      child: Material(
        color: selected ? colors.primaryContainer : colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: selected ? colors.primary : colors.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Opacity(
            opacity: onTap == null ? .45 : 1,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  children: [
                    AspectRatio(
                      aspectRatio: 1,
                      child: BuyerMediaImage(url: image),
                    ),
                    if (selected)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Icon(
                          Icons.check_circle,
                          size: 22,
                          color: colors.primary,
                        ),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 10,
                  ),
                  child: Column(
                    children: [
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: selected ? colors.primary : colors.onSurface,
                        ),
                      ),
                      if (onTap == null)
                        const Text(
                          'Out of stock',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 10),
                        ),
                    ],
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

Future<BuyerVariantSelection?> showBuyerVariantSheet(
  BuildContext context, {
  required BuyerProductDetailData detail,
  required BuyerVariantData? selected,
  required int quantity,
}) => showModalBottomSheet<BuyerVariantSelection>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
  ),
  clipBehavior: Clip.antiAlias,
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

  // Only split complete attribute combinations. Older products with just a
  // variant name continue to show one card per actual variant.
  List<String> get _axes {
    final variants = widget.detail.variants;
    if (variants.isEmpty) return const [];
    final keys = variants.first.attributes.keys.toList();
    if (keys.isEmpty ||
        variants.any(
          (v) =>
              v.attributes.length != keys.length ||
              keys.any(
                (key) => (v.attributes[key]?.toString().trim() ?? '').isEmpty,
              ),
        )) {
      return const [];
    }
    final color = keys
        .where(
          (key) =>
              key.toLowerCase() == 'color' || key.toLowerCase() == 'colour',
        )
        .firstOrNull;
    if (color != null) keys.insert(0, keys.removeAt(keys.indexOf(color)));
    return keys;
  }

  String _label(BuyerVariantData variant) =>
      variant.label.isEmpty ? variant.name : variant.label;

  String _value(BuyerVariantData variant, String axis) =>
      variant.attributes[axis].toString().trim();

  List<BuyerVariantData> _matches(
    String axis,
    String value, {
    required bool keepOthers,
  }) => widget.detail.variants
      .where(
        (variant) =>
            buyerSelectionStock(widget.detail, variant) > 0 &&
            _value(variant, axis) == value &&
            (!keepOthers ||
                _variant == null ||
                _axes.every(
                  (other) =>
                      other == axis ||
                      _value(variant, other) == _value(_variant!, other),
                )),
      )
      .toList();

  void _select(BuyerVariantData variant) => setState(() {
    _variant = variant;
    _quantity = _quantity.clamp(1, math.max(1, _stock));
  });

  Widget _photoOptions(BuildContext context, {String? axis}) {
    final variants = widget.detail.variants;
    final values = axis == null
        ? variants.map((v) => v.id.toString()).toList()
        : variants.map((v) => _value(v, axis)).toSet().toList();
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = math.max(2, (constraints.maxWidth / 112).floor());
        final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final value in values)
              Builder(
                builder: (context) {
                  final variant = axis == null
                      ? variants.firstWhere((v) => v.id.toString() == value)
                      : variants.firstWhere((v) => _value(v, axis) == value);
                  final candidates = axis == null
                      ? [
                          if (buyerSelectionStock(widget.detail, variant) > 0)
                            variant,
                        ]
                      : _matches(axis, value, keepOthers: false);
                  final selected = axis == null
                      ? _variant?.id == variant.id
                      : _variant != null && _value(_variant!, axis) == value;
                  return SizedBox(
                    width: width,
                    child: _VariantPhotoCard(
                      label: axis == null ? _label(variant) : value,
                      image: widget.detail.product.image,
                      selected: selected,
                      onTap: candidates.isEmpty
                          ? null
                          : () {
                              final compatible = axis == null
                                  ? candidates
                                  : _matches(axis, value, keepOthers: true);
                              _select(
                                compatible.firstOrNull ?? candidates.first,
                              );
                            },
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }

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
              padding: const EdgeInsets.fromLTRB(16, 20, 8, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox.square(
                      dimension: 88,
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
                        const SizedBox(height: 4),
                        Text(
                          _variant == null ? product.name : _label(_variant!),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
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
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (product.hasVariants) ...[
                      Text(
                        _axes.isEmpty
                            ? 'Variation (${widget.detail.variants.length})'
                            : '${_axes.first} (${widget.detail.variants.map((v) => _value(v, _axes.first)).toSet().length})',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (widget.detail.variants.isEmpty)
                        Text(
                          'No available variations.',
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      _photoOptions(context, axis: _axes.firstOrNull),
                      for (final axis in _axes.skip(1)) ...[
                        const SizedBox(height: 20),
                        Text(
                          axis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final value
                                in widget.detail.variants
                                    .map((v) => _value(v, axis))
                                    .toSet())
                              ChoiceChip(
                                label: Text(value),
                                selected:
                                    _variant != null &&
                                    _value(_variant!, axis) == value,
                                showCheckmark: false,
                                onSelected:
                                    _matches(
                                      axis,
                                      value,
                                      keepOthers: true,
                                    ).isEmpty
                                    ? null
                                    : (_) => _select(
                                        _matches(
                                          axis,
                                          value,
                                          keepOthers: true,
                                        ).first,
                                      ),
                              ),
                          ],
                        ),
                      ],
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
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    shape: const StadiumBorder(),
                  ),
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
