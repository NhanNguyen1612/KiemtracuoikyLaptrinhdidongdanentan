import 'dart:io';
import 'package:flutter/material.dart';
import 'voice_dialogue_service.dart';

/// Quản lý trạng thái Bong bóng nổi (Floating PiP Bubble) và Màn hình Live Voice
class VoiceBubbleController extends ChangeNotifier {
  static final VoiceBubbleController _instance = VoiceBubbleController._internal();
  factory VoiceBubbleController() => _instance;
  VoiceBubbleController._internal();

  bool _isLiveActive = false;
  bool _isMinimized = false;
  Offset _bubblePosition = const Offset(280, 560);
  String _currentContext = 'GENERAL';
  final VoiceDialogueService _dialogueService = VoiceDialogueService();

  bool get isLiveActive => _isLiveActive;
  bool get isMinimized => _isMinimized;
  Offset get bubblePosition => _bubblePosition;
  String get currentContext => _currentContext;
  VoiceDialogueService get dialogueService => _dialogueService;

  /// Cập nhật vị trí kéo thả của bong bóng nổi
  void updatePosition(Offset newPos) {
    _bubblePosition = newPos;
    notifyListeners();
  }

  /// Kích hoạt phiên hội thoại Live Voice
  Future<void> startLiveSession({
    String contextHint = 'GENERAL',
    bool startMinimized = false,
  }) async {
    _isLiveActive = true;
    _isMinimized = startMinimized;
    _currentContext = contextHint;
    _dialogueService.continuousLiveMode = false; // Mặc định: Bấm mới ghi âm (Manual) tránh tự động thu âm ngoài ý muốn

    // Tránh gọi Native Speech-to-Text bị treo khi đang chạy test môi trường VM
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      try {
        await _dialogueService.initialize();
        // Chỉ tự động lắng nghe nếu đang bật chế độ Tự động rảnh tay (continuousLiveMode)
        if (_dialogueService.continuousLiveMode) {
          await _dialogueService.startListening(contextHint: contextHint);
        }
      } catch (_) {}
    }
    notifyListeners();
  }

  /// Thu nhỏ thành bong bóng nổi (Floating PiP Bubble) ở góc màn hình
  void minimizeToBubble({String? newContext}) {
    if (newContext != null) {
      _currentContext = newContext;
    }
    _isMinimized = true;
    notifyListeners();
  }

  /// Phóng to trở lại toàn màn hình (Fullscreen Live Voice)
  void expandToFullscreen({String? newContext}) {
    if (newContext != null) {
      _currentContext = newContext;
    }
    _isMinimized = false;
    notifyListeners();
  }

  /// Chuyển đổi trạng thái thu nhỏ / phóng to
  void toggleMinimize() {
    _isMinimized = !_isMinimized;
    notifyListeners();
  }

  /// Kết thúc phiên Live Voice hoàn toàn
  Future<void> closeLiveSession() async {
    _isLiveActive = false;
    _isMinimized = false;
    _dialogueService.continuousLiveMode = false;
    await _dialogueService.stopListening();
    notifyListeners();
  }
}
