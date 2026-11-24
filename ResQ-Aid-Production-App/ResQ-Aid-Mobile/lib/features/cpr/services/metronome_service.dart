import 'dart:async';
import 'package:flutter/services.dart';

typedef MetronomeBeatCallback = void Function(int beatIndex, double jitterMs);

/// Service điều phối nhịp Metronome 110 BPM với độ trễ Jitter <= 5ms
class MetronomeService {
  static const int targetBpm = 110;
  static const int targetIntervalUs = 545455; // 60,000,000 / 110 us ≈ 545.45 ms

  Timer? _timer;
  final Stopwatch _stopwatch = Stopwatch();
  int _lastTickUs = 0;
  int _beatCount = 0;
  double _lastJitterMs = 0.0;
  bool _isRunning = false;
  bool _soundEnabled = true;
  bool _hapticEnabled = true;

  MetronomeBeatCallback? onBeat;

  bool get isRunning => _isRunning;
  double get lastJitterMs => _lastJitterMs;
  int get beatCount => _beatCount;

  void configure({bool? soundEnabled, bool? hapticEnabled, MetronomeBeatCallback? onBeat}) {
    if (soundEnabled != null) _soundEnabled = soundEnabled;
    if (hapticEnabled != null) _hapticEnabled = hapticEnabled;
    if (onBeat != null) this.onBeat = onBeat;
  }

  void start() {
    if (_isRunning) return;
    _isRunning = true;
    _stopwatch.reset();
    _stopwatch.start();
    _lastTickUs = 0;
    _beatCount = 0;

    // Kích hoạt ngay nhịp đầu tiên
    _triggerBeat();

    // Vòng lặp nhịp 545ms
    _timer = Timer.periodic(const Duration(milliseconds: 545), (timer) {
      if (!_isRunning) {
        timer.cancel();
        return;
      }
      _triggerBeat();
    });
  }

  void _triggerBeat() {
    final nowUs = _stopwatch.elapsedMicroseconds;
    if (_lastTickUs > 0) {
      final deltaUs = nowUs - _lastTickUs;
      final diffUs = (deltaUs - targetIntervalUs).abs();
      _lastJitterMs = diffUs / 1000.0;
    } else {
      _lastJitterMs = 0.0;
    }
    _lastTickUs = nowUs;
    _beatCount++;

    // Xúc giác: Rung phản hồi tức thì
    if (_hapticEnabled) {
      HapticFeedback.heavyImpact();
    }

    // Âm thanh: Nhịp click hệ thống
    if (_soundEnabled) {
      SystemSound.play(SystemSoundType.click);
    }

    onBeat?.call(_beatCount, _lastJitterMs);
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _stopwatch.stop();
    _isRunning = false;
  }

  void reset() {
    stop();
    _beatCount = 0;
    _lastTickUs = 0;
    _lastJitterMs = 0.0;
  }
}
