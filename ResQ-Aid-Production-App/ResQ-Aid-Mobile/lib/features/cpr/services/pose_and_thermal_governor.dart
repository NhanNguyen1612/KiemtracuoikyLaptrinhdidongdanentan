import '../domain/cpr_session_state.dart';
import '../../../../core/services/tts_service.dart';

typedef VoiceSpeakAction = Future<void> Function(String text);

/// Quản trị tư thế MoveNet, giới hạn giọng nói (5s) và hạ tải nhiệt thiết bị
class PoseAndThermalGovernor {
  static const int voiceRateLimitSeconds = 5;
  static const double optimalAngleMin = 165.0;
  static const double optimalAngleMax = 180.0;
  static const double warningAngleThreshold = 150.0;

  DateTime? _lastVoiceAlertTime;
  String? _lastVoiceMessage;
  VoiceSpeakAction _voiceAction = TtsService.speak;

  void setVoiceActionForTest(VoiceSpeakAction action) {
    _voiceAction = action;
  }

  /// Đánh giá chất lượng tư thế từ góc đo khuỷu tay
  PostureQuality evaluatePosture(double elbowAngleDeg) {
    if (elbowAngleDeg >= optimalAngleMin && elbowAngleDeg <= optimalAngleMax) {
      return PostureQuality.optimal;
    } else if (elbowAngleDeg < warningAngleThreshold) {
      return PostureQuality.elbowBent;
    }
    return PostureQuality.optimal;
  }

  /// Xử lý cảnh báo giọng nói với bộ lọc Rate-limit 5 giây
  /// Đảm bảo không phát lặp lại trong vòng 5 giây để tránh hoảng loạn
  bool handlePostureVoicePrompt(PostureQuality quality, {DateTime? customNow}) {
    final now = customNow ?? DateTime.now();

    if (quality == PostureQuality.elbowBent) {
      if (_lastVoiceAlertTime != null) {
        final diff = now.difference(_lastVoiceAlertTime!).inSeconds;
        if (diff < voiceRateLimitSeconds) {
          // Bị chặn bởi rate-limit 5s
          return false;
        }
      }

      // Đã đủ điều kiện phát
      _lastVoiceAlertTime = now;
      _lastVoiceMessage = 'Khóa thẳng khuỷu tay!';
      _voiceAction(_lastVoiceMessage!);
      return true;
    }

    return false;
  }

  /// Đánh giá trạng thái nhiệt độ và điều tiết FPS / Camera
  ThermalEvaluation evaluateThermalState(double batteryTempC) {
    if (batteryTempC >= 45.0) {
      return const ThermalEvaluation(
        state: ThermalState.critical,
        fps: 0,
        isCameraPreviewActive: false,
        warningMessage: 'Tắt camera để bảo vệ máy. Tiếp tục ép tim theo nhịp bíp và độ rung!',
      );
    } else if (batteryTempC >= 40.0) {
      return const ThermalEvaluation(
        state: ThermalState.throttled,
        fps: 15,
        isCameraPreviewActive: true,
        warningMessage: 'Chế độ tiết kiệm nhiệt: Đã tối ưu hóa AI (15fps)',
      );
    } else {
      return const ThermalEvaluation(
        state: ThermalState.nominal,
        fps: 30,
        isCameraPreviewActive: true,
        warningMessage: null,
      );
    }
  }

  void reset() {
    _lastVoiceAlertTime = null;
    _lastVoiceMessage = null;
  }
}

class ThermalEvaluation {
  final ThermalState state;
  final int fps;
  final bool isCameraPreviewActive;
  final String? warningMessage;

  const ThermalEvaluation({
    required this.state,
    required this.fps,
    required this.isCameraPreviewActive,
    this.warningMessage,
  });
}
