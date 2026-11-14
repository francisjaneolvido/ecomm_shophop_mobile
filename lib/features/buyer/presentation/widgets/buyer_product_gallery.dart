import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shophop/features/buyer/data/services/buyer_catalog_service.dart';
import 'package:shophop/shared/widgets/shop_hop_product_media.dart';

List<BuyerMediaItem> buyerProductMedia(BuyerProductDetailData detail) {
  if (detail.media.isNotEmpty) return detail.media;
  final photos = detail.gallery.where((url) => url.isNotEmpty).toList();
  if (photos.isEmpty && detail.product.image.isNotEmpty) {
    photos.add(detail.product.image);
  }
  final video = detail.videoUrl.isEmpty
      ? <BuyerMediaItem>[]
      : [BuyerMediaItem(type: 'video', url: detail.videoUrl)];
  final media = <BuyerMediaItem>[
    if (detail.mediaFirst == 'video') ...video,
    ...photos.map((url) => BuyerMediaItem(type: 'image', url: url)),
    if (detail.mediaFirst != 'video') ...video,
  ];
  return media.isEmpty ? const [BuyerMediaItem(type: 'image', url: '')] : media;
}

class BuyerMediaImage extends StatelessWidget {
  const BuyerMediaImage({
    super.key,
    required this.url,
    this.fit = BoxFit.contain,
    this.dark = false,
  });
  final String url;
  final BoxFit fit;
  final bool dark;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    Widget fallback({bool loading = false}) => ColoredBox(
      color: dark ? Colors.black : colors.surfaceContainerLow,
      child: Center(
        child: loading
            ? const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                CupertinoIcons.photo,
                color: dark ? Colors.white54 : colors.onSurfaceVariant,
                size: 30,
              ),
      ),
    );
    if (url.isEmpty) return fallback();
    return Image.network(
      url,
      fit: fit,
      webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : fallback(loading: true),
      errorBuilder: (_, _, _) => fallback(),
    );
  }
}

Future<int> showBuyerMediaViewer(
  BuildContext context, {
  required List<BuyerMediaItem> media,
  int initialIndex = 0,
  String title = 'Product photos',
}) async {
  if (media.isEmpty) return 0;
  var selected = initialIndex.clamp(0, media.length - 1);
  final result = await Navigator.of(context).push<int>(
    MaterialPageRoute(
      builder: (_) => BuyerMediaViewer(
        media: media,
        initialIndex: selected,
        title: title,
        onChanged: (index) => selected = index,
      ),
    ),
  );
  return result ?? selected;
}

class BuyerProductGallery extends StatefulWidget {
  const BuyerProductGallery({
    super.key,
    required this.media,
    required this.controller,
    required this.index,
    required this.onChanged,
    this.active = true,
    this.showThumbnails = true,
  });
  final List<BuyerMediaItem> media;
  final PageController controller;
  final int index;
  final ValueChanged<int> onChanged;
  final bool active;
  final bool showThumbnails;
  @override
  State<BuyerProductGallery> createState() => _BuyerProductGalleryState();
}

class _BuyerProductGalleryState extends State<BuyerProductGallery> {
  bool _viewerOpen = false;
  void _select(int index) {
    if (widget.controller.hasClients) widget.controller.jumpToPage(index);
    widget.onChanged(index);
  }

  Future<void> _open() async {
    if (_viewerOpen) return;
    setState(() => _viewerOpen = true);
    try {
      final index = await showBuyerMediaViewer(
        context,
        media: widget.media,
        initialIndex: widget.index,
      );
      if (mounted) _select(index.clamp(0, widget.media.length - 1));
    } finally {
      if (mounted) setState(() => _viewerOpen = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.surface,
      child: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                PageView.builder(
                  controller: widget.controller,
                  itemCount: widget.media.length,
                  onPageChanged: widget.onChanged,
                  itemBuilder: (context, index) {
                    final item = widget.media[index];
                    return item.isVideo
                        ? ShopHopVideoPlayer(
                            key: ValueKey(item.url),
                            url: item.url,
                            active:
                                widget.active &&
                                !_viewerOpen &&
                                index == widget.index,
                          )
                        : Semantics(
                            button: true,
                            label: 'Open photo ${index + 1} full screen',
                            child: GestureDetector(
                              onTap: _open,
                              child: BuyerMediaImage(url: item.url),
                            ),
                          );
                  },
                ),
                Positioned(
                  right: 12,
                  bottom: 8,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.media[widget.index].isVideo)
                        IconButton(
                          tooltip: 'Open video full screen',
                          onPressed: _open,
                          style: IconButton.styleFrom(
                            backgroundColor: colors.surface.withValues(
                              alpha: .9,
                            ),
                          ),
                          icon: const Icon(CupertinoIcons.fullscreen, size: 18),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colors.surface.withValues(alpha: .9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${widget.index + 1}/${widget.media.length}',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (widget.showThumbnails && widget.media.length > 1)
            SizedBox(
              height: 62,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                itemCount: widget.media.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (context, index) => Semantics(
                  button: true,
                  selected: index == widget.index,
                  label:
                      'Select ${widget.media[index].isVideo ? 'video' : 'photo'} ${index + 1}',
                  child: InkWell(
                    onTap: () => _select(index),
                    child: Container(
                      width: 52,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: index == widget.index
                              ? colors.primary
                              : colors.outline,
                          width: index == widget.index ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      padding: const EdgeInsets.all(2),
                      child: widget.media[index].isVideo
                          ? ColoredBox(
                              color: colors.secondary,
                              child: const Icon(
                                CupertinoIcons.play_circle,
                                color: Colors.white,
                                size: 24,
                              ),
                            )
                          : BuyerMediaImage(
                              url: widget.media[index].url,
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class BuyerMediaViewer extends StatefulWidget {
  const BuyerMediaViewer({
    super.key,
    required this.media,
    required this.initialIndex,
    required this.title,
    required this.onChanged,
  });
  final List<BuyerMediaItem> media;
  final int initialIndex;
  final String title;
  final ValueChanged<int> onChanged;
  @override
  State<BuyerMediaViewer> createState() => _BuyerMediaViewerState();
}

class _BuyerMediaViewerState extends State<BuyerMediaViewer> {
  late final PageController _pages = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;
  bool _zoomed = false;
  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light,
    child: Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Close full screen',
                  onPressed: () => Navigator.pop(context, _index),
                  icon: const Icon(
                    CupertinoIcons.xmark,
                    color: Colors.white,
                    size: 21,
                  ),
                ),
                Expanded(
                  child: Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    '${_index + 1}/${widget.media.length}',
                    key: const ValueKey('viewer-counter'),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
            Expanded(
              child: PageView.builder(
                controller: _pages,
                physics: _zoomed ? const NeverScrollableScrollPhysics() : null,
                itemCount: widget.media.length,
                onPageChanged: (index) {
                  setState(() {
                    _index = index;
                    _zoomed = false;
                  });
                  widget.onChanged(index);
                },
                itemBuilder: (context, index) => widget.media[index].isVideo
                    ? Center(
                        child: ShopHopVideoPlayer(
                          key: ValueKey(widget.media[index].url),
                          url: widget.media[index].url,
                          active: index == _index,
                        ),
                      )
                    : _ZoomablePhoto(
                        key: ValueKey('viewer-photo-$index'),
                        url: widget.media[index].url,
                        onZoomChanged: (zoomed) {
                          if (index == _index && zoomed != _zoomed) {
                            setState(() => _zoomed = zoomed);
                          }
                        },
                      ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Pinch or double-tap to zoom. Swipe to browse.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ZoomablePhoto extends StatefulWidget {
  const _ZoomablePhoto({
    super.key,
    required this.url,
    required this.onZoomChanged,
  });
  final String url;
  final ValueChanged<bool> onZoomChanged;
  @override
  State<_ZoomablePhoto> createState() => _ZoomablePhotoState();
}

class _ZoomablePhotoState extends State<_ZoomablePhoto> {
  final _transform = TransformationController();
  Offset _tap = Offset.zero;
  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _doubleTap() {
    final zoomed = _transform.value.getMaxScaleOnAxis() > 1.01;
    _transform.value = zoomed
        ? Matrix4.identity()
        : (Matrix4.diagonal3Values(2.5, 2.5, 1)
            ..setTranslationRaw(-_tap.dx * 1.5, -_tap.dy * 1.5, 0));
    widget.onZoomChanged(!zoomed);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onDoubleTapDown: (details) => _tap = details.localPosition,
    onDoubleTap: _doubleTap,
    child: InteractiveViewer(
      transformationController: _transform,
      minScale: 1,
      maxScale: 4,
      onInteractionUpdate: (_) =>
          widget.onZoomChanged(_transform.value.getMaxScaleOnAxis() > 1.01),
      child: SizedBox.expand(
        child: BuyerMediaImage(url: widget.url, dark: true),
      ),
    ),
  );
}
