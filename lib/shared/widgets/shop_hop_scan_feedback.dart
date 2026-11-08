import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum ScanFeedbackEvent { verified, complete, error }

abstract interface class ScanFeedbackOutput {
  Future<void> play(ScanFeedbackEvent event);
  Future<void> vibrate(ScanFeedbackEvent event);
}

class DeviceScanFeedbackOutput implements ScanFeedbackOutput {
  AudioPlayer? _player;
  Future<void> _pending = Future<void>.value();

  @override
  Future<void> play(ScanFeedbackEvent event) {
    final next = _pending.catchError((_) {}).then((_) => _play(event));
    _pending = next;
    return next;
  }

  Future<void> _play(ScanFeedbackEvent event) async {
    final player = _player ??= AudioPlayer();
    await player.stop();
    final name = switch (event) {
      ScanFeedbackEvent.verified => 'scan_verified',
      ScanFeedbackEvent.complete => 'scan_complete',
      ScanFeedbackEvent.error => 'scan_error',
    };
    await player.play(AssetSource('audio/$name.wav'), volume: .6);
  }

  @override
  Future<void> vibrate(ScanFeedbackEvent event) => switch (event) {
    ScanFeedbackEvent.verified => HapticFeedback.selectionClick(),
    ScanFeedbackEvent.complete => HapticFeedback.mediumImpact(),
    ScanFeedbackEvent.error => HapticFeedback.heavyImpact(),
  };
}

/// Feedback follows API outcomes. Audio/haptic failure never fails a handover.
class ShopHopScanFeedback {
  ShopHopScanFeedback({ScanFeedbackOutput? output, DateTime Function()? now})
    : _output = output ?? DeviceScanFeedbackOutput(),
      _now = now ?? DateTime.now;

  static ShopHopScanFeedback instance = ShopHopScanFeedback();
  // Session preferences shared across all scanner screens.
  static final soundEnabled = ValueNotifier(true);
  static final vibrationEnabled = ValueNotifier(true);
  final ScanFeedbackOutput _output;
  final DateTime Function() _now;
  final Map<String, DateTime> _recent = {};

  void notify(ScanFeedbackEvent event, {String? reference}) {
    unawaited(report(event, reference: reference));
  }

  Future<void> report(ScanFeedbackEvent event, {String? reference}) async {
    final now = _now();
    final key = '${event.name}:${reference ?? ''}';
    final previous = _recent[key];
    if (previous != null &&
        now.difference(previous) < const Duration(milliseconds: 900)) {
      return;
    }
    _recent.removeWhere(
      (_, when) => now.difference(when) > const Duration(seconds: 5),
    );
    _recent[key] = now;
    await Future.wait([
      if (soundEnabled.value) _safely(() => _output.play(event)),
      if (vibrationEnabled.value) _safely(() => _output.vibrate(event)),
    ]);
  }

  Future<void> _safely(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      // Muted/unsupported hardware and playback restrictions leave scanning usable.
    }
  }
}
