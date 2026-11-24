import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';

class DeviceMemoryProfile {
  final int totalRamMb;
  final int availRamMb;
  final bool lowMemory;
  final int cpuCores;
  final String recommendedModel;

  const DeviceMemoryProfile({
    required this.totalRamMb,
    required this.availRamMb,
    required this.lowMemory,
    required this.cpuCores,
    required this.recommendedModel,
  });
}

class SpeechCapabilityProfile {
  final bool recognitionAvailable;
  final bool onDeviceRecognitionAvailable;
  final int sdkInt;

  const SpeechCapabilityProfile({
    required this.recognitionAvailable,
    required this.onDeviceRecognitionAvailable,
    required this.sdkInt,
  });
}

/// Cầu nối phần cứng Android thực thụ (Nhiệt độ pin, Bộ nhớ RAM, Wakelock giữ sáng màn hình, Trạng thái STT On-Device)
class DeviceHealthService {
  static const MethodChannel _channel = MethodChannel('vn.edu.vku.resq_aid/device_health');

  static bool get _isTestEnv => Platform.environment.containsKey('FLUTTER_TEST');

  static bool get _isMobileNative => Platform.isAndroid || Platform.isIOS;

  /// Giải mã ảnh JPEG/PNG/WebP/HEIC trực tiếp trên CPU RAM gốc (Android BitmapFactory / iOS CGContext)
  /// Trả về mảng RGB phẳng [targetSize * targetSize * 3] trong ~2ms, tránh 100% lỗi treo Impeller Vulkan ui.Image.toByteData!
  static Future<Uint8List?> decodeImageToRgb({
    required Uint8List bytes,
    int targetSize = 48,
    ui.Rect? cropRoi,
    double? viewAspect,
  }) async {
    if (_isTestEnv || !_isMobileNative) return null;
    try {
      final args = <String, dynamic>{
        'bytes': bytes,
        'targetSize': targetSize,
        if (viewAspect != null && viewAspect > 0.1) 'viewAspect': viewAspect,
        if (cropRoi != null) ...{
          'roiLeft': cropRoi.left,
          'roiTop': cropRoi.top,
          'roiRight': cropRoi.right,
          'roiBottom': cropRoi.bottom,
        },
      };
      final rgb = await _channel
          .invokeMethod<Uint8List>('decodeImageToRgb', args)
          .timeout(const Duration(milliseconds: 2500));
      if (rgb != null && rgb.length == targetSize * targetSize * 3) {
        return rgb;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Đọc nhiệt độ thiết bị (°C) từ Android BatteryManager / iOS ProcessInfo.thermalState
  static Future<double> getBatteryTemperatureC() async {
    if (_isTestEnv || !_isMobileNative) return 36.5;
    try {
      final temp = await _channel.invokeMethod<double>('getBatteryTemperature');
      return temp ?? 36.5;
    } catch (_) {
      return 36.5;
    }
  }

  /// Đọc dung lượng RAM vật lý để tự động định cỡ mô hình Local AI (0.5B vs 1.5B)
  static Future<DeviceMemoryProfile> getMemoryProfile() async {
    if (_isTestEnv || !_isMobileNative) {
      return const DeviceMemoryProfile(
        totalRamMb: 6144,
        availRamMb: 3200,
        lowMemory: false,
        cpuCores: 8,
        recommendedModel: 'Qwen2.5-1.5B-Instruct-Q4_K_M',
      );
    }
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>('getMemoryInfo');
      if (raw == null) throw StateError('Null memory map');
      return DeviceMemoryProfile(
        totalRamMb: (raw['totalRamMb'] as num?)?.toInt() ?? 4096,
        availRamMb: (raw['availRamMb'] as num?)?.toInt() ?? 2048,
        lowMemory: raw['lowMemory'] == true,
        cpuCores: (raw['cpuCores'] as num?)?.toInt() ?? 4,
        recommendedModel: raw['recommendedModel']?.toString() ?? 'Qwen2.5-0.5B-Instruct-Q4_K_M',
      );
    } catch (_) {
      return const DeviceMemoryProfile(
        totalRamMb: 4096,
        availRamMb: 2048,
        lowMemory: false,
        cpuCores: 4,
        recommendedModel: 'Qwen2.5-0.5B-Instruct-Q4_K_M',
      );
    }
  }

  /// Giữ màn hình luôn sáng khi đang ép tim CPR hoặc đo mạch PPG (Android Wakelock & iOS IdleTimer)
  static Future<void> setKeepScreenOn(bool enabled) async {
    if (_isTestEnv || !_isMobileNative) return;
    try {
      await _channel.invokeMethod<bool>('setKeepScreenOn', {'enabled': enabled});
    } catch (_) {}
  }

  /// Tăng độ sáng màn hình lên tối đa (1.0 = 100%) để làm đèn rọi xuyên mao mạch cho Camera Trước
  static Future<void> setScreenBrightness(double brightness) async {
    if (_isTestEnv || !_isMobileNative) return;
    try {
      await _channel.invokeMethod('setScreenBrightness', {'brightness': brightness});
    } catch (_) {}
  }

  /// Trả lại độ sáng màn hình mặc định theo cài đặt hệ thống của người dùng
  static Future<void> resetScreenBrightness() async {
    if (_isTestEnv || !_isMobileNative) return;
    try {
      await _channel.invokeMethod('resetScreenBrightness');
    } catch (_) {}
  }

  /// Kiểm tra khả năng nhận diện giọng nói On-Device của Android / iOS
  static Future<SpeechCapabilityProfile> getSpeechCapabilities() async {
    if (_isTestEnv || !_isMobileNative) {
      return const SpeechCapabilityProfile(
        recognitionAvailable: true,
        onDeviceRecognitionAvailable: true,
        sdkInt: 34,
      );
    }
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>('getSpeechCapabilities');
      return SpeechCapabilityProfile(
        recognitionAvailable: raw?['recognitionAvailable'] == true,
        onDeviceRecognitionAvailable: raw?['onDeviceRecognitionAvailable'] == true,
        sdkInt: (raw?['sdkInt'] as num?)?.toInt() ?? 33,
      );
    } catch (_) {
      return const SpeechCapabilityProfile(
        recognitionAvailable: false,
        onDeviceRecognitionAvailable: false,
        sdkInt: 30,
      );
    }
  }
}
