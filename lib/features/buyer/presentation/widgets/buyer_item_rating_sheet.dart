import 'package:flutter/material.dart';
import 'package:shophop/core/theme/app_colors.dart';
import 'package:shophop/features/buyer/data/services/buyer_order_service.dart';

class BuyerItemRatingSheet extends StatefulWidget {
  const BuyerItemRatingSheet({
    super.key,
    required this.item,
    required this.onSubmit,
    required this.onSessionExpired,
  });
  final BuyerOrderItemData item;
  final Future<void> Function(int rating, String comment) onSubmit;
  final Future<void> Function() onSessionExpired;

  @override
  State<BuyerItemRatingSheet> createState() => _BuyerItemRatingSheetState();
}

class _BuyerItemRatingSheetState extends State<BuyerItemRatingSheet> {
  final _comment = TextEditingController();
  int _rating = 0;
  bool _saving = false;
  String? _error;
  static const _labels = [
    'Select a star rating',
    'Poor',
    'Fair',
    'Good',
    'Very good',
    'Excellent',
  ];

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving || _rating == 0) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSubmit(_rating, _comment.text);
      if (mounted) Navigator.of(context).pop(true);
    } on BuyerOrderException catch (error) {
      if (!mounted) return;
      if (error.isUnauthorized) {
        Navigator.of(context).pop(false);
        await widget.onSessionExpired();
        return;
      }
      setState(() {
        _error = error.message;
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          20,
          24,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Rate your item',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              widget.item.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              widget.item.variant,
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 22),
            Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                children: List.generate(
                  5,
                  (index) => IconButton(
                    key: ValueKey('rate-star-${index + 1}'),
                    tooltip: '${index + 1} ${index == 0 ? 'star' : 'stars'}',
                    onPressed: _saving
                        ? null
                        : () => setState(() => _rating = index + 1),
                    iconSize: 34,
                    icon: Icon(
                      index < _rating
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: index < _rating
                          ? AppColors.warning
                          : AppColors.textMuted,
                    ),
                  ),
                ),
              ),
            ),
            Center(
              child: Text(
                _labels[_rating],
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 22),
            TextField(
              controller: _comment,
              enabled: !_saving,
              minLines: 3,
              maxLines: 5,
              maxLength: 2000,
              decoration: const InputDecoration(
                labelText: 'Your review (optional)',
                hintText: 'How was the quality, fit, or experience?',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your rating and review will be visible on the product page.',
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppColors.errorStrong),
                ),
              ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving || _rating == 0 ? null : _submit,
                child: Text(_saving ? 'Submitting…' : 'Submit rating'),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _saving
                    ? null
                    : () => Navigator.of(context).pop(false),
                child: const Text('Not now'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
