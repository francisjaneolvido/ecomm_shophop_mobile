import 'dart:async';
import 'package:flutter/widgets.dart';

/// Poll only while foregrounded and visible. Disposal cancels future ticks.
class ForegroundRefresh with WidgetsBindingObserver {
  ForegroundRefresh({
    required this.refresh,
    required this.canRefresh,
    this.interval = const Duration(seconds: 15),
  }) {
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(interval, (_) => _tick());
  }

  final Future<void> Function() refresh;
  final bool Function() canRefresh;
  final Duration interval;
  Timer? _timer;
  bool _busy = false;
  bool _disposed = false;
  bool _foreground = true;

  Future<void> _tick() async {
    if (_disposed || !_foreground || _busy || !canRefresh()) return;
    _busy = true;
    try {
      await refresh();
    } finally {
      _busy = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) _tick();
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
  }
}
