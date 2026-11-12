import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shophop/core/theme/app_colors.dart';
import 'package:shophop/core/config/api_config.dart';
import 'package:shophop/features/seller/data/services/seller_workspace_service.dart';
import 'package:shophop/shared/widgets/shop_hop_navigation.dart';
import 'package:shophop/shared/widgets/shop_hop_ui.dart';
import 'package:shophop/shared/widgets/shop_hop_product_media.dart';

/// Mobile version of the Seller Web's simple-product workflow.
/// Variant matrices, image deletion and vouchers remain Web-only.
class SellerProductEditorScreen extends StatefulWidget {
  const SellerProductEditorScreen({
    super.key,
    required this.token,
    required this.businessCategory,
    required this.subcategories,
    this.product,
  });
  final String token;
  final String businessCategory;
  final List<String> subcategories;
  final Map<String, dynamic>? product;

  @override
  State<SellerProductEditorScreen> createState() =>
      _SellerProductEditorScreenState();
}

class _SellerProductEditorScreenState extends State<SellerProductEditorScreen> {
  final _key = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _sku = TextEditingController();
  final _price = TextEditingController();
  final _weight = TextEditingController();
  final _discount = TextEditingController();
  final _stock = TextEditingController();
  final _threshold = TextEditingController();
  final _description = TextEditingController();
  List<PlatformFile> _photos = [];
  PlatformFile? _video;
  bool _removeVideo = false;
  List<String> _mediaTokens = [];
  String? _subcategory;
  String? _error;
  bool _saving = false;

  bool get _editing => widget.product != null;
  int? get _productId => int.tryParse(widget.product?['id']?.toString() ?? '');

  @override
  void initState() {
    super.initState();
    final p = widget.product ?? {};
    final currentMedia = p['media'];
    if (currentMedia is List) {
      _mediaTokens = currentMedia
          .whereType<Map>()
          .map((entry) => entry['key']?.toString() ?? '')
          .where((key) => key.isNotEmpty)
          .toList();
    }

    _name.text = p['name']?.toString() ?? '';
    _sku.text = p['sku']?.toString() ?? '';
    _price.text = p['price']?.toString() ?? '';
    _weight.text = p['weight_kg']?.toString() ?? '0.5';
    _discount.text = p['discount']?.toString() ?? '0';
    _stock.text = p['stock']?.toString() ?? '0';
    _threshold.text = p['low_stock_threshold']?.toString() ?? '10';
    _description.text = p['description']?.toString() ?? '';
    final current = p['subcategory']?.toString();
    _subcategory = widget.subcategories.contains(current) ? current : null;
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _sku,
      _price,
      _weight,
      _discount,
      _stock,
      _threshold,
      _description,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _label(String name, {bool isRequired = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        Text(
          name,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        if (isRequired)
          const Text(
            ' *',
            style: TextStyle(
              color: Color(0xFFD43E47),
              fontWeight: FontWeight.w900,
            ),
          ),
        if (!isRequired)
          const Text(
            ' (Optional)',
            style: TextStyle(color: Color(0xFF6B6B7B), fontSize: 11),
          ),
      ],
    ),
  );

  Widget _field(
    String label,
    TextEditingController controller, {
    bool isRequired = false,
    TextInputType? keyboard,
    int lines = 1,
    String? Function(String?)? validate,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label, isRequired: isRequired),
        TextFormField(
          controller: controller,
          keyboardType: keyboard,
          maxLines: lines,
          inputFormatters: keyboard == null
              ? null
              : <TextInputFormatter>[
                  FilteringTextInputFormatter.allow(
                    keyboard == TextInputType.number
                        ? RegExp(r'[0-9]')
                        : RegExp(r'[0-9.]'),
                  ),
                ],
          textInputAction: lines > 1
              ? TextInputAction.newline
              : TextInputAction.next,
          decoration: InputDecoration(
            hintText: label,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          validator:
              validate ??
              (isRequired
                  ? (value) => (value ?? '').trim().isEmpty
                        ? '$label is required.'
                        : null
                  : null),
        ),
      ],
    ),
  );

  String? _nonNegative(
    String? value, {
    double minimum = 0,
    bool whole = false,
  }) {
    final number = double.tryParse((value ?? '').trim());
    if (number == null ||
        number < minimum ||
        (whole && number != number.roundToDouble())) {
      return whole
          ? 'Enter a whole number (0 or above).'
          : 'Enter a value of at least $minimum.';
    }
    return null;
  }

  Future<void> _chooseMedia() async {
    if (_saving) return;
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'mp4'],
        allowMultiple: true,
        withData: true,
      );
      if (!mounted || result == null) return;
      final photos = [..._photos];
      final order = [..._mediaTokens];
      PlatformFile? video = _video;
      var videoSeen = false;
      for (final file in result.files) {
        final extension = file.extension?.toLowerCase() ?? '';
        if (file.bytes == null) {
          setState(() => _error = 'Could not read ${file.name}. Please retry.');
          return;
        }
        if (extension == 'mp4') {
          if (file.size > 30 * 1024 * 1024 || videoSeen) {
            setState(
              () => _error = 'Only one MP4 video up to 30 MB can be selected.',
            );
            return;
          }
          videoSeen = true;
          video = file;
          if (!order.contains('video')) order.add('video');
        } else if (['jpg', 'jpeg', 'png', 'webp'].contains(extension)) {
          if (photos.length >= 8 || file.size > 5 * 1024 * 1024) {
            setState(
              () => _error = 'Maximum 8 photos; each photo must be under 5 MB.',
            );
            return;
          }
          order.add('new:${photos.length}');
          photos.add(file);
        }
      }
      setState(() {
        _photos = photos;
        _video = video;
        if (videoSeen) _removeVideo = false;
        _mediaTokens = order;
        _error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not open media picker. Try again.');
      }
    }
  }

  Future<void> _save() async {
    if (_saving || !_key.currentState!.validate()) return;
    if (_subcategory == null) {
      setState(() => _error = 'Choose an allowed subcategory.');
      return;
    }
    final ok = await shopHopConfirm(
      context,
      title: _editing ? 'Update this product?' : 'Create this product?',
      message:
          'Only ${widget.businessCategory} subcategories are allowed. '
          'Product details will be reviewed by ShopHop Admin before appearing to buyers.',
      confirmLabel: _editing ? 'Save changes' : 'Create product',
    );
    if (!ok || !mounted) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final result = await SellerWorkspaceService.saveProduct(
      token: widget.token,
      productId: _productId,
      images: _photos,
      video: _video,
      removeVideo: _removeVideo,
      fields: {
        'name': _name.text.trim(),
        'sku': _sku.text.trim(),
        'subcategory': _subcategory!,
        'price': _price.text.trim(),
        'weight_kg': _weight.text.trim(),
        'discount': _discount.text.trim(),
        'stock': _stock.text.trim(),
        'low_stock_threshold': _threshold.text.trim(),
        'description': _description.text.trim(),
        'media_first': _mediaTokens.isNotEmpty && _mediaTokens.first == 'video'
            ? 'video'
            : 'image',
        'media_sequence': jsonEncode(_mediaTokens),
      },
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _error = result.success ? null : result.message;
    });
    if (result.success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.grayBg,
    appBar: AppBar(
      title: Text(_editing ? 'Edit product' : 'Add product'),
      actions: [
        if (_saving)
          const Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
      ],
    ),
    body: Form(
      key: _key,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              ShopHopSurface(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Product information',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Registered shop: ${widget.businessCategory}',
                      style: const TextStyle(
                        color: Color(0xFF6B6B7B),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _field('Product name', _name, isRequired: true),
                    _field('SKU', _sku),
                    _label('Subcategory', isRequired: true),
                    DropdownButtonFormField<String>(
                      initialValue: _subcategory,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      hint: const Text('Choose subcategory'),
                      items: widget.subcategories
                          .map(
                            (s) => DropdownMenuItem(
                              value: s,
                              child: Text(s, overflow: TextOverflow.ellipsis),
                            ),
                          )
                          .toList(),
                      onChanged: _saving
                          ? null
                          : (value) => setState(() => _subcategory = value),
                      validator: (value) =>
                          value == null ? 'Subcategory is required.' : null,
                    ),
                    const SizedBox(height: 14),
                    _field('Description', _description, lines: 3),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ShopHopSurface(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pricing & stock',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 15),
                    _field(
                      'Price (PHP)',
                      _price,
                      isRequired: true,
                      keyboard: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validate: (v) => _nonNegative(v),
                    ),
                    _field(
                      'Weight (kg)',
                      _weight,
                      isRequired: true,
                      keyboard: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validate: (v) => _nonNegative(v, minimum: 0.05),
                    ),
                    _field(
                      'Available stock',
                      _stock,
                      isRequired: true,
                      keyboard: TextInputType.number,
                      validate: (v) => _nonNegative(v, whole: true),
                    ),
                    _field(
                      'Low-stock alert threshold',
                      _threshold,
                      keyboard: TextInputType.number,
                      validate: (v) => (v ?? '').trim().isEmpty
                          ? null
                          : _nonNegative(v, whole: true),
                    ),
                    _field(
                      'Discount (%)',
                      _discount,
                      keyboard: TextInputType.number,
                      validate: (v) {
                        if ((v ?? '').trim().isEmpty) return null;
                        final n = int.tryParse(v!.trim());
                        return n == null || n < 0 || n > 100
                            ? 'Enter 0 to 100.'
                            : null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ShopHopSurface(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Product media',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Photos and video in one gallery. The first item is featured. Tap the star to feature another item.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF6B6B7B)),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _saving ? null : _chooseMedia,
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: const Text('Add photos or MP4 video'),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Up to 8 photos (5 MB each) and one video (30 MB).',
                      style: TextStyle(fontSize: 11, color: Color(0xFF6B6B7B)),
                    ),
                    const SizedBox(height: 12),
                    for (var index = 0; index < _mediaTokens.length; index++)
                      Builder(
                        builder: (context) {
                          final token = _mediaTokens[index];
                          final isVideo = token == 'video';
                          final isNew = token.startsWith('new:');
                          final newIndex = isNew
                              ? int.tryParse(token.substring(4))
                              : null;
                          final photo =
                              newIndex != null && newIndex < _photos.length
                              ? _photos[newIndex]
                              : null;
                          final oldList = widget.product?['media'];
                          Map? oldItem;
                          if (oldList is List) {
                            for (final item in oldList) {
                              if (item is Map &&
                                  item['key']?.toString() == token) {
                                oldItem = item;
                                break;
                              }
                            }
                          }
                          return Card(
                            margin: const EdgeInsets.only(bottom: 7),
                            child: ListTile(
                              dense: true,
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: SizedBox(
                                  width: 48,
                                  height: 48,
                                  child: isVideo
                                      ? ShopHopProductThumbnail(
                                          imageUrl: widget.product?['image_url']
                                              ?.toString(),
                                          videoUrl: _video == null
                                              ? (oldItem?['url']?.toString() ??
                                                    widget.product?['video_url']
                                                        ?.toString())
                                              : null,
                                          videoFirst: true,
                                          width: 48,
                                          height: 48,
                                        )
                                      : photo?.bytes != null
                                      ? Image.memory(
                                          photo!.bytes!,
                                          fit: BoxFit.cover,
                                        )
                                      : oldItem != null
                                      ? Image.network(
                                          ApiConfig.resolveMediaUrl(
                                            oldItem['url']?.toString(),
                                          ),
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              const Icon(Icons.image_outlined),
                                        )
                                      : const Icon(Icons.image_outlined),
                                ),
                              ),
                              title: Text(
                                isVideo
                                    ? 'Product video'
                                    : (photo?.name ?? 'Product photo'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                isVideo && _video != null
                                    ? '${_video!.name} · Preview available after saving'
                                    : index == 0
                                    ? '★ Featured · appears first'
                                    : 'Position ${index + 1}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: PopupMenuButton<String>(
                                tooltip: 'Media options',
                                icon: const Icon(Icons.more_vert),
                                onSelected: (action) => setState(() {
                                  _mediaTokens.removeAt(index);
                                  final position = action == 'feature'
                                      ? 0
                                      : action == 'up'
                                      ? index - 1
                                      : index + 1;
                                  _mediaTokens.insert(
                                    position
                                        .clamp(0, _mediaTokens.length)
                                        .toInt(),
                                    token,
                                  );
                                }),
                                itemBuilder: (_) => [
                                  if (index > 0)
                                    const PopupMenuItem(
                                      value: 'feature',
                                      child: Text('Set as featured'),
                                    ),
                                  if (index > 0)
                                    const PopupMenuItem(
                                      value: 'up',
                                      child: Text('Move earlier'),
                                    ),
                                  if (index < _mediaTokens.length - 1)
                                    const PopupMenuItem(
                                      value: 'down',
                                      child: Text('Move later'),
                                    ),
                                ],
                                enabled: !_saving && _mediaTokens.length > 1,
                              ),
                            ),
                          );
                        },
                      ),
                    if ((widget.product?['video_url']?.toString() ?? '')
                            .isNotEmpty &&
                        _video == null)
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Remove existing video'),
                        value: _removeVideo,
                        onChanged: _saving
                            ? null
                            : (v) => setState(() {
                                _removeVideo = v;
                                if (v) {
                                  _mediaTokens.remove('video');
                                } else if (!_mediaTokens.contains('video')) {
                                  _mediaTokens.add('video');
                                }
                              }),
                      ),
                    const SizedBox(height: 4),
                    const Text(
                      'You can still manage old photo deletions in Seller Web.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF6B6B7B)),
                    ),
                  ],
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Color(0xFFB42318)),
                  ),
                ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.check_circle_outline),
                label: Text(
                  _saving
                      ? 'Saving...'
                      : _editing
                      ? 'Review & save'
                      : 'Review & add product',
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Changes will require Admin compliance approval before public visibility.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Color(0xFF6B6B7B)),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
