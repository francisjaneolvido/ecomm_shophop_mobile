import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shophop/shared/widgets/shop_hop_scan_feedback.dart';

class RecordingOutput implements ScanFeedbackOutput {
  final sounds = <ScanFeedbackEvent>[];
  final haptics = <ScanFeedbackEvent>[];
  bool unavailable = false;
  @override
  Future<void> play(ScanFeedbackEvent event) async {
    sounds.add(event);
    if (unavailable) throw StateError('Audio unavailable');
  }

  @override
  Future<void> vibrate(ScanFeedbackEvent event) async {
    haptics.add(event);
    if (unavailable) throw StateError('Haptics unavailable');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    ShopHopScanFeedback.soundEnabled.value = true;
    ShopHopScanFeedback.vibrationEnabled.value = true;
  });
  test(
    'Verified QR and confirmed handover have different cues; duplicate detections are suppressed',
    () async {
      final output = RecordingOutput();
      var now = DateTime(2026, 11, 8);
      final feedback = ShopHopScanFeedback(output: output, now: () => now);
      await feedback.report(ScanFeedbackEvent.verified, reference: 'SHP-1');
      await feedback.report(ScanFeedbackEvent.verified, reference: 'SHP-1');
      await feedback.report(ScanFeedbackEvent.complete, reference: 'SHP-1');
      await feedback.report(ScanFeedbackEvent.complete, reference: 'SHP-1');
      expect(output.sounds, [
        ScanFeedbackEvent.verified,
        ScanFeedbackEvent.complete,
      ]);
      expect(output.haptics, output.sounds);
      now = now.add(const Duration(seconds: 1));
      await feedback.report(ScanFeedbackEvent.verified, reference: 'SHP-1');
      await feedback.report(ScanFeedbackEvent.verified, reference: 'SHP-2');
      expect(output.sounds.length, 4);
    },
  );
  test('Sound and vibration can be disabled independently', () async {
    final output = RecordingOutput();
    final feedback = ShopHopScanFeedback(output: output);
    ShopHopScanFeedback.soundEnabled.value = false;
    await feedback.report(ScanFeedbackEvent.verified, reference: '1');
    expect(output.sounds, isEmpty);
    expect(output.haptics, [ScanFeedbackEvent.verified]);
    ShopHopScanFeedback.soundEnabled.value = true;
    ShopHopScanFeedback.vibrationEnabled.value = false;
    await feedback.report(ScanFeedbackEvent.complete, reference: '1');
    expect(output.sounds, [ScanFeedbackEvent.complete]);
    expect(output.haptics.length, 1);
  });
  test('Unavailable playback hardware does not fail the operation', () async {
    final output = RecordingOutput()..unavailable = true;
    await ShopHopScanFeedback(
      output: output,
    ).report(ScanFeedbackEvent.complete);
    expect(output.sounds, [ScanFeedbackEvent.complete]);
    expect(output.haptics, [ScanFeedbackEvent.complete]);
  });
  test(
    'All three bundled sounds are valid short, non-silent WAV assets',
    () async {
      for (final name in ['scan_verified', 'scan_complete', 'scan_error']) {
        final data = await rootBundle.load('assets/audio/$name.wav');
        expect(String.fromCharCodes(data.buffer.asUint8List(0, 4)), 'RIFF');
        expect(String.fromCharCodes(data.buffer.asUint8List(8, 4)), 'WAVE');
        expect(data.lengthInBytes, inInclusiveRange(2000, 44144));
        expect(data.buffer.asUint8List(44).any((b) => b != 0), isTrue);
      }
    },
  );
}
