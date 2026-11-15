import 'package:flutter/material.dart';
import 'package:shophop/core/config/api_config.dart';
import 'package:video_player/video_player.dart';

class AfterSalesEvidenceStrip extends StatelessWidget {
  const AfterSalesEvidenceStrip({
    super.key,
    required this.token,
    required this.caseId,
    required this.evidence,
  });

  final String token;
  final int caseId;
  final dynamic evidence;

  @override
  Widget build(BuildContext context) {
    final files = evidence is List ? evidence as List : const [];
    if (files.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Buyer evidence',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in files)
                if (entry is Map && entry['index'] is int)
                  _tile(
                    context,
                    entry['index'] as int,
                    entry['type'] == 'video',
                  ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, int index, bool video) {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/after-sales/$caseId/buyer-evidence/$index',
    );
    final headers = {'Authorization': 'Bearer $token'};
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => showDialog<void>(
        context: context,
        builder: (_) => video
            ? _EvidenceVideoDialog(uri: uri, headers: headers)
            : Dialog(
                child: InteractiveViewer(
                  child: Image.network(
                    uri.toString(),
                    headers: headers,
                    errorBuilder: (_, _, _) => const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Photo unavailable.'),
                    ),
                  ),
                ),
              ),
      ),
      child: Container(
        width: 96,
        height: 96,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(10),
        ),
        child: video
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.play_circle_outline, size: 32),
                  Text('Play video'),
                ],
              )
            : Image.network(
                uri.toString(),
                headers: headers,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    const Icon(Icons.broken_image_outlined),
              ),
      ),
    );
  }
}

class _EvidenceVideoDialog extends StatefulWidget {
  const _EvidenceVideoDialog({required this.uri, required this.headers});

  final Uri uri;
  final Map<String, String> headers;

  @override
  State<_EvidenceVideoDialog> createState() => _EvidenceVideoDialogState();
}

class _EvidenceVideoDialogState extends State<_EvidenceVideoDialog> {
  late final VideoPlayerController _controller;
  late final Future<void> _ready;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(
      widget.uri,
      httpHeaders: widget.headers,
    );
    _ready = _controller.initialize().then((_) async {
      if (mounted) await _controller.play();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: FutureBuilder<void>(
        future: _ready,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Text('Video could not be played.');
          }
          if (snapshot.connectionState != ConnectionState.done) {
            return const SizedBox(
              height: 180,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              ),
              IconButton(
                tooltip: 'Play or pause video',
                icon: Icon(
                  _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                ),
                onPressed: () {
                  setState(
                    () => _controller.value.isPlaying
                        ? _controller.pause()
                        : _controller.play(),
                  );
                },
              ),
            ],
          );
        },
      ),
    ),
  );
}
