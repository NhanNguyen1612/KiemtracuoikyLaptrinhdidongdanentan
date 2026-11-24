import 'dart:async';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../cpr/presentation/cpr_coach_screen.dart';
import '../../../core/services/demo_mode_service.dart';
import '../../../core/services/device_health_service.dart';
import '../../../core/services/ppg_pipeline.dart';
import '../../../core/services/tts_service.dart';
import '../../../core/theme/app_theme.dart';

enum HeartRateMode {
  cameraPpg, // Đo quang học qua Camera & Flash (Photoplethysmography)
  touchPulse, // Bắt mạch thủ công: Chạm theo nhịp đập thật của mạch cảnh/quay
}

class HeartRateMonitorScreen extends ConsumerStatefulWidget {
  const HeartRateMonitorScreen({super.key});

  @override
  ConsumerState<HeartRateMonitorScreen> createState() => _HeartRateMonitorScreenState();
}

class _HeartRateMonitorScreenState extends ConsumerState<HeartRateMonitorScreen>
    with SingleTickerProviderStateMixin {
  HeartRateMode _mode = HeartRateMode.cameraPpg;
  bool _isMeasuring = false;
  bool _isCompleted = false;
  int _currentBpm = 0;
  double _progress = 0.0;
  int _remainingSeconds = 12;
  Timer? _measurementTimer;
  Timer? _waveformTimer;
  Timer? _thermalGuardTimer;
  final PpgPipeline _ppgPipeline = PpgPipeline(); // Pipeline DSP Butterworth Bandpass + SQI

  // Camera & PPG Variables
  CameraController? _cameraController;
  List<CameraDescription> _availableCameras = [];
  int _selectedCameraIndex = 0;
  double _minZoomLevel = 1.0;
  double _maxZoomLevel = 1.0;
  double _currentZoomLevel = 1.0;

  bool _isCameraReady = false;
  bool _isFlashOn = false;
  bool _isStreamingImages = false;
  bool _isExposureLocked = false;
  bool _fingerDetected = false;
  bool _highSensitivityMode = true; // Bật mặc định cho dòng Redmi Note 12 Pro 5G / Xiaomi có đèn Flash cách xa Camera chính
  int _consecutiveValidFrames = 0;
  int _consecutiveInvalidFrames = 0;
  String _cameraErrorMsg = '';
  int _validContactTicks = 0; // Đếm số tick (mỗi tick 100ms) có ngón tay che camera thật sự

  CameraDescription? get _currentCamera =>
      (_selectedCameraIndex >= 0 && _selectedCameraIndex < _availableCameras.length)
          ? _availableCameras[_selectedCameraIndex]
          : null;

  bool get _isFrontCamera => _currentCamera?.lensDirection == CameraLensDirection.front;
  double _dcR = 0.0;
  double _dcG = 0.0;
  double _dcY = 0.0;
  double _latestFilteredSample = 0.0;
  double _rollingWavePeak = 0.35;
  int _sampleY = 0;
  int _sampleV = 0;
  int _sampleU = 0;

  // Data samples for PPG & ECG Waveform
  final List<double> _waveformPoints = [];
  final List<DateTime> _beatTimestamps = [];
  double _phase = 0.0;

  late AnimationController _heartAnimController;
  late Animation<double> _heartScaleAnimation;
  String _emergencyPhone = DemoModeService.defaultDemoPhone;

  @override
  void initState() {
    super.initState();
    _heartAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    _heartScaleAnimation = Tween<double>(begin: 0.92, end: 1.15).animate(
      CurvedAnimation(parent: _heartAnimController, curve: Curves.easeInOut),
    );

    DeviceHealthService.setKeepScreenOn(true);
    _initCamera();
    _loadEmergencyPhone();
  }

  Future<void> _loadEmergencyPhone() async {
    final phone = await DemoModeService.getEmergencyPhone();
    if (mounted) setState(() => _emergencyPhone = phone);
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _cameraErrorMsg = 'Không tìm thấy camera phần cứng';
          _mode = HeartRateMode.touchPulse;
        });
        return;
      }

      _availableCameras = cameras;
      // ƯU TIÊN MẶC ĐỊNH CAMERA TRƯỚC (Theo yêu cầu đổi vị trí camera, tránh camera to ở trên cùng mặt lưng):
      final frontIdx = _availableCameras.indexWhere((c) => c.lensDirection == CameraLensDirection.front);
      if (frontIdx != -1) {
        _selectedCameraIndex = frontIdx;
      } else {
        _selectedCameraIndex = 0;
      }
      await _setupCameraController(_availableCameras[_selectedCameraIndex]);
    } catch (e) {
      debugPrint('[HeartRate] Camera init warning: $e');
      if (mounted) {
        setState(() {
          _cameraErrorMsg = 'Không thể mở camera (chuyển sang Bắt mạch chạm)';
          _mode = HeartRateMode.touchPulse;
        });
      }
    }
  }

  Future<void> _setupCameraController(CameraDescription camera) async {
    if (_cameraController != null) {
      try {
        if (_isFlashOn) {
          try {
            await _cameraController!.setFlashMode(FlashMode.off);
          } catch (_) {}
          _isFlashOn = false;
        }
        await _cameraController!.dispose();
      } catch (_) {}
    }

    _cameraController = CameraController(
      camera,
      ResolutionPreset.low,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    try {
      await _cameraController!.initialize();
      // Lấy nét và phơi sáng tự động để cảm biến thích ứng với ánh sáng mao mạch
      try {
        await _cameraController!.setFocusMode(FocusMode.auto);
      } catch (_) {}
      try {
        await _cameraController!.setExposureMode(ExposureMode.auto);
      } catch (_) {}

      try {
        _minZoomLevel = await _cameraController!.getMinZoomLevel();
        _maxZoomLevel = await _cameraController!.getMaxZoomLevel();
        _currentZoomLevel = 1.0.clamp(_minZoomLevel, _maxZoomLevel);
        await _cameraController!.setZoomLevel(_currentZoomLevel);
      } catch (_) {}

      if (mounted) {
        setState(() {
          _isCameraReady = true;
          _cameraErrorMsg = '';
        });
      }
    } catch (e) {
      debugPrint('[HeartRate] Setup camera error: $e');
      if (mounted) {
        setState(() {
          _cameraErrorMsg = 'Lỗi camera: $e';
        });
      }
    }
  }

  Future<void> _setOpticalZoom(double zoom) async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    try {
      if (zoom < 1.0 && _minZoomLevel >= 0.99) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Phần cứng Xiaomi khóa ống kính phụ, không hỗ trợ zoom dưới 1.0x! Khuyên dùng "Cam Trước" trên màn hình.'),
              duration: Duration(seconds: 4),
              backgroundColor: Color(0xFFD97706),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
      final target = zoom.clamp(_minZoomLevel, _maxZoomLevel);
      await _cameraController!.setZoomLevel(target);
      setState(() {
        _currentZoomLevel = target;
      });
      if (mounted) {
        final isWide = target < 0.99;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isWide
                ? 'Đã chuyển mức zoom ${target.toStringAsFixed(1)}x (Cảm biến Góc Rộng 8MP ở góc dưới)'
                : 'Đã chuyển mức zoom ${target.toStringAsFixed(1)}x (Cảm biến Chính 50MP ở trên cùng)'),
            duration: const Duration(seconds: 2),
            backgroundColor: const Color(0xFF0284C7),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('[HeartRate] Zoom error: $e');
    }
  }

  Future<void> _selectCameraLens(int index) async {
    if (index < 0 || index >= _availableCameras.length) return;
    if (_selectedCameraIndex == index && _cameraController != null && _cameraController!.value.isInitialized) {
      return;
    }
    final wasMeasuring = _isMeasuring;
    if (_isMeasuring) {
      _stopMeasurementInternal();
    }
    setState(() {
      _isCameraReady = false;
      _selectedCameraIndex = index;
    });
    await _setupCameraController(_availableCameras[_selectedCameraIndex]);
    if (wasMeasuring) {
      _startMeasurement();
    }
    if (mounted) {
      final lensName = _getCameraLensLabel(index);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã chọn $lensName'),
          duration: const Duration(seconds: 2),
          backgroundColor: const Color(0xFF0284C7),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _switchCameraLens() async {
    if (_availableCameras.length <= 1) return;
    final nextIdx = (_selectedCameraIndex + 1) % _availableCameras.length;
    await _selectCameraLens(nextIdx);
  }

  String _getCameraLensLabel(int index) {
    if (index >= 0 && index < _availableCameras.length) {
      final cam = _availableCameras[index];
      if (cam.lensDirection == CameraLensDirection.front) {
        return 'Camera Trước (Màn hình phát sáng • Khuyên Dùng ⭐)';
      }
      return 'Camera Sau (Ống kính to ở trên cùng mặt lưng)';
    }
    return 'Camera đo nhịp tim';
  }

  String _getCameraLensShortName(int index) {
    if (index >= 0 && index < _availableCameras.length) {
      final cam = _availableCameras[index];
      if (cam.lensDirection == CameraLensDirection.front) {
        return 'Cam Trước (Khuyên Dùng ⭐)';
      }
      return 'Cam Sau (Ống Kính To)';
    }
    return 'Cam ${index + 1}';
  }

  String _getCameraLensDescription(int index) {
    if (index >= 0 && index < _availableCameras.length) {
      final cam = _availableCameras[index];
      if (cam.lensDirection == CameraLensDirection.front) {
        return 'Màn hình tự phát sáng • Đo cực nhạy';
      }
      return 'Cảm biến 50MP to ở trên • Bật flash LED';
    }
    return 'Camera đo mao mạch';
  }

  @override
  void dispose() {
    DeviceHealthService.setKeepScreenOn(false);
    DeviceHealthService.resetScreenBrightness();
    _thermalGuardTimer?.cancel();
    _measurementTimer?.cancel();
    _waveformTimer?.cancel();
    _heartAnimController.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  void _stopMeasurementInternal() {
    DeviceHealthService.resetScreenBrightness();
    _thermalGuardTimer?.cancel();
    _measurementTimer?.cancel();
    _waveformTimer?.cancel();
    _heartAnimController.stop();

    if (_cameraController != null) {
      if (_isStreamingImages) {
        try {
          _cameraController!.stopImageStream();
        } catch (_) {}
        _isStreamingImages = false;
      }
      if (_isExposureLocked) {
        try {
          _cameraController!.setExposureMode(ExposureMode.auto);
        } catch (_) {}
        _isExposureLocked = false;
      }
      if (_isFlashOn) {
        try {
          _cameraController!.setFlashMode(FlashMode.off);
        } catch (_) {}
        _isFlashOn = false;
      }
    }

    if (mounted) {
      setState(() {
        _isMeasuring = false;
      });
    }
  }

  /// Bắt đầu chu kỳ đo nhịp tim (12 giây tiếp xúc thực tế, tối đa 60s bảo vệ nhiệt)
  void _startMeasurement() async {
    if (_isMeasuring) return;

    _ppgPipeline.reset();
    _thermalGuardTimer?.cancel();
    // BẢO VỆ NHIỆT (THERMAL GUARD): Giới hạn tối đa 60s bật đèn Flash để đủ thời gian đặt ngón tay chuẩn trên Redmi/Xiaomi
    _thermalGuardTimer = Timer(const Duration(seconds: 60), () {
      if (_isMeasuring && mounted) {
        _finishMeasurement();
      }
    });

    setState(() {
      _isMeasuring = true;
      _isCompleted = false;
      _progress = 0.0;
      _remainingSeconds = 12;
      _currentBpm = 0;
      _validContactTicks = 0;
      _consecutiveValidFrames = 0;
      _consecutiveInvalidFrames = 0;
      _dcR = 0.0;
      _dcG = 0.0;
      _dcY = 0.0;
      _latestFilteredSample = 0.0;
      _rollingWavePeak = 0.35;
      _waveformPoints.clear();
      _beatTimestamps.clear();
      _fingerDetected = _mode != HeartRateMode.cameraPpg;
    });

    _heartAnimController.repeat(reverse: true);

    // QUAN TRỌNG CHO REDMI NOTE 12 PRO 5G (MediaTek Dimensity 1080 Camera2 HAL):
    // Phải mở startImageStream() TRƯỚC để tạo xong CaptureSession YUV_420_888.
    // Nếu là Camera Sau: Bật FlashMode.torch sau 240ms.
    // Nếu là Camera Trước: Không bật đèn Flash lưng, màn hình sẽ tự động phát sáng trợ quang!
    if (_mode == HeartRateMode.cameraPpg && _cameraController != null && _isCameraReady) {
      try {
        try {
          await _cameraController!.setExposureMode(ExposureMode.auto);
          _isExposureLocked = false;
        } catch (_) {}
        _startCameraImageStream();
        await Future.delayed(const Duration(milliseconds: 240));
        if (_isFrontCamera) {
          // BẬT ĐỘ SÁNG 100% VÀ MÀN HÌNH NỀN TRẮNG RỰC RỠ ĐỂ LÀM ĐÈN CHIẾU MAO MẠCH
          try {
            await DeviceHealthService.setScreenBrightness(1.0);
          } catch (_) {}
        } else if (_isMeasuring && _cameraController != null) {
          try {
            await _cameraController!.setFlashMode(FlashMode.torch);
            _isFlashOn = true;
          } catch (_) {}
        }
        // Khẳng định lại Torch sau 450ms phòng trường hợp MediaTek Camera2 session đàm phán lại
        Future.delayed(const Duration(milliseconds: 450), () async {
          if (!_isFrontCamera && _isMeasuring && _cameraController != null && _cameraController!.value.isInitialized) {
            try {
              await _cameraController!.setFlashMode(FlashMode.torch);
              _isFlashOn = true;
            } catch (_) {}
          }
        });
      } catch (e) {
        debugPrint('[HeartRate] Flash torch / stream error: $e');
      }
    }

    // Timer cập nhật tiến trình: Cần đủ 120 ticks hợp lệ (120 x 100ms = 12.0 giây tiếp xúc thật)
    const targetTicks = 120;
    _measurementTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) return;

      // ĐIỀU KIỆN TIẾP XÚC QUANG HỌC HỢP LỆ:
      // Bắt buộc phải có ngón tay che camera thật sự!
      // Nếu vật thể không phải mao mạch người hoặc nhấc tay ra, tiến trình SẼ DỪNG LẠI NGAY LẬP TỨC.
      final hasValidFingerContact = (_mode != HeartRateMode.cameraPpg) || _fingerDetected;

      if (hasValidFingerContact) {
        _validContactTicks++;
        setState(() {
          _progress = (_validContactTicks / targetTicks).clamp(0.0, 1.0);
          _remainingSeconds = max(0, ((targetTicks - _validContactTicks) / 10).ceil());
        });

        if (_validContactTicks >= targetTicks) {
          _finishMeasurement();
        }
      }
    });

    // Timer vẽ biểu đồ sóng PPG / ECG thời gian thực
    _waveformTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!mounted) return;
      _updateWaveform();
    });

    if (_mode == HeartRateMode.cameraPpg) {
      if (_isFrontCamera) {
        TtsService.speak('Bắt đầu đo. Hãy đặt nhẹ đầu ngón tay che kín camera trước ở trên màn hình, giữ yên.');
      } else {
        TtsService.speak('Bắt đầu đo. Hãy đặt nhẹ đầu ngón tay che ống kính to ở trên cùng mặt lưng, giữ yên.');
      }
    } else {
      TtsService.speak('Bắt đầu đo nhịp tim. Hãy giữ yên tay và hít thở đều.');
    }
  }

  void _startCameraImageStream() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    if (_isStreamingImages) {
      try {
        _cameraController!.stopImageStream();
      } catch (_) {}
      _isStreamingImages = false;
    }

    try {
      _isStreamingImages = true;
      _cameraController!.startImageStream((CameraImage image) {
        if (!_isMeasuring) return;

        // Lấy mẫu đủ 30 khung hình/giây trên lưới 2D 16x16 (256 điểm ảnh) tuân thủ đúng rowStride & pixelStride
        // Sửa triệt để lỗi tráo kênh U/V trên định dạng NV21 (bytesPerPixel=2) của Redmi Note 12 Pro 5G!
        bool isFingerFrame = false;
        double avgR = 0.0;
        double avgG = 0.0;
        double avgLuma = 0.0;

        if (image.format.group == ImageFormatGroup.yuv420 && image.planes.length >= 3) {
          final w = image.width;
          final h = image.height;
          final yPlane = image.planes[0];
          final uPlane = image.planes[1];
          final vPlane = image.planes[2];

          final yBytes = yPlane.bytes;
          final uBytes = uPlane.bytes;
          final vBytes = vPlane.bytes;

          final yRowStride = yPlane.bytesPerRow;
          final uvRowStride = uPlane.bytesPerRow;
          final uvPixelStride = uPlane.bytesPerPixel ?? 1;

          const gridN = 16; // 16 x 16 = 256 mẫu giúp giảm nhiễu lượng tử hóa 16 lần (độ mịn < 0.02 mức xám!)
          final xStart = (w * 0.18).floor();
          final xEnd = (w * 0.82).floor();
          final yStart = (h * 0.18).floor();
          final yEnd = (h * 0.82).floor();
          final stepX = max(1, (xEnd - xStart) ~/ gridN);
          final stepY = max(1, (yEnd - yStart) ~/ gridN);

          double sumY = 0.0;
          double sumY2 = 0.0;
          double sumU = 0.0;
          double sumV = 0.0;
          double sumGradient = 0.0;
          int warmTissuePixels = 0;
          int count = 0;

          for (int gy = 0; gy < gridN; gy++) {
            final py = (yStart + gy * stepY).clamp(0, h - 1);
            final yRowOff = py * yRowStride;
            final uvRowOff = (py >> 1) * uvRowStride;

            for (int gx = 0; gx < gridN; gx++) {
              final px = (xStart + gx * stepX).clamp(0, w - 1);
              final yIdx = yRowOff + px;
              final uvIdx = uvRowOff + (px >> 1) * uvPixelStride;

              if (yIdx >= yBytes.length || uvIdx >= uBytes.length || uvIdx >= vBytes.length) {
                continue;
              }

              final yVal = yBytes[yIdx].toDouble();
              final uVal = uBytes[uvIdx].toDouble();
              final vVal = vBytes[uvIdx].toDouble();

              // Tính độ sắc nét cạnh cục bộ (Focus Gradient Check):
              // Khi ngón tay áp sát kính 0mm -> Defocus cực đại, không có chi tiết cạnh (grad <= 3.8)
              // Khi camera hướng vào khuôn mặt / mắt / mũi / phòng ở xa -> Được lấy nét rõ (grad >= 8.0 - 40.0)
              final pxRight = min(px + 2, w - 1);
              final pyDown = min(py + 2, h - 1);
              final yRightVal = yBytes[yRowOff + pxRight].toDouble();
              final yDownVal = yBytes[pyDown * yRowStride + px].toDouble();
              final localGrad = (yRightVal - yVal).abs() + (yDownVal - yVal).abs();
              sumGradient += localGrad;

              sumY += yVal;
              sumY2 += yVal * yVal;
              sumU += uVal;
              sumV += vVal;
              count++;

              // Điểm ảnh mô ngón tay xuyên sáng thực sự:
              // Ánh sáng đi xuyên qua mô người có tỷ lệ sắc đỏ (Cr/V) rất đậm và triệt tiêu sắc lam (Cb/U)
              // Mặt người ngoài phòng chỉ đạt V ~ 130-134 và V - U ~ 8-11.
              // Mao mạch ngón tay áp sát đèn luôn đạt V >= 137 và V - U >= 12!
              if (vVal >= 137 && (vVal - uVal) >= 12) {
                warmTissuePixels++;
              }
            }
          }

          if (count > 0) {
            final meanY = sumY / count;
            final meanU = sumU / count;
            final meanV = sumV / count;
            final varianceY = max(0.0, (sumY2 / count) - (meanY * meanY));
            final spatialStdY = sqrt(varianceY);
            final meanGrad = sumGradient / count;

            _sampleY = meanY.round();
            _sampleU = meanU.round();
            _sampleV = meanV.round();

            avgLuma = meanY;
            avgR = (meanY + 1.402 * (meanV - 128.0)).clamp(0.0, 255.0);
            avgG = (meanY - 0.344136 * (meanU - 128.0) - 0.714136 * (meanV - 128.0)).clamp(0.0, 255.0);
            final warmRatio = warmTissuePixels / count;

            // BỘ 4 TIÊU CHUẨN VẬT LÝ BẮT BUỘC ĐỂ XÁC NHẬN CHE KÍN CAMERA (CHỐNG NHẬN NHẦM KHUÔN MẶT / PHÒNG):
            // 1. Phổ đỏ Hemoglobin xuyên thấu: V >= 138 và (V - U) >= 14 (Khuôn mặt người chỉ đạt V ~ 132-134, V - U ~ 10-11)
            // 2. Độ mờ quang học 0mm (Macro Defocus): meanGrad <= 4.2 (Khuôn mặt có mắt, mũi, tóc, mũ có meanGrad >= 8.0 - 35.0)
            // 3. Che kín toàn bộ ống kính: warmRatio >= 0.80 (80% cảm biến phải là mô đỏ, loại bỏ ảnh thấy mặt + phòng)
            // 4. Độ đồng nhất bề mặt mô mềm: spatialStdY <= 26.0 (Khuôn mặt có bóng mắt mũi tóc làm spatialStdY > 30)
            final bool isLuminanceValid = meanY >= 10.0 && meanY <= 250.0;
            final bool isHemoglobinWarm = meanV >= 138.0 && (meanV - meanU) >= 14.0;
            final bool isDefocusedMacro = meanGrad <= 4.2;
            final bool isSmoothTissue = spatialStdY <= 26.0;
            final bool isFullyCovered = warmRatio >= 0.80;

            isFingerFrame = isLuminanceValid &&
                isHemoglobinWarm &&
                isDefocusedMacro &&
                isSmoothTissue &&
                isFullyCovered;
          }
        } else {
          // Định dạng BGRA8888 (iOS)
          final bytes = image.planes.first.bytes;
          double sumR = 0, sumG = 0, sumB = 0, sumR2 = 0;
          const sampleCount = 196;
          final step = max(1, (bytes.length ~/ 4) ~/ sampleCount) * 4;

          int count = 0;
          for (int i = 0; i < bytes.length - 3 && count < sampleCount; i += step) {
            final b = bytes[i].toDouble();
            final g = bytes[i + 1].toDouble();
            final r = bytes[i + 2].toDouble();
            sumR += r;
            sumG += g;
            sumB += b;
            sumR2 += r * r;
            count++;
          }

          if (count > 0) {
            avgR = sumR / count;
            avgG = sumG / count;
            final avgB = sumB / count;
            avgLuma = 0.299 * avgR + 0.587 * avgG + 0.114 * avgB;
            final stdR = sqrt(max(0.0, (sumR2 / count) - (avgR * avgR)));
            _sampleY = avgLuma.round();
            _sampleV = (128 + 0.5 * (avgR - avgG)).round();
            _sampleU = (128 + 0.5 * (avgB - avgLuma)).round();
            isFingerFrame = avgLuma >= 10.0 &&
                stdR <= 34.0 &&
                avgR >= avgG * 1.12 &&
                avgR >= avgB * 1.18;
          }
        }

        // BỘ LỌC CHỐNG NHẤP NHÁY + TỰ ĐỘNG KHÓA PHƠI SÁNG (AE LOCK) KHI NGÓN TAY ĐÃ ỔN ĐỊNH:
        if (isFingerFrame) {
          _consecutiveValidFrames++;
          _consecutiveInvalidFrames = 0;
          if (_consecutiveValidFrames >= 4 && !_fingerDetected && mounted) {
            setState(() => _fingerDetected = true);
          }
          // Sau 16 khung hình (~0.5s) khi độ sáng ngón tay đã ổn định -> Khóa AE & AF để Camera2 không tự bù sáng triệt tiêu sóng mạch!
          if (_consecutiveValidFrames == 16 && !_isExposureLocked && _cameraController != null) {
            _isExposureLocked = true;
            try {
              _cameraController!.setExposureMode(ExposureMode.locked);
            } catch (_) {}
            try {
              _cameraController!.setFocusMode(ExposureMode.locked == ExposureMode.locked ? FocusMode.locked : FocusMode.auto);
            } catch (_) {}
          }
        } else {
          _consecutiveInvalidFrames++;
          _consecutiveValidFrames = 0;
          if (_consecutiveInvalidFrames >= 8 && _fingerDetected && mounted) {
            if (_isExposureLocked && _cameraController != null) {
              _isExposureLocked = false;
              try {
                _cameraController!.setExposureMode(ExposureMode.auto);
              } catch (_) {}
            }
            setState(() {
              _fingerDetected = false;
              _currentBpm = 0;
              _latestFilteredSample = 0.0;
            });
            _dcR = 0.0;
            _dcG = 0.0;
            _dcY = 0.0;
            _ppgPipeline.reset();
          }
        }

        // TRÍCH XUẤT XUNG MẠCH ĐA KÊNH CHỐNG BÃO HÒA (SONY IMX766 / REDMI NOTE 12 PRO 5G):
        // - Nếu kênh Đỏ chưa bão hòa (< 242): Kết hợp vi sai Sắc độ (Chrominance R - 0.55*G) triệt tiêu rung tay
        // - Nếu kênh Đỏ kịch trần (>= 242 do cảm biến IMX766 lớn + đèn Flash sáng): Tự chuyển sang kênh hấp thụ Xanh lá (-G) & Độ sáng (-Y)!
        if (_fingerDetected) {
          if (_dcR == 0.0) {
            _dcR = avgR;
            _dcG = avgG;
            _dcY = avgLuma;
          } else {
            _dcR += 0.05 * (avgR - _dcR);
            _dcG += 0.05 * (avgG - _dcG);
            _dcY += 0.05 * (avgLuma - _dcY);
          }

          final double acDelta;
          if (avgR >= 242.0 && avgG < 238.0) {
            // Kênh Đỏ bão hòa 255 -> Dùng hấp thụ Hemoglobin trên kênh Xanh lá (-G) & Luma (-Y)
            acDelta = -((avgG - _dcG) * 0.75 + (avgLuma - _dcY) * 0.25);
          } else {
            // Vi sai Chrominance chuẩn y sinh (khử nhiễu chuyển động đồng pha và tăng tỷ số tín hiệu/nhiễu)
            acDelta = (avgR - _dcR) - 0.50 * (avgG - _dcG);
          }

          // Khuếch đại vi sai thích ứng: Cam trước (ánh sáng khuếch tán từ màn hình) cần độ nhạy cao hơn (13.5x - 16.0x) so với Cam sau dùng đèn Flash (6.0x - 8.5x)
          final double gain = _isFrontCamera
              ? (_highSensitivityMode ? 16.0 : 13.5)
              : (_highSensitivityMode ? 8.5 : 6.0);
          final amplifiedSignal = (128.0 + acDelta * gain).clamp(20.0, 240.0);

          final pipelineResult = _ppgPipeline.processFrame(amplifiedSignal);
          _latestFilteredSample = pipelineResult.filteredSample;
          if (pipelineResult.acAmplitude > 0.04) {
            _rollingWavePeak = 0.85 * _rollingWavePeak + 0.15 * (pipelineResult.acAmplitude * 0.55);
          }
          if (pipelineResult.isValid && mounted) {
            setState(() {
              _currentBpm = pipelineResult.bpm!;
            });
          }
        }
      });
    } catch (e) {
      debugPrint('[HeartRate] Image stream fallback: $e');
    }
  }

  /// Ghi nhận 1 nhịp đập khi người dùng chạm ở chế độ Bắt Mạch Chạm (Tap)
  void _recordHeartbeatPulse() {
    final now = DateTime.now();
    if (_beatTimestamps.isNotEmpty) {
      final diffMs = now.difference(_beatTimestamps.last).inMilliseconds;
      if (diffMs < 350) return; // Khử nhiễu nhịp giả (>170 BPM)
    }

    _beatTimestamps.add(now);

    // Tính BPM tức thời: Bắt đầu tính ngay từ 2 nhịp trở lên để người dùng thấy số nhịp hiển thị sớm!
    if (_beatTimestamps.length >= 2) {
      final recentIntervals = <int>[];
      for (int i = max(1, _beatTimestamps.length - 5); i < _beatTimestamps.length; i++) {
        final interval = _beatTimestamps[i].difference(_beatTimestamps[i - 1]).inMilliseconds;
        if (interval >= 370 && interval <= 1400) {
          recentIntervals.add(interval);
        }
      }
      if (recentIntervals.isNotEmpty) {
        final avgInterval = recentIntervals.reduce((a, b) => a + b) / recentIntervals.length;
        if (avgInterval > 0) {
          final calculatedBpm = (60000 / avgInterval).round().clamp(48, 155);
          if (mounted) {
            setState(() {
              _currentBpm = calculatedBpm;
            });
          }
        }
      }
    }
  }

  /// Chế độ Bắt Mạch Thủ Công: Người dùng chạm theo từng nhịp đập thật
  void _handleManualTapPulse() {
    if (!_isMeasuring) {
      _startMeasurement();
    }
    _recordHeartbeatPulse();
    // Tạo sóng nhô cao khi chạm
    setState(() {
      _phase += 1.5;
    });
  }

  void _updateWaveform() {
    setState(() {
      _phase += 0.22;
      double y;
      if (_mode == HeartRateMode.cameraPpg && _fingerDetected) {
        // Vẽ trực tiếp sóng xung mạch quang học thực tế sau bộ lọc thông dải Butterworth
        final normAmp = max(0.18, _rollingWavePeak);
        y = (-_latestFilteredSample / normAmp).clamp(-1.0, 1.0);
      } else if (_mode == HeartRateMode.touchPulse && _currentBpm > 0) {
        final sinVal = sin(_phase);
        if (sinVal > 0.85) {
          y = -1.0;
        } else if (sinVal > 0.6) {
          y = 0.4;
        } else {
          y = sinVal * 0.35 + (sin(_phase * 2) * 0.15);
        }
      } else {
        y = (Random().nextDouble() - 0.5) * 0.05;
      }

      _waveformPoints.add(y);
      if (_waveformPoints.length > 80) {
        _waveformPoints.removeAt(0);
      }
    });
  }

  void _finishMeasurement() async {
    DeviceHealthService.resetScreenBrightness();
    _thermalGuardTimer?.cancel();
    _measurementTimer?.cancel();
    _waveformTimer?.cancel();
    _heartAnimController.stop();

    if (_cameraController != null) {
      if (_isStreamingImages) {
        try {
          await _cameraController!.stopImageStream();
        } catch (_) {}
        _isStreamingImages = false;
      }
      if (_isExposureLocked) {
        try {
          await _cameraController!.setExposureMode(ExposureMode.auto);
        } catch (_) {}
        _isExposureLocked = false;
      }
      if (_isFlashOn) {
        try {
          await _cameraController!.setFlashMode(FlashMode.off);
        } catch (_) {}
        _isFlashOn = false;
      }
    }

    int finalBpm = _currentBpm;
    // ĐÁNH GIÁ KẾT QUẢ ĐO CHUẨN XÁC:
    if (_mode == HeartRateMode.cameraPpg) {
      if (_currentBpm > 0) {
        finalBpm = _currentBpm;
      } else if (_ppgPipeline.lastValidBpm != null && _ppgPipeline.lastValidBpm! > 0) {
        // Sử dụng nhịp tim ổn định hợp lệ đã ghi nhận được trong suốt tiến trình đo
        finalBpm = _ppgPipeline.lastValidBpm!;
      } else {
        // KHÔNG TỰ ĐOÁN HAY ĐO LÁO: Nếu không bắt được nhịp tim thật sự, trả về 0 BPM để cảnh báo
        finalBpm = 0;
      }
    } else if (_mode == HeartRateMode.touchPulse) {
      if (_beatTimestamps.length < 2) {
        finalBpm = 0;
      }
    }

    setState(() {
      _isMeasuring = false;
      _isCompleted = true;
      _currentBpm = finalBpm;
      _progress = 1.0;
    });

    // Thông báo bằng giọng nói y tế an toàn (không suy diễn chẩn đoán)
    if (finalBpm == 0) {
      TtsService.speak('Không thu được tín hiệu mạch rõ ràng. Hãy kiểm tra tri giác nạn nhân và giữ yên tay.');
    } else if (finalBpm < 60) {
      TtsService.speak('Ghi nhận khoảng $finalBpm nhịp một phút, nhịp chậm, chỉ mang tính chất tham khảo.');
    } else if (finalBpm > 100) {
      TtsService.speak('Ghi nhận khoảng $finalBpm nhịp một phút, nhịp nhanh, chỉ mang tính chất tham khảo.');
    } else {
      TtsService.speak('Ghi nhận khoảng $finalBpm nhịp một phút, chỉ mang tính chất tham khảo.');
    }
  }

  Future<void> _callEmergency(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNoPulse = _isCompleted && _currentBpm == 0;
    final isTachycardia = _currentBpm > 100;
    final isBradycardia = _currentBpm > 0 && _currentBpm < 60;
    final isNormal = _currentBpm >= 60 && _currentBpm <= 100;

    Color statusColor;
    String statusTitle;
    String statusDetail;

    if (!_isCompleted && !_isMeasuring) {
      statusColor = const Color(0xFF38BDF8);
      statusTitle = 'SẴN SÀNG THEO DÕI NHỊP MẠCH';
      statusDetail = _mode == HeartRateMode.cameraPpg
          ? 'Đặt nhẹ đầu ngón tay che camera sau và đèn flash. Giữ tay yên.'
          : 'Bắt mạch cổ hoặc cổ tay người bệnh, chạm vào nút hình trái tim theo từng nhịp đập';
    } else if (_isMeasuring) {
      if (_mode == HeartRateMode.cameraPpg && !_fingerDetected) {
        statusColor = const Color(0xFFEF4444);
        statusTitle = _isFrontCamera
            ? '🔴 CHƯA CHE CAMERA TRƯỚC (ĐANG THẤY MẶT / PHÒNG)'
            : '🔴 CHƯA ĐẶT NGÓN TAY CHE CAMERA & FLASH';
        statusDetail = _isFrontCamera
            ? 'Tiến trình tạm dừng! Hãy áp nhẹ đầu ngón tay che kín lỗ camera trước trên màn hình.'
            : 'Tiến trình đang tạm dừng. Hãy che camera sau và flash bằng đầu ngón tay.';
      } else {
        statusColor = const Color(0xFF38BDF8);
        statusTitle = 'ĐANG ĐO NHỊP TIM (${_remainingSeconds}s)...';
        statusDetail = 'Tín hiệu mao mạch tốt. Giữ yên ngón tay và hít thở đều...';
      }
    } else if (isNoPulse) {
      statusColor = const Color(0xFFEF4444);
      statusTitle = 'TÍN HIỆU KHÔNG ỔN ĐỊNH / CHƯA GHI NHẬN MẠCH';
      statusDetail = 'Không phát hiện xung mạch rõ ràng (có thể do ngón tay lạnh, co mạch hoặc che lệch). Nếu nạn nhân BẤT TỈNH & KHÔNG THỞ, hãy gọi 115 và ép tim CPR ngay!';
    } else if (isTachycardia) {
      statusColor = Colors.orangeAccent;
      statusTitle = 'GHI NHẬN: $_currentBpm NHỊP/PHÚT (NHANH > 100)';
      statusDetail = 'Chỉ số mang tính tham khảo khi nghỉ ngơi. Nhịp nhanh có thể do vận động, đau đớn, hoảng loạn hoặc sốt. Hãy cho người bệnh nghỉ ngơi và theo dõi triệu chứng.';
    } else if (isBradycardia) {
      statusColor = Colors.amber;
      statusTitle = 'GHI NHẬN: $_currentBpm NHỊP/PHÚT (CHẬM < 60)';
      statusDetail = 'Chỉ số mang tính tham khảo. Theo dõi sát tri giác và nhịp thở của người bệnh. Nếu kèm hoa mắt, chóng mặt, ngất xỉu hãy đưa đến cơ sở y tế.';
    } else {
      statusColor = const Color(0xFF4ADE80);
      statusTitle = 'GHI NHẬN: ~$_currentBpm NHỊP/PHÚT (THAM KHẢO)';
      statusDetail = 'Nằm trong khoảng tham khảo sinh lý người trưởng thành khi nghỉ ngơi (60 - 100 nhịp/phút). Không dùng thay thế thiết bị y tế chuyên dụng.';
    }

    final bool isWhiteTorchMode = _isFrontCamera && _isMeasuring && _mode == HeartRateMode.cameraPpg;

    return Scaffold(
      backgroundColor: isWhiteTorchMode ? Colors.white : const Color(0xFF0A0F1D),
      appBar: AppBar(
        title: Text(
          isWhiteTorchMode ? '💡 ĐÈN MÀN HÌNH ĐANG CHIẾU MAO MẠCH' : 'THEO DÕI NHỊP MẠCH THAM KHẢO',
          style: TextStyle(
            fontFamily: 'Roboto',
            fontWeight: FontWeight.w800,
            fontSize: isWhiteTorchMode ? 13.0 : 14.5,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: isWhiteTorchMode ? Colors.white : const Color(0xFF131D31),
        foregroundColor: isWhiteTorchMode ? const Color(0xFF0F172A) : Colors.white,
        elevation: isWhiteTorchMode ? 2 : 0,
        actions: [
          IconButton(
            tooltip: 'Gọi cấp cứu 115',
            icon: const Icon(Icons.phone_in_talk_rounded, color: Color(0xFFEF4444)),
            onPressed: () => _callEmergency(_emergencyPhone),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isWhiteTorchMode) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF38BDF8), width: 2),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x6638BDF8),
                      blurRadius: 28,
                      spreadRadius: 8,
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.wb_sunny_rounded, color: Color(0xFFF59E0B), size: 30),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ĐÈN NỀN TRẮNG ĐANG BẬT (100% SÁNG TỐI ĐA)',
                            style: TextStyle(
                              color: Color(0xFF0F172A),
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Toàn bộ màn hình đang phát quang cực đại để chiếu xuyên mao mạch ngón tay của bạn.\nHãy áp nhẹ đầu ngón tay che kín lỗ Camera Trước!',
                            style: TextStyle(
                              color: Color(0xFF334155),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // CẢNH BÁO LÂM SÀNG AHA/ILCOR 2025 BLS (ĐƯỜNG A):
            // Nạn nhân không đáp ứng và không thở bình thường -> KHÔNG đo gì cả, chuyển thẳng sang CPR
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF450A0A),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFEF4444), width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 22),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'CẢNH BÁO Y TẾ KHẨN CẤP (AHA / BLS)',
                          style: TextStyle(color: Color(0xFFFCA5A5), fontWeight: FontWeight.w900, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Nếu nạn nhân BẤT TỈNH, KHÔNG THỞ hoặc THỞ NGÁP: KHÔNG ĐO NHỊP TIM! Hãy gọi 115 và bắt đầu ép tim CPR ngay lập tức!',
                    style: TextStyle(color: Colors.white, fontSize: 11.5, height: 1.4, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        _stopMeasurementInternal();
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const CPRCoachScreen()),
                        );
                      },
                      icon: const Icon(Icons.favorite_rounded, size: 16),
                      label: const Text(
                        'CHUYỂN SANG ÉP TIM CPR NGAY',
                        style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w900, fontSize: 11.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // CHỌN CHẾ ĐỘ ĐO
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF131D31),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF24324D)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildModeTab(
                      label: 'Camera PPG',
                      icon: Icons.camera_alt_rounded,
                      isActive: _mode == HeartRateMode.cameraPpg,
                      onTap: () {
                        if (_isMeasuring) return;
                        setState(() => _mode = HeartRateMode.cameraPpg);
                      },
                    ),
                  ),
                  Expanded(
                    child: _buildModeTab(
                      label: 'Bắt Mạch Chạm',
                      icon: Icons.touch_app_rounded,
                      isActive: _mode == HeartRateMode.touchPulse,
                      onTap: () {
                        if (_isMeasuring) return;
                        setState(() => _mode = HeartRateMode.touchPulse);
                      },
                    ),
                  ),
                ],
              ),
            ),

            if (_cameraErrorMsg.isNotEmpty && _mode == HeartRateMode.touchPulse)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '💡 $_cameraErrorMsg',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.amberAccent, fontSize: 11),
                ),
              ),

            if (_mode == HeartRateMode.cameraPpg) ...[
              // Nút Chế độ Nhạy Cao (Dành riêng cho máy có đèn flash nằm xa camera như Xiaomi / Redmi)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF131D31),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _highSensitivityMode ? const Color(0xFF38BDF8) : const Color(0xFF24324D),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.bolt_rounded,
                      color: _highSensitivityMode ? const Color(0xFF38BDF8) : const Color(0xFF94A3B8),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _highSensitivityMode
                                ? '⚡ Chế độ Nhạy Cao ĐANG BẬT (Đo siêu nhạy)'
                                : 'Chế độ Nhạy Cao (Cho điện thoại đèn flash xa):',
                            style: TextStyle(
                              color: _highSensitivityMode ? const Color(0xFF38BDF8) : const Color(0xFF94A3B8),
                              fontSize: 11,
                              fontWeight: _highSensitivityMode ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          Text(
                            _sampleY > 0
                                ? 'Cảm biến quang: Y=$_sampleY | V=$_sampleV | U=$_sampleU'
                                : 'Tự động nhận diện mao mạch và đo liên tục, không bị kẹt dừng',
                            style: const TextStyle(color: Colors.white54, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _highSensitivityMode,
                      activeTrackColor: const Color(0xFF0284C7),
                      onChanged: (val) {
                        setState(() => _highSensitivityMode = val);
                      },
                    ),
                  ],
                ),
              ),

              // BỘ CHỌN VỊ TRÍ CAMERA ĐO NHỊP TIM (Camera Trước trên màn hình vs Camera Sau lưng máy)
              if (_availableCameras.isNotEmpty) ...[
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF131D31),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF38BDF8).withOpacity(0.5),
                      width: 1.2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.tune_rounded, color: Color(0xFF38BDF8), size: 16),
                          const SizedBox(width: 6),
                          const Text(
                            'CHỌN VỊ TRÍ CAMERA ĐO NHỊP TIM:',
                            style: TextStyle(
                              color: Color(0xFF38BDF8),
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0284C7).withOpacity(0.3),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${_availableCameras.length} Vị trí',
                              style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: List.generate(_availableCameras.length, (idx) {
                          final isSelected = _selectedCameraIndex == idx;
                          final isFront = _availableCameras[idx].lensDirection == CameraLensDirection.front;
                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                right: idx < _availableCameras.length - 1 ? 6 : 0,
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => _selectCameraLens(idx),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(0xFF0284C7).withOpacity(0.4)
                                          : const Color(0xFF1E293B),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isSelected
                                            ? const Color(0xFF38BDF8)
                                            : (isFront ? const Color(0xFFF59E0B) : const Color(0xFF334155)),
                                        width: isSelected ? 2.0 : 1.0,
                                      ),
                                      boxShadow: isSelected
                                          ? [
                                              BoxShadow(
                                                color: const Color(0xFF0284C7).withOpacity(0.4),
                                                blurRadius: 8,
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Column(
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              isSelected
                                                  ? Icons.check_circle_rounded
                                                  : (isFront ? Icons.camera_front_rounded : Icons.camera_rear_rounded),
                                              color: isSelected
                                                  ? const Color(0xFF38BDF8)
                                                  : (isFront ? const Color(0xFFF59E0B) : Colors.white60),
                                              size: 13,
                                            ),
                                            const SizedBox(width: 4),
                                            Flexible(
                                              child: Text(
                                                _getCameraLensShortName(idx),
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: isSelected ? Colors.white : (isFront ? const Color(0xFFFDE68A) : Colors.white70),
                                                  fontSize: 10.5,
                                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          _getCameraLensDescription(idx),
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: isSelected ? const Color(0xFF38BDF8) : Colors.white38,
                                            fontSize: 9,
                                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                      if (!_isFrontCamera) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF334155)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.tune_rounded, size: 13, color: Color(0xFF38BDF8)),
                                  SizedBox(width: 4),
                                  Text(
                                    'ĐỔI ỐNG KÍNH VẬT LÝ MẶT LƯNG (ZOOM QUANG):',
                                    style: TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              if (_minZoomLevel < 0.95) ...[
                                Row(
                                  children: [
                                    Expanded(
                                      child: InkWell(
                                        onTap: () => _setOpticalZoom(1.0),
                                        borderRadius: BorderRadius.circular(6),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                                          decoration: BoxDecoration(
                                            color: _currentZoomLevel >= 0.95
                                                ? const Color(0xFF0284C7).withOpacity(0.35)
                                                : const Color(0xFF1E293B),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: _currentZoomLevel >= 0.95
                                                  ? const Color(0xFF38BDF8)
                                                  : const Color(0xFF334155),
                                              width: _currentZoomLevel >= 0.95 ? 1.5 : 1.0,
                                            ),
                                          ),
                                          child: Column(
                                            children: [
                                              Text(
                                                '1.0x • Cam Chính 50MP',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  color: _currentZoomLevel >= 0.95 ? Colors.white : Colors.white70,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Text(
                                                'Mắt to trên cùng',
                                                style: TextStyle(
                                                  color: _currentZoomLevel >= 0.95 ? const Color(0xFF38BDF8) : Colors.white38,
                                                  fontSize: 8.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: InkWell(
                                        onTap: () => _setOpticalZoom(0.8),
                                        borderRadius: BorderRadius.circular(6),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                                          decoration: BoxDecoration(
                                            color: _currentZoomLevel < 0.95
                                                ? const Color(0xFF0284C7).withOpacity(0.35)
                                                : const Color(0xFF1E293B),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: _currentZoomLevel < 0.95
                                                  ? const Color(0xFF38BDF8)
                                                  : const Color(0xFF334155),
                                              width: _currentZoomLevel < 0.95 ? 1.5 : 1.0,
                                            ),
                                          ),
                                          child: Column(
                                            children: [
                                              Text(
                                                '0.8x • Cam Thu Nhỏ',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  color: _currentZoomLevel < 0.95 ? Colors.white : Colors.white70,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Text(
                                                'Góc rộng 8MP (Mắt dưới)',
                                                style: TextStyle(
                                                  color: _currentZoomLevel < 0.95 ? const Color(0xFF38BDF8) : Colors.white38,
                                                  fontSize: 8.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ] else ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E293B),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.35)),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.lock_outline_rounded, color: Color(0xFFF59E0B), size: 16),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Hệ điều hành Xiaomi khóa hoàn toàn các cảm biến phụ (Góc rộng & Macro) đối với app ngoài, chỉ mở duy nhất cảm biến chính 1.0x.\n👉 Hãy bấm chọn "Cam Trước (⭐ Khuyên dùng)" ở trên: Màn hình sẽ tự động phát sáng trắng 100% cực đại để rọi mao mạch đo siêu nhạy!',
                                          style: TextStyle(
                                            color: Colors.amber.shade200,
                                            fontSize: 10,
                                            height: 1.35,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              // Card hướng dẫn đặt ngón tay trực quan
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded, color: Color(0xFF38BDF8), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'BẠN ĐANG DÙNG: ${_getCameraLensLabel(_selectedCameraIndex).toUpperCase()}',
                            style: const TextStyle(
                              color: Color(0xFF38BDF8),
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isFrontCamera
                                ? '• ĐÃ CHỌN "CAMERA TRƯỚC (Trên màn hình)" — VỊ TRÍ ĐO TỐI ƯU NHẤT CHO REDMI NOTE 12 PRO 5G!\n• Đặt nhẹ đầu ngón tay (ngón trỏ hoặc ngón cái) che kín lỗ Camera Trước ở mép trên màn hình.\n• Màn hình tự động chiếu sáng mao mạch ngón tay, không lo đèn Flash sau lưng bị cách xa!\n• Kính ngắm tròn bên dưới hiển thị 100% hình ảnh thực của ngón tay bạn.'
                                : (_currentZoomLevel < 0.95
                                    ? '• ĐÃ CHỌN "CAM THU NHỎ ${_currentZoomLevel.toStringAsFixed(1)}x (Cảm biến góc rộng)":\n• Hãy đặt nhẹ đầu ngón tay che kín ỐNG KÍNH Ở GÓC DƯỚI BÊN TRÁI mặt lưng máy.\n• Cảm biến thu nhỏ đang trực tiếp thu nhận hình ảnh quang học mao mạch ngón tay bạn để tính nhịp tim!\n• Giữ yên ngón tay trong suốt 12 giây tiếp xúc.'
                                    : '• ĐÃ CHỌN "CAM CHÍNH 50MP (1.0x)":\n• Hãy đặt nhẹ đầu ngón tay che kín ỐNG KÍNH TO Ở TRÊN CÙNG mặt lưng máy.\n• Do đèn Flash nằm cách ống kính chính ~2.8cm, bạn có thể hướng tay về nơi có ánh sáng phòng hoặc bấm nút "0.8x • Cam Thu Nhỏ" ở trên để đo bằng ống kính phía dưới!'),
                            style: const TextStyle(
                              color: Color(0xFFE2E8F0),
                              fontSize: 11,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            // MÀN HÌNH THEO DÕI SÓNG ĐIỆN TIM / PPG WAVEFORM (ICU MONITOR STYLE)
            Container(
              height: 160,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: statusColor.withOpacity(0.6), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: statusColor.withOpacity(0.15),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Lưới tọa độ y tế ECG Grid
                  Positioned.fill(
                    child: CustomPaint(
                      painter: EcgGridPainter(),
                    ),
                  ),
                  // Đường sóng nhấp nhô thời gian thực
                  Positioned.fill(
                    child: CustomPaint(
                      painter: PpgWaveformPainter(
                        points: _waveformPoints,
                        color: statusColor,
                      ),
                    ),
                  ),
                  // Header thông số Monitor
                  Positioned(
                    top: 10,
                    left: 12,
                    right: 12,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _isMeasuring ? Colors.greenAccent : Colors.grey,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _mode == HeartRateMode.cameraPpg
                                  ? 'PPG OPTICAL SENSOR'
                                  : 'MANUAL PULSE TAP',
                              style: const TextStyle(
                                fontFamily: 'Roboto',
                                color: Color(0xFF38BDF8),
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          _currentBpm > 0 ? '$_currentBpm BPM' : '-- BPM',
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            color: statusColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Thông báo góc dưới nếu chưa phát hiện ngón tay hoặc đang đo
                  if (_mode == HeartRateMode.cameraPpg && _isMeasuring)
                    Positioned(
                      bottom: 8,
                      left: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _fingerDetected
                              ? const Color(0xFF16A34A).withOpacity(0.9)
                              : const Color(0xFFDC2626).withOpacity(0.95),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: (_fingerDetected ? Colors.green : Colors.red).withOpacity(0.4),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _fingerDetected ? Icons.check_circle_rounded : Icons.pan_tool_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                _fingerDetected
                                    ? '🟢 ĐÃ NHẬN DIỆN MAO MẠCH - ĐANG LẤY MẪU (${_remainingSeconds}s)'
                                    : '🔴 CHƯA ĐẶT NGÓN TAY CHE CAMERA - ĐANG TẠM DỪNG',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontFamily: 'Roboto',
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // KHỐI ĐỒ HỌA TRÁI TIM & CHỈ SỐ NHỊP TIM TRUNG TÂM
            GestureDetector(
              onTap: _mode == HeartRateMode.touchPulse ? _handleManualTapPulse : null,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF131D31),
                      const Color(0xFF0F172A),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF24324D)),
                ),
                child: Column(
                  children: [
                    // NÚT CHUYỂN NHANH CAMERA TRƯỚC / SAU
                    if (_mode == HeartRateMode.cameraPpg && _availableCameras.length > 1)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          onTap: _switchCameraLens,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0284C7).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFF38BDF8), width: 1.2),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.cameraswitch_rounded, size: 16, color: Color(0xFF38BDF8)),
                                const SizedBox(width: 6),
                                Text(
                                  _isFrontCamera
                                      ? 'Đổi sang Camera Sau (Ống Kính To Mặt Lưng)'
                                      : '⭐ Khuyên Dùng: Đổi sang Camera Trước (Màn Hình)',
                                  style: const TextStyle(
                                    color: Color(0xFF38BDF8),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                    // Icon trái tim co bóp theo nhịp & Kính ngắm quang học Camera trực quan
                    ScaleTransition(
                      scale: _isMeasuring ? _heartScaleAnimation : const AlwaysStoppedAnimation(1.0),
                      child: Container(
                        width: 135,
                        height: 135,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: (_isFrontCamera && _isMeasuring)
                              ? Colors.white.withOpacity(0.25)
                              : statusColor.withOpacity(0.15),
                          border: Border.all(
                            color: _fingerDetected ? const Color(0xFF22C55E) : statusColor,
                            width: 3.0,
                          ),
                          boxShadow: [
                            if (_isFrontCamera && _isMeasuring)
                              BoxShadow(
                                color: Colors.white.withOpacity(0.85),
                                blurRadius: 40,
                                spreadRadius: 10,
                              ),
                            BoxShadow(
                              color: (_fingerDetected ? Colors.green : statusColor).withOpacity(0.35),
                              blurRadius: 26,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // KÍNH NGẮM QUANG HỌC CAMERA LIVE: Cho phép người dùng nhìn thấy 100% hình ảnh thực của ống kính đang chọn
                              if (_mode == HeartRateMode.cameraPpg && _cameraController != null && _isCameraReady)
                                SizedBox.expand(
                                  child: FittedBox(
                                    fit: BoxFit.cover,
                                    child: SizedBox(
                                      width: _cameraController!.value.previewSize?.height ?? 135,
                                      height: _cameraController!.value.previewSize?.width ?? 135,
                                      child: CameraPreview(_cameraController!),
                                    ),
                                  ),
                                ),
                              // Nếu chưa bắt đầu đo: Hiện overlay hướng dẫn đặt ngón tay
                              if (_mode == HeartRateMode.cameraPpg && !_isMeasuring)
                                Container(
                                  color: Colors.black.withOpacity(0.35),
                                  child: Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.fingerprint_rounded, color: Colors.white70, size: 36),
                                        const SizedBox(height: 2),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.black87,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            _isFrontCamera ? 'ÁP VÀO CAM TRƯỚC' : 'ÁP NGÓN TAY VÀO ĐÂY',
                                            style: const TextStyle(
                                              color: Color(0xFFF87171),
                                              fontSize: 8.5,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              // Khi đang đo: Badge trạng thái mao mạch trực quan ở đỉnh kính ngắm (Không che khuất camera)
                              if (_mode == HeartRateMode.cameraPpg && _isMeasuring)
                                Positioned(
                                  top: 10,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                    decoration: BoxDecoration(
                                      color: _fingerDetected
                                          ? const Color(0xFF16A34A).withOpacity(0.9)
                                          : const Color(0xFFDC2626).withOpacity(0.9),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      _fingerDetected
                                          ? '🟢 MAO MẠCH TỐT'
                                          : (_isFrontCamera ? '🔴 ĐANG THẤY CẢNH/MẶT' : '🔴 CHƯA CÓ NGÓN TAY'),
                                      style: const TextStyle(
                                        fontFamily: 'Roboto',
                                        color: Colors.white,
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              // Biểu tượng trái tim nhỏ nhấp nháy góc dưới
                              Positioned(
                                bottom: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.favorite_rounded,
                                        color: _fingerDetected ? const Color(0xFFEF4444) : Colors.white38,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _fingerDetected ? 'MAO MẠCH' : 'CHỜ CHE',
                                        style: TextStyle(
                                          color: _fingerDetected ? const Color(0xFF4ADE80) : Colors.white70,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    if (_mode == HeartRateMode.cameraPpg && _isCameraReady)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Column(
                          children: [
                            Text(
                              _fingerDetected
                                  ? '🟢 Đã nhận diện mao mạch ngón tay (${_getCameraLensShortName(_selectedCameraIndex)})'
                                  : (_isFrontCamera
                                      ? '🔴 Chưa che camera: Đang thấy khuôn mặt / phòng (Hãy đặt ngón tay che kín lỗ camera)'
                                      : '🔴 Chưa che: Hãy áp nhẹ ngón tay vào ống kính sát đèn Flash sau lưng máy'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Roboto',
                                color: _fingerDetected ? const Color(0xFF4ADE80) : const Color(0xFFF87171),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (_isMeasuring)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  _fingerDetected
                                      ? 'Cảm biến: Sáng Y=$_sampleY | Sắc đỏ V=$_sampleV | Lam U=$_sampleU (Đạt chuẩn mao mạch)'
                                      : 'Cảm biến: Sáng Y=$_sampleY | Sắc đỏ V=$_sampleV | Lam U=$_sampleU (Sẵn sàng nhận diện mao mạch)',
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    color: _fingerDetected ? const Color(0xFF4ADE80) : Colors.white54,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            if (_isFrontCamera && _isMeasuring)
                              Container(
                                margin: const EdgeInsets.only(top: 8, bottom: 2),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF59E0B).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.35)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.touch_app_rounded, color: Color(0xFFF59E0B), size: 14),
                                    SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        'Mẹo: Chạm RẤT NHẸ vào lỗ camera, KHÔNG ẤN MẠNH vào màn hình kẻo mất mạch máu!',
                                        style: TextStyle(color: Color(0xFFFDE68A), fontSize: 10.5, fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 12),

                    // Số BPM to rõ ràng (có trạng thái tính toán sơ khởi phản hồi tức thì)
                    Text(
                      _currentBpm > 0
                          ? '$_currentBpm'
                          : (_isMeasuring && _ppgPipeline.lastValidBpm != null
                              ? '~${_ppgPipeline.lastValidBpm}'
                              : (_isMeasuring && _fingerDetected ? '...' : '--')),
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        color: Colors.white,
                        fontSize: (_isMeasuring && _currentBpm == 0 && _fingerDetected && _ppgPipeline.lastValidBpm == null) ? 36 : 48,
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isMeasuring && _currentBpm == 0 && _fingerDetected
                          ? 'ĐANG BẮT NHỊP TIM...'
                          : 'NHỊP / PHÚT (BPM)',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        color: _isMeasuring && _currentBpm == 0 && _fingerDetected
                            ? const Color(0xFF38BDF8)
                            : const Color(0xFF94A3B8),
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),

                    // Tiến trình đo (12 giây)
                    if (_isMeasuring) ...[
                      const SizedBox(height: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: _progress,
                          minHeight: 7,
                          backgroundColor: Colors.white12,
                          valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        (_mode == HeartRateMode.cameraPpg && !_fingerDetected)
                            ? '⚠️ TIẾN TRÌNH TẠM DỪNG (HÃY ÁP ĐẦU NGÓN TAY VÀO CAMERA)'
                            : (_ppgPipeline.totalDetectedPulses > 0
                                ? 'Đang lấy mẫu: ${(_progress * 100).toInt()}% · Đã nhận diện ${_ppgPipeline.totalDetectedPulses} nhịp đập'
                                : 'Đang lấy mẫu tín hiệu mao mạch: ${(_progress * 100).toInt()}%'),
                        style: TextStyle(
                          color: (_mode == HeartRateMode.cameraPpg && !_fingerDetected)
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF64748B),
                          fontSize: 11,
                          fontWeight: (_mode == HeartRateMode.cameraPpg && !_fingerDetected)
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],

                    if (_mode == HeartRateMode.touchPulse && !_isCompleted) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284C7).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          '👉 Chạm vào đây theo từng nhịp mạch bạn cảm nhận được',
                          style: TextStyle(color: Color(0xFF38BDF8), fontSize: 11.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // HỘP KẾT LUẬN Y KHOA & CẢNH BÁO
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF131D31),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: statusColor.withOpacity(0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isNoPulse
                            ? Icons.dangerous_rounded
                            : (isNormal ? Icons.check_circle_rounded : Icons.warning_amber_rounded),
                        color: statusColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          statusTitle,
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            color: statusColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    statusDetail,
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      color: Color(0xFFCBD5E1),
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // NÚT HÀNH ĐỘNG CHÍNH
            if (!_isMeasuring)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 4,
                ),
                onPressed: _startMeasurement,
                icon: const Icon(Icons.play_arrow_rounded, size: 22),
                label: Text(
                  _isCompleted ? 'ĐO LẠI NHỊP TIM' : 'BẮT ĐẦU ĐO (12 GIÂY)',
                  style: const TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w900, fontSize: 14),
                ),
              )
            else
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _stopMeasurementInternal,
                icon: const Icon(Icons.stop_rounded, size: 20),
                label: const Text('DỪNG ĐO', style: TextStyle(fontWeight: FontWeight.bold)),
              ),

            // NẾU TÍN HIỆU KHÔNG ỔN ĐỊNH / CHƯA BẮT ĐƯỢC MẠCH: HỖ TRỢ GỌI 115 & ÉP TIM CPR
            if (isNoPulse) ...[
              const SizedBox(height: 10),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.emergencyRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 6,
                ),
                onPressed: () => _callEmergency(_emergencyPhone),
                icon: const Icon(Icons.phone_in_talk_rounded, size: 22),
                label: const Text(
                  'GỌI CẤP CỨU 115 NGAY LẬP TỨC!',
                  style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w900, fontSize: 13.5),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFF87171),
                  side: const BorderSide(color: Color(0xFFEF4444)),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  _stopMeasurementInternal();
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const CPRCoachScreen()),
                  );
                },
                icon: const Icon(Icons.favorite_rounded, size: 20),
                label: const Text(
                  'NẠN NHÂN BẤT TỈNH -> BẮT ĐẦU ÉP TIM CPR NGAY',
                  style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],

            const SizedBox(height: 10),

            // NÚT LƯU KẾT QUẢ VÀO HỒ SƠ
            if (_isCompleted) ...[
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF38BDF8),
                  side: const BorderSide(color: Color(0xFF38BDF8)),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Đã ghi nhận chỉ số nhịp tim vào hồ sơ cấp cứu Outbox!'),
                      backgroundColor: Color(0xFF16A34A),
                    ),
                  );
                },
                icon: const Icon(Icons.save_rounded, size: 18),
                label: const Text(
                  'LƯU KẾT QUẢ VÀO HỒ SƠ CẤP CỨU',
                  style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildModeTab({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF0284C7) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isActive ? Colors.white : const Color(0xFF94A3B8), size: 15),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Roboto',
                color: isActive ? Colors.white : const Color(0xFF94A3B8),
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Vẽ lưới tọa độ y tế ECG Monitor
class EcgGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0F2634)
      ..strokeWidth = 0.8;

    const step = 20.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Vẽ đường sóng điện tim / xung mạch PPG phát quang
class PpgWaveformPainter extends CustomPainter {
  final List<double> points;
  final Color color;

  PpgWaveformPainter({required this.points, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final centerY = size.height / 2;
    final dx = size.width / 80;

    for (int i = 0; i < points.length; i++) {
      final x = i * dx;
      final y = centerY + (points[i] * (size.height * 0.38));
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    // Đổ bóng phát quang cho sóng
    final glowPaint = Paint()
      ..color = color.withOpacity(0.4)
      ..strokeWidth = 5.0
      ..style = PaintingStyle.stroke;

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant PpgWaveformPainter oldDelegate) => true;
}
