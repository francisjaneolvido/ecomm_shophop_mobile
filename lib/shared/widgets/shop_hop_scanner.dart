import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shophop/core/theme/app_colors.dart';
import 'package:shophop/shared/widgets/shop_hop_scan_feedback.dart';

class ShopHopScanPreferences extends StatelessWidget {
  const ShopHopScanPreferences({super.key});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: ValueListenableBuilder<bool>(
          valueListenable: ShopHopScanFeedback.soundEnabled,
          builder: (_, enabled, _) => TextButton.icon(
            onPressed: () => ShopHopScanFeedback.soundEnabled.value = !enabled,
            icon: Icon(
              enabled ? CupertinoIcons.speaker_2 : CupertinoIcons.speaker_slash,
              size: 17,
            ),
            label: Text(
              enabled ? 'Sound on' : 'Sound off',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ),
        ),
      ),
      Expanded(
        child: ValueListenableBuilder<bool>(
          valueListenable: ShopHopScanFeedback.vibrationEnabled,
          builder: (_, enabled, _) => TextButton.icon(
            onPressed: () =>
                ShopHopScanFeedback.vibrationEnabled.value = !enabled,
            icon: const Icon(Icons.vibration, size: 17),
            label: Text(
              enabled ? 'Vibration on' : 'Vibration off',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ),
        ),
      ),
    ],
  );
}

class ShopHopScanSteps extends StatelessWidget {
  const ShopHopScanSteps({super.key, required this.step});
  final int step;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      children: [
        for (var i = 0; i < 3; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i == 2 ? 0 : 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: i <= step ? AppColors.tealDark : AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${i + 1}  ${['Scan', 'Review', 'Confirm'][i]}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: i == step ? FontWeight.w600 : FontWeight.w400,
                      color: i <= step
                          ? AppColors.tealDark
                          : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

class ShopHopCameraPanel extends StatelessWidget {
  const ShopHopCameraPanel({
    super.key,
    required this.controller,
    required this.onDetect,
    required this.scanning,
    required this.busy,
    required this.onToggle,
    this.instruction = 'Align the ShopHop QR inside the frame',
  });
  final MobileScannerController controller;
  final void Function(BarcodeCapture) onDetect;
  final bool scanning;
  final bool busy;
  final VoidCallback onToggle;
  final String instruction;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: AspectRatio(
          aspectRatio: 1.15,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (scanning)
                MobileScanner(controller: controller, onDetect: onDetect)
              else
                ColoredBox(
                  color: AppColors.navy,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          CupertinoIcons.qrcode_viewfinder,
                          size: 64,
                          color: AppColors.tealLight.withValues(alpha: .8),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          busy ? 'Verifying QR...' : 'Ready to scan',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (scanning)
                const IgnorePointer(
                  child: CustomPaint(painter: _ScanFramePainter()),
                ),
              if (scanning)
                Positioned(
                  top: 10,
                  right: 10,
                  child: ValueListenableBuilder<MobileScannerState>(
                    valueListenable: controller,
                    builder: (context, state, _) => IconButton(
                      tooltip: state.torchState == TorchState.on
                          ? 'Turn flashlight off'
                          : 'Turn flashlight on',
                      onPressed: state.torchState == TorchState.unavailable
                          ? null
                          : () async {
                              try {
                                await controller.toggleTorch();
                              } catch (_) {}
                            },
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.navy.withValues(alpha: .7),
                        foregroundColor: Colors.white,
                      ),
                      icon: Icon(
                        state.torchState == TorchState.on
                            ? Icons.flash_on
                            : Icons.flash_off,
                        size: 21,
                      ),
                    ),
                  ),
                ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Text(
                  instruction,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.4,
                    color: Colors.white,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              if (busy)
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(minHeight: 3),
                ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 10),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: busy ? null : onToggle,
          icon: Icon(
            scanning
                ? CupertinoIcons.pause_circle
                : CupertinoIcons.qrcode_viewfinder,
            size: 20,
          ),
          label: Text(scanning ? 'Pause camera' : 'Open camera'),
        ),
      ),
      const ShopHopScanPreferences(),
    ],
  );
}

class _ScanFramePainter extends CustomPainter {
  const _ScanFramePainter();
  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(220.0, math.min(size.width - 48, size.height - 70));
    final rect = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: side,
      height: side,
    );
    final cutout = RRect.fromRectAndRadius(rect, const Radius.circular(16));
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(cutout);
    canvas.drawPath(path, Paint()..color = Colors.black.withValues(alpha: .45));
    canvas.drawRRect(
      cutout,
      Paint()
        ..color = Colors.white.withValues(alpha: .5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    final p = Paint()
      ..color = AppColors.teal
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    for (final point in [
      rect.topLeft,
      rect.topRight,
      rect.bottomLeft,
      rect.bottomRight,
    ]) {
      final x = point.dx == rect.left ? 1 : -1;
      final y = point.dy == rect.top ? 1 : -1;
      canvas.drawLine(
        point + Offset(0, 20.0 * y),
        point + Offset(0, 5.0 * y),
        p,
      );
      canvas.drawLine(
        point + Offset(5.0 * x, 0),
        point + Offset(20.0 * x, 0),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ScanFramePainter oldDelegate) => false;
}

class ShopHopScanNotice extends StatelessWidget {
  const ShopHopScanNotice({
    super.key,
    required this.message,
    required this.success,
    this.onNext,
    this.nextLabel = 'Scan next',
  });
  final String message;
  final bool success;
  final VoidCallback? onNext;
  final String nextLabel;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: success ? AppColors.tealLight : const Color(0xFFFFF3E8),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
        color: success
            ? AppColors.tealDark.withValues(alpha: .25)
            : const Color(0xFFF0D7B4),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              success
                  ? CupertinoIcons.checkmark_seal_fill
                  : CupertinoIcons.exclamationmark_circle,
              size: 22,
              color: success ? AppColors.tealDark : const Color(0xFF9B5718),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    success ? 'Confirmed' : 'Check before continuing',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    message,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      fontWeight: FontWeight.w400,
                      color: AppColors.navy,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (onNext != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onNext,
              icon: const Icon(CupertinoIcons.qrcode_viewfinder, size: 18),
              label: Text(nextLabel),
            ),
          ),
      ],
    ),
  );
}
