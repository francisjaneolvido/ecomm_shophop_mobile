import 'package:flutter/material.dart';
import 'package:shophop/core/theme/app_colors.dart';
import 'package:shophop/features/buyer/data/services/buyer_catalog_service.dart';
import 'package:shophop/features/buyer/presentation/widgets/buyer_product_gallery.dart';
import 'package:shophop/shared/widgets/shop_hop_product_media.dart';

/// List cards browse the same seller-ordered media as the product detail page.
class BuyerCardCarousel extends StatefulWidget {
  const BuyerCardCarousel({
    super.key,
    required this.product,
    required this.onOpen,
  });
  final BuyerProductData product;
  final VoidCallback onOpen;
  @override
  State<BuyerCardCarousel> createState() => _BuyerCardCarouselState();
}

class _BuyerCardCarouselState extends State<BuyerCardCarousel> {
  int _index = 0;
  bool _playing = false;
  List<BuyerMediaItem> get _media {
    if (widget.product.media.isNotEmpty) return widget.product.media;
    final image = BuyerMediaItem(type: 'image', url: widget.product.image);
    final video = BuyerMediaItem(type: 'video', url: widget.product.videoUrl);
    return [
      if (widget.product.videoFirst && video.url.isNotEmpty) video,
      if (image.url.isNotEmpty) image,
      if (!widget.product.videoFirst && video.url.isNotEmpty) video,
      if (image.url.isEmpty && video.url.isEmpty) image,
    ];
  }

  @override
  void didUpdateWidget(covariant BuyerCardCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.product.id != widget.product.id) {
      _index = 0;
      _playing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = _media;
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          key: ValueKey('product-carousel-${widget.product.id}'),
          itemCount: media.length,
          onPageChanged: (index) => setState(() {
            _index = index;
            _playing = false;
          }),
          itemBuilder: (context, index) {
            final item = media[index];
            if (item.isVideo && _playing && index == _index) {
              return ShopHopVideoPlayer(
                url: item.url,
                autoplay: true,
                active: true,
              );
            }
            return GestureDetector(
              onTap: item.isVideo
                  ? () => setState(() => _playing = true)
                  : widget.onOpen,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  BuyerMediaImage(
                    url: item.isVideo ? widget.product.image : item.url,
                    fit: BoxFit.cover,
                  ),
                  if (item.isVideo)
                    Center(
                      child: Semantics(
                        button: true,
                        label: 'Play product video',
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.navy.withValues(alpha: .8),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
        if (media.length > 1)
          Positioned(
            right: 8,
            top: 8,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.navy.withValues(alpha: .75),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_index + 1}/${media.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 9),
                ),
              ),
            ),
          ),
        if (media.length > 1 && !_playing)
          Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var index = 0; index < media.length; index++)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      width: index == _index ? 14 : 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: index == _index
                            ? AppColors.pink
                            : Colors.white70,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
