import 'package:flutter/material.dart';
import 'package:shophop/core/theme/app_colors.dart';

/// Shared presentation for Cart and Checkout; prices stay supplied by the API.
class PurchaseText {
  PurchaseText._();
  static const title = TextStyle(
    fontSize: 21,
    fontWeight: FontWeight.w600,
    color: AppColors.navy,
  );
  static const section = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.4,
    color: AppColors.navy,
  );
  static const product = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.4,
    color: AppColors.navy,
  );
  static const detail = TextStyle(
    fontSize: 12,
    height: 1.5,
    color: AppColors.textMuted,
  );
  static const price = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.4,
    color: AppColors.navy,
  );
}

String purchasePrice(double amount) => '₱${amount.toStringAsFixed(2)}';

class PurchaseImage extends StatelessWidget {
  const PurchaseImage({super.key, required this.url, this.size = 72});
  final String url;
  final double size;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(10),
    child: Container(
      width: size,
      height: size,
      color: AppColors.surfaceSoft,
      child: url.isEmpty
          ? const Icon(Icons.image_outlined, color: AppColors.textMuted)
          : Image.network(
              url,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.image_not_supported_outlined,
                color: AppColors.textMuted,
              ),
            ),
    ),
  );
}

class PurchasePrice extends StatelessWidget {
  const PurchasePrice({super.key, required this.value, this.original});
  final double value;
  final double? original;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 2,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      Text(purchasePrice(value), style: PurchaseText.price),
      if (original != null && original! > value)
        Text(
          purchasePrice(original!),
          style: PurchaseText.detail.copyWith(
            decoration: TextDecoration.lineThrough,
          ),
        ),
    ],
  );
}

class PurchaseBottomBar extends StatelessWidget {
  const PurchaseBottomBar({
    super.key,
    required this.summary,
    required this.action,
  });
  final Widget summary;
  final Widget action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: Material(
      color: AppColors.surface,
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final stacked =
                  constraints.maxWidth < 330 ||
                  MediaQuery.textScalerOf(context).scale(14) > 18;
              return stacked
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [summary, const SizedBox(height: 10), action],
                    )
                  : Row(
                      children: [
                        Expanded(child: summary),
                        const SizedBox(width: 16),
                        Flexible(child: action),
                      ],
                    );
            },
          ),
        ),
      ),
    ),
  );
}
