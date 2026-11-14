import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shophop/core/theme/app_colors.dart';
import 'package:shophop/core/config/api_config.dart';
import 'package:shophop/features/buyer/data/services/buyer_order_service.dart';

class BuyerItemRatingPage extends StatefulWidget {
  const BuyerItemRatingPage({
    super.key,
    required this.item,
    required this.onSubmit,
    required this.onSessionExpired,
    this.pickMedia,
  });
  final BuyerOrderItemData item;
  final Future<void> Function(
    int rating,
    String comment,
    List<PlatformFile> media,
  )
  onSubmit;
  final Future<void> Function() onSessionExpired;
  final Future<List<PlatformFile>?> Function()? pickMedia;

  @override
  State<BuyerItemRatingPage> createState() => _BuyerItemRatingPageState();
}

class _BuyerItemRatingPageState extends State<BuyerItemRatingPage> {
  final _comment = TextEditingController();
  int _rating = 0;
  bool _saving = false;
  String? _error;
  List<PlatformFile> _media = [];
  bool _picking = false;

  Future<void> _chooseMedia() async {
    if (_saving || _picking) return;
    setState(() => _picking = true);
    try {
      final selected = widget.pickMedia != null
          ? await widget.pickMedia!()
          : (await FilePicker.pickFiles(
              type: FileType.custom,
              allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'mp4'],
              allowMultiple: true,
              withData: true,
            ))?.files;
      if (!mounted || selected == null) return;
      final files = [..._media];
      for (final file in selected) {
        if (files.any(
          (old) => old.name == file.name && old.size == file.size,
        )) {
          continue;
        }
        files.add(file);
      }
      BuyerOrderService.validateReviewMedia(files);
      setState(() {
        _media = files;
        _error = null;
      });
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is BuyerOrderException
              ? error.message
              : 'Could not open media picker. Try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

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
    if (_saving || _picking || _rating == 0) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSubmit(_rating, _comment.text, List.unmodifiable(_media));
      if (mounted) Navigator.of(context).pop(true);
    } on BuyerOrderException catch (error) {
      if (!mounted) return;
      if (error.isUnauthorized) {
        Navigator.of(context).pop(false);
        await widget.onSessionExpired();
        return;
      }
      setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Could not submit your review. Your rating, text, and attachments are kept. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final blocked = _saving || _picking;
    return PopScope(
      canPop: !blocked,
      child: Scaffold(
        backgroundColor: AppColors.page,
        appBar: AppBar(
          title: const Text(
            'Rate product',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 19),
          ),
          leading: IconButton(
            tooltip: 'Back to orders',
            onPressed: blocked ? null : () => Navigator.of(context).pop(false),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
        ),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: SingleChildScrollView(
              key: const ValueKey('rating-form-scroll'),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.pinkSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.favorite_outline_rounded,
                          size: 20,
                          color: AppColors.navy,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Your experience helps other buyers choose with confidence.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.5,
                              color: AppColors.navy,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Material(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _productSummary(),
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'How was your item?',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Tap a star to share your rating.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Center(
                                child: Wrap(
                                  alignment: WrapAlignment.center,
                                  spacing: 3,
                                  children: List.generate(
                                    5,
                                    (index) => IconButton(
                                      key: ValueKey('rate-star-${index + 1}'),
                                      tooltip:
                                          '${index + 1} ${index == 0 ? 'star' : 'stars'}',
                                      onPressed: blocked
                                          ? null
                                          : () => setState(
                                              () => _rating = index + 1,
                                            ),
                                      iconSize: 40,
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
                              const SizedBox(height: 4),
                              Center(
                                child: Text(
                                  _labels[_rating],
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 26),
                              const Text(
                                'Add photos & videos',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Optional · Show the details that matter.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _uploadArea(),
                              const SizedBox(height: 8),
                              const Text(
                                'Up to 6 photos (5 MB each) and 2 MP4 videos (30 MB each).',
                                style: TextStyle(
                                  fontSize: 10,
                                  height: 1.5,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              if (_media.isNotEmpty) ...[
                                const SizedBox(height: 14),
                                Text(
                                  '${_media.where((file) => file.extension?.toLowerCase() != 'mp4').length}/6 photos · ${_media.where((file) => file.extension?.toLowerCase() == 'mp4').length}/2 videos',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                _attachmentPreviews(),
                              ],
                              const SizedBox(height: 26),
                              const Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Write your review',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    'Optional',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _comment,
                                enabled: !blocked,
                                minLines: 5,
                                maxLines: 8,
                                maxLength: 2000,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.6,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'Your review (optional)',
                                  floatingLabelBehavior:
                                      FloatingLabelBehavior.never,
                                  hintText:
                                      'How was the quality? Did it match the description?\n\nShare what you liked or what could be better.',
                                  hintStyle: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 12,
                                    height: 1.6,
                                  ),
                                  filled: true,
                                  fillColor: AppColors.surfaceSoft,
                                  contentPadding: const EdgeInsets.all(16),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: AppColors.border,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: AppColors.border,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.visibility_outlined,
                                    size: 16,
                                    color: AppColors.textMuted,
                                  ),
                                  SizedBox(width: 7),
                                  Expanded(
                                    child: Text(
                                      'Your rating, review, and attachments will be visible on the product page.',
                                      style: TextStyle(
                                        fontSize: 11,
                                        height: 1.5,
                                        color: AppColors.textMuted,
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
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Material(
            color: Colors.white,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Center(
                  heightFactor: 1,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 608),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Semantics(
                              liveRegion: true,
                              child: Text(
                                _error!,
                                style: const TextStyle(
                                  color: AppColors.errorStrong,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        SizedBox(
                          height: 50,
                          child: FilledButton(
                            onPressed: blocked || _rating == 0 ? null : _submit,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (_saving) ...[
                                  const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                ],
                                Flexible(
                                  child: Text(
                                    _saving
                                        ? (_media.isEmpty
                                              ? 'Submitting…'
                                              : 'Uploading review…')
                                        : 'Submit rating',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _productSummary() => Padding(
    padding: const EdgeInsets.all(16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 60,
            height: 60,
            child: widget.item.image?.isNotEmpty == true
                ? Image.network(
                    ApiConfig.resolveMediaUrl(widget.item.image),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _productPlaceholder(),
                  )
                : _productPlaceholder(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.item.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '${widget.item.variant} · Qty ${widget.item.quantity}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _productPlaceholder() => const ColoredBox(
    color: AppColors.surfaceSoft,
    child: Icon(
      Icons.inventory_2_outlined,
      color: AppColors.textMuted,
      size: 26,
    ),
  );

  Widget _uploadArea() => SizedBox(
    width: double.infinity,
    child: CustomPaint(
      painter: const _UploadBorderPainter(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _saving || _picking ? null : _chooseMedia,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 14,
              vertical: _media.isEmpty ? 24 : 16,
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.pinkSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.add_photo_alternate_outlined,
                    color: AppColors.navy,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _picking ? 'Opening gallery…' : 'Add photos or videos',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Choose from your gallery',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _attachmentPreviews() => Wrap(
    spacing: 8,
    runSpacing: 10,
    children: List.generate(_media.length, (index) {
      final file = _media[index];
      final video = file.extension?.toLowerCase() == 'mp4';
      return SizedBox(
        width: 88,
        child: Column(
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 88,
                    height: 80,
                    child: video
                        ? const ColoredBox(
                            color: AppColors.pinkSoft,
                            child: Icon(
                              Icons.play_circle_outline_rounded,
                              size: 30,
                            ),
                          )
                        : Image.memory(
                            file.bytes!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                const Icon(Icons.image_outlined),
                          ),
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: IconButton.filled(
                    tooltip: 'Remove ${file.name}',
                    onPressed: _saving || _picking
                        ? null
                        : () => setState(() => _media.removeAt(index)),
                    icon: const Icon(Icons.close, size: 16),
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              file.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10),
            ),
            Text(
              '${(file.size / 1024 / 1024).toStringAsFixed(1)} MB',
              style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }),
  );
}

class _UploadBorderPainter extends CustomPainter {
  const _UploadBorderPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)),
      );
    final paint = Paint()
      ..color = AppColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final metric in path.computeMetrics()) {
      for (double offset = 0; offset < metric.length; offset += 10) {
        canvas.drawPath(
          metric.extractPath(offset, (offset + 5).clamp(0, metric.length)),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _UploadBorderPainter oldDelegate) => false;
}
