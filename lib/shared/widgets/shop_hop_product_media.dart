import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:shophop/core/config/api_config.dart';
import 'package:shophop/core/theme/app_colors.dart';

/// Responsive product thumbnail used by Seller inventory and product editors.
/// Video players are created only on tap (not for every row of inventory).
class ShopHopProductThumbnail extends StatelessWidget {
  const ShopHopProductThumbnail({
    super.key,
    this.imageUrl,
    this.videoUrl,
    this.videoFirst = false,
    this.width = 72,
    this.height = 72,
  });
  final String? imageUrl;
  final String? videoUrl;
  final bool videoFirst;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final image = ApiConfig.resolveMediaUrl(imageUrl);
    final video = ApiConfig.resolveMediaUrl(videoUrl);
    final canPlay = video.isNotEmpty;
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Material(
        color: const Color(0xFFF0F4F6),
        child: InkWell(
          onTap: canPlay
              ? () => ShopHopVideoPreview.open(context, video)
              : null,
          child: SizedBox(
            width: width,
            height: height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (image.isNotEmpty)
                  Image.network(
                    image,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const _MediaPlaceholder(),
                  )
                else
                  const _MediaPlaceholder(),
                if (canPlay && videoFirst)
                  ColoredBox(
                    color: const Color(0x510F1B3D),
                    child: Center(
                      child: Icon(
                        Icons.play_circle_fill_rounded,
                        size: width < 60 ? 24 : 32,
                        color: Colors.white,
                      ),
                    ),
                  ),
                if (canPlay)
                  Positioned(
                    left: 3,
                    bottom: 3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.navy,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: const Text(
                        'VIDEO',
                        style: TextStyle(
                          fontSize: 8,
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
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
  }
}

class _MediaPlaceholder extends StatelessWidget {
  const _MediaPlaceholder();
  @override
  Widget build(BuildContext context) => const Center(
    child: Icon(
      Icons.image_not_supported_outlined,
      color: Color(0xFF97A5B4),
      size: 26,
    ),
  );
}

class ShopHopVideoPreview {
  const ShopHopVideoPreview._();
  static Future<void> open(BuildContext context, String url) async {
    final resolved = ApiConfig.resolveMediaUrl(url);
    if (resolved.isEmpty) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Product video',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 12),
              ShopHopVideoPlayer(url: resolved, active: true),
              const SizedBox(height: 10),
              const Text(
                'Tap Play to preview. Playback requires a reachable video URL.',
                style: TextStyle(fontSize: 11, color: Color(0xFF607084)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Gallery and preview video player with pause, mute, retry/error behavior.
/// Does not auto-start other videos when scrolling a product list.
class ShopHopVideoPlayer extends StatefulWidget {
  const ShopHopVideoPlayer({super.key, required this.url, this.active = true});
  final String url;
  final bool active;
  @override
  State<ShopHopVideoPlayer> createState() => _ShopHopVideoPlayerState();
}

class _ShopHopVideoPlayerState extends State<ShopHopVideoPlayer> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final url = ApiConfig.resolveMediaUrl(widget.url);
    final uri = Uri.tryParse(url);
    if (uri == null || !['http', 'https'].contains(uri.scheme)) {
      if (mounted) setState(() => _failed = true);
      return;
    }
    final controller = VideoPlayerController.networkUrl(uri);
    _controller = controller;
    try {
      await controller.initialize();
      if (!mounted || !identical(_controller, controller)) return;
      await controller.setLooping(true);
      await controller.setVolume(0);
      if (mounted) {
        setState(() {
          _ready = true;
          _failed = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _failed = true;
          _ready = false;
        });
      }
    }
  }

  @override
  void didUpdateWidget(covariant ShopHopVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      final previous = _controller;
      _controller = null;
      _ready = false;
      _failed = false;
      previous?.dispose();
      _init();
    } else if (!widget.active && oldWidget.active) {
      _controller?.pause();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Container(
      constraints: const BoxConstraints(minHeight: 180),
      color: AppColors.navy,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: _failed
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.videocam_off_outlined,
                      size: 32,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Video cannot be loaded.',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Check the media link or internet connection.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 10),
                    ),
                  ],
                ),
              )
            : !_ready || controller == null
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.teal),
              )
            : Stack(
                alignment: Alignment.center,
                children: [
                  Center(
                    child: AspectRatio(
                      aspectRatio: controller.value.aspectRatio > 0
                          ? controller.value.aspectRatio
                          : 16 / 9,
                      child: VideoPlayer(controller),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: ColoredBox(
                      color: const Color(0x880F1B3D),
                      child: Row(
                        children: [
                          IconButton(
                            tooltip: controller.value.isPlaying
                                ? 'Pause'
                                : 'Play',
                            onPressed: () async {
                              if (controller.value.isPlaying) {
                                await controller.pause();
                              } else {
                                await controller.play();
                              }
                              if (mounted) setState(() {});
                            },
                            icon: Icon(
                              controller.value.isPlaying
                                  ? Icons.pause_circle_filled_rounded
                                  : Icons.play_circle_fill_rounded,
                              color: Colors.white,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            tooltip: 'Toggle sound',
                            onPressed: () async {
                              await controller.setVolume(
                                controller.value.volume == 0 ? 1 : 0,
                              );
                              if (mounted) setState(() {});
                            },
                            icon: Icon(
                              controller.value.volume == 0
                                  ? Icons.volume_off_rounded
                                  : Icons.volume_up_rounded,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
