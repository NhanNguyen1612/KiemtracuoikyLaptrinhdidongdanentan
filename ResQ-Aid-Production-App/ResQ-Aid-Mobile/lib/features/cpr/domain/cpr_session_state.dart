import 'dart:convert';

/// Trạng thái tư thế theo MoveNet
enum PostureQuality {
  optimal, // Khóa thẳng khuỷu tay 165° - 180° (Xanh lục)
  elbowBent, // Tay bị cong < 150° (Đỏ cảnh báo)
  uncalibrated, // Chưa phát hiện được khớp
}

/// Trạng thái nhiệt độ phần cứng
enum ThermalState {
  nominal, // < 40°C: 30 fps
  throttled, // 40°C - 44.9°C: 15 fps
  critical, // >= 45°C: Tắt camera hoàn toàn, chuyển AMOLED tối giản
}

/// Trạng thái phiên ép tim CPR thời gian thực
class CprSessionState {
  final int totalCompressions;
  final int currentCompressionInCycle;
  final int totalCycles;
  final int elapsedSeconds;
  final int activeCompressionSeconds;
  final int pauseCount;
  final bool isRunning;
  final bool isContinuousMode; // True: Hands-only; False: 30:2
  final double estimatedDepthCm; // Mục tiêu: 5.0 - 6.0 cm (±1.0cm)
  final double elbowAngleDeg; // Mục tiêu: 165° - 180°
  final PostureQuality postureQuality;
  final double temperatureC;
  final int currentFps;
  final ThermalState thermalState;
  final bool isCameraPreviewActive;
  final double lastJitterMs;
  final String? lastVoiceWarning;
  final DateTime? lastVoiceWarningTime;

  const CprSessionState({
    this.totalCompressions = 0,
    this.currentCompressionInCycle = 0,
    this.totalCycles = 0,
    this.elapsedSeconds = 0,
    this.activeCompressionSeconds = 0,
    this.pauseCount = 0,
    this.isRunning = false,
    this.isContinuousMode = true,
    this.estimatedDepthCm = 5.4,
    this.elbowAngleDeg = 176.0,
    this.postureQuality = PostureQuality.optimal,
    this.temperatureC = 37.5,
    this.currentFps = 30,
    this.thermalState = ThermalState.nominal,
    this.isCameraPreviewActive = true,
    this.lastJitterMs = 1.2,
    this.lastVoiceWarning,
    this.lastVoiceWarningTime,
  });

  /// Tính chỉ số Phân số ép tim (Chest Compression Fraction - CCF)
  /// Theo chuẩn AHA: CCF = (Thời gian ép thực tế / Tổng thời gian) * 100%
  double get ccfPercentage {
    if (elapsedSeconds == 0) return 100.0;
    return ((activeCompressionSeconds / elapsedSeconds) * 100.0).clamp(0.0, 100.0);
  }

  /// Tiêu chuẩn AHA 2020/2025: CCF đạt từ 60% trở lên
  bool get isCcfCompliant => ccfPercentage >= 60.0;

  /// Tần số ép tim tức thời (Instantaneous BPM)
  double get instantBpm {
    if (elapsedSeconds == 0 || activeCompressionSeconds == 0) return 0.0;
    return (totalCompressions / (activeCompressionSeconds / 60.0)).clamp(0.0, 200.0);
  }

  CprSessionState copyWith({
    int? totalCompressions,
    int? currentCompressionInCycle,
    int? totalCycles,
    int? elapsedSeconds,
    int? activeCompressionSeconds,
    int? pauseCount,
    bool? isRunning,
    bool? isContinuousMode,
    double? estimatedDepthCm,
    double? elbowAngleDeg,
    PostureQuality? postureQuality,
    double? temperatureC,
    int? currentFps,
    ThermalState? thermalState,
    bool? isCameraPreviewActive,
    double? lastJitterMs,
    String? lastVoiceWarning,
    DateTime? lastVoiceWarningTime,
  }) {
    return CprSessionState(
      totalCompressions: totalCompressions ?? this.totalCompressions,
      currentCompressionInCycle: currentCompressionInCycle ?? this.currentCompressionInCycle,
      totalCycles: totalCycles ?? this.totalCycles,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      activeCompressionSeconds: activeCompressionSeconds ?? this.activeCompressionSeconds,
      pauseCount: pauseCount ?? this.pauseCount,
      isRunning: isRunning ?? this.isRunning,
      isContinuousMode: isContinuousMode ?? this.isContinuousMode,
      estimatedDepthCm: estimatedDepthCm ?? this.estimatedDepthCm,
      elbowAngleDeg: elbowAngleDeg ?? this.elbowAngleDeg,
      postureQuality: postureQuality ?? this.postureQuality,
      temperatureC: temperatureC ?? this.temperatureC,
      currentFps: currentFps ?? this.currentFps,
      thermalState: thermalState ?? this.thermalState,
      isCameraPreviewActive: isCameraPreviewActive ?? this.isCameraPreviewActive,
      lastJitterMs: lastJitterMs ?? this.lastJitterMs,
      lastVoiceWarning: lastVoiceWarning ?? this.lastVoiceWarning,
      lastVoiceWarningTime: lastVoiceWarningTime ?? this.lastVoiceWarningTime,
    );
  }

  /// Xuất gói tin Telemetry P2 gộp (Batch) gửi lên Outbox
  Map<String, dynamic> toTelemetryP2Map({required String clientUuid}) {
    return {
      'client_uuid': clientUuid,
      'timestamp': DateTime.now().toIso8601String(),
      'elapsed_s': elapsedSeconds,
      'active_s': activeCompressionSeconds,
      'total_compressions': totalCompressions,
      'ccf': double.parse(ccfPercentage.toStringAsFixed(1)),
      'inst_bpm': double.parse(instantBpm.toStringAsFixed(1)),
      'depth_cm': double.parse(estimatedDepthCm.toStringAsFixed(1)),
      'elbow_angle': double.parse(elbowAngleDeg.toStringAsFixed(1)),
      'posture_quality': postureQuality.name,
      'temp_c': double.parse(temperatureC.toStringAsFixed(1)),
      'fps': currentFps,
      'pause_count': pauseCount,
    };
  }

  String toTelemetryP2Json({required String clientUuid}) {
    return jsonEncode(toTelemetryP2Map(clientUuid: clientUuid));
  }
}
