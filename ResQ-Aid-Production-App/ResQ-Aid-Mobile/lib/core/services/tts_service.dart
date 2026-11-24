import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  static final FlutterTts _flutterTts = FlutterTts();
  static bool _initialized = false;
  static bool _isSpeaking = false;
  static VoidCallback? onCompletion;

  /// Trạng thái AI đang phát giọng nói qua loa ngoài
  static bool get isSpeaking => _isSpeaking;

  static Future<void> init() async {
    if (_initialized) return;
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      _initialized = true;
      return;
    }
    try {
      await _flutterTts.setLanguage('vi-VN').timeout(const Duration(milliseconds: 600), onTimeout: () => 0);
      await _flutterTts.setSpeechRate(0.5).timeout(const Duration(milliseconds: 400), onTimeout: () => 0);
      await _flutterTts.setVolume(1.0).timeout(const Duration(milliseconds: 400), onTimeout: () => 0);
      await _flutterTts.setPitch(1.0).timeout(const Duration(milliseconds: 400), onTimeout: () => 0);

      _flutterTts.setStartHandler(() {
        _isSpeaking = true;
      });
      _flutterTts.setCompletionHandler(() {
        _isSpeaking = false;
        onCompletion?.call();
      });
      _flutterTts.setCancelHandler(() {
        _isSpeaking = false;
      });
      _flutterTts.setErrorHandler((_) {
        _isSpeaking = false;
      });
      _initialized = true;
    } catch (_) {
      // Bỏ qua nếu môi trường test không hỗ trợ TTS native
    }
  }

  /// Phát âm thanh phản hồi AI hoàn toàn bất đồng bộ (Non-blocking) để không bao giờ gây ANR / đơ app
  static Future<void> speak(String text) async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) return;
    try {
      if (!_initialized) await init();
      _isSpeaking = true;
      await _flutterTts.stop();
      await _flutterTts.speak(text);
    } catch (_) {
      _isSpeaking = false;
    }
  }

  static Future<void> stop() async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) return;
    try {
      _isSpeaking = false;
      await _flutterTts.stop();
    } catch (_) {}
  }
}
