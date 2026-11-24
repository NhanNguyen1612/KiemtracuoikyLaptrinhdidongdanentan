import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/services/demo_mode_service.dart';
import '../../../core/services/tflite_vision_service.dart';
import '../../../core/services/wound_classifier_interface.dart';
// voice_bubble_controller và voice_dialogue_service không dùng trong màn hình này nữa

enum WoundCaseType {
  burnDegree2,
  burnDegree3,
  arterialBleeding,
  openFracture,        // Gãy xương / Trật khớp ngón tay / Biến dạng chi thể (Cần nẹp bất động)
  minorAbrasion,       // Chấn thương trầy xước nhẹ
  cutLaceration,       // Vết đứt tay, rách da mô mềm do dao/vật sắc nhọn
  deepWound,           // Vết thương hở sâu / toác mép lộ cơ gân (Cần khâu y tế)
  tetanusRisk,         // Vết thương kim loại rỉ sét / giẫm đinh (Nguy cơ uốn ván cao)
  animalBite,          // Vết thương chó mèo cắn / động vật cào (Nguy cơ bệnh dại)
  swollenInflammation, // Vết sưng tấy, mẩn đỏ, bầm tím tụ máu, côn trùng cắn
  noWoundDetected,     // Không phát hiện vết thương (Đồ vật hoặc Da người lành lặn)
}

/// Vị trí giải phẫu trên cơ thể nạn nhân (Chân / Tay / Toàn thân)
enum BodyLocation {
  legOrKnee, // Vùng Chân / Đầu gối / Chi dưới
  armOrHand, // Bàn tay / Ngón tay / Cánh tay
  general,   // Thân mình / Toàn thân / Vị trí khác
}

class WoundScannerScreen extends ConsumerStatefulWidget {
  const WoundScannerScreen({super.key});

  @override
  ConsumerState<WoundScannerScreen> createState() => _WoundScannerScreenState();
}

class _WoundScannerScreenState extends ConsumerState<WoundScannerScreen>
    with SingleTickerProviderStateMixin {
  WoundCaseType _selectedCase = WoundCaseType.noWoundDetected;
  BodyLocation _selectedBodyLocation = BodyLocation.legOrKnee;
  Rect _viewfinderBox = const Rect.fromLTWH(0.15, 0.15, 0.70, 0.70);
  bool _isDraggingViewfinder = false;
  bool _isScanning = false;
  bool _scanCompleted = false;
  String _emergencyPhone = DemoModeService.defaultDemoPhone;
  XFile? _capturedImageFile;
  Uint8List? _cachedImageBytes;
  double _lastViewAspect = 0.92;
  final ImagePicker _picker = ImagePicker();
  double _aiConfidence = 0.974;
  int _aiLatencyMs = 28;
  String? _customVisionLabel;
  Rect? _woundRoi;
  bool _needsClarification = false;
  String? _clarificationQuestion;
  List<ClinicalClarificationOption>? _clarificationOptions;
  ClinicalClarificationOption? _selectedOption;
  String _guardrailStatus = 'Zero-Miss Guardrail: Đang sẵn sàng';
  List<String> _safetyChecklist = const [];
  ClinicalTriagePriority _triagePriority = ClinicalTriagePriority.p2SemiUrgent;
  late AnimationController _animController;
  late Animation<double> _scanAnimation;

  // Cổng kiểm soát chất lượng ảnh (Quality Gate) & Red-Flags lâm sàng
  TfliteInferenceResult? _originalVisionResult;
  QualityGateResult? _qualityGate;
  bool _isUncertain = false;
  String? _uncertaintyGuidance;
  final Set<String> _selectedRedFlagIds = {};

  // Live Camera Controller (Luôn bật trực tiếp trong khung ngắm)
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isCameraReady = false;
  bool _isFlashOn = false;
  int _selectedCameraIndex = 0;
  String _cameraErrorMsg = '';

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _scanAnimation = Tween<double>(begin: 0.08, end: 0.92).animate(_animController);
    _loadEmergencyPhone();
    // Khởi động nóng C++ TFLite XNNPACK ngay khi mở màn hình để độ trễ suy luận < 15ms
    Future.microtask(() => ref.read(woundClassifierProvider).initialize());
    _initLiveCamera();
  }

  Future<void> _initLiveCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          setState(() => _cameraErrorMsg = 'Không tìm thấy camera phần cứng');
        }
        return;
      }
      _cameras = cameras;
      final backIdx = cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.back);
      _selectedCameraIndex = backIdx != -1 ? backIdx : 0;
      await _setupCameraController(_cameras[_selectedCameraIndex]);
    } catch (e) {
      debugPrint('[WoundScanner] Camera init error: $e');
      if (mounted) {
        setState(() => _cameraErrorMsg = '$e');
      }
    }
  }

  Future<void> _setupCameraController(CameraDescription camera) async {
    if (_cameraController != null) {
      try {
        if (_isFlashOn) {
          await _cameraController!.setFlashMode(FlashMode.off);
          _isFlashOn = false;
        }
        await _cameraController!.dispose();
      } catch (_) {}
    }

    _cameraController = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await _cameraController!.initialize();
      // Tắt FlashMode.auto mặc định của Android Camera2 (tránh chu kỳ nháy đo sáng 900ms khi bấm chụp)
      // và bật lấy nét liên tục để bấm chụp ăn ngay (< 100ms)
      try {
        await _cameraController!.setFlashMode(_isFlashOn ? FlashMode.torch : FlashMode.off);
      } catch (_) {}
      try {
        await _cameraController!.setFocusMode(FocusMode.auto);
      } catch (_) {}
      try {
        await _cameraController!.setExposureMode(ExposureMode.auto);
      } catch (_) {}
      if (mounted) {
        setState(() {
          _isCameraReady = true;
          _cameraErrorMsg = '';
        });
      }
    } catch (e) {
      debugPrint('[WoundScanner] Setup camera controller error: $e');
      if (mounted) {
        setState(() {
          _isCameraReady = false;
          _cameraErrorMsg = '$e';
        });
      }
    }
  }

  Future<void> _toggleFlash() async {
    if (_cameraController == null || !_isCameraReady) return;
    try {
      final nextMode = _isFlashOn ? FlashMode.off : FlashMode.torch;
      await _cameraController!.setFlashMode(nextMode);
      setState(() => _isFlashOn = !_isFlashOn);
    } catch (e) {
      debugPrint('[WoundScanner] Flash toggle warning: $e');
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length <= 1) return;
    setState(() => _isCameraReady = false);
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    await _setupCameraController(_cameras[_selectedCameraIndex]);
  }

  Future<void> _captureFromLiveCamera() async {
    if (_cameraController == null || !_isCameraReady || _isScanning) return;
    try {
      final XFile photo = await _cameraController!.takePicture();
      try {
        await _cameraController!.pausePreview();
      } catch (_) {}
      await _processCapturedImage(photo);
    } catch (e) {
      debugPrint('[WoundScanner] Capture picture error: $e');
      // Fallback sang hệ thống picker nếu controller bận
      await _takePhotoWithCamera();
    }
  }

  void _resetToLiveCamera() {
    try {
      _cameraController?.resumePreview();
    } catch (_) {}
    setState(() {
      _capturedImageFile = null;
      _cachedImageBytes = null;
      _woundRoi = null;
      _viewfinderBox = const Rect.fromLTWH(0.15, 0.15, 0.70, 0.70);
      _isDraggingViewfinder = false;
      _needsClarification = false;
      _clarificationQuestion = null;
      _clarificationOptions = null;
      _selectedOption = null;
      _originalVisionResult = null;
      _qualityGate = null;
      _isUncertain = false;
      _uncertaintyGuidance = null;
      _selectedRedFlagIds.clear();
      _guardrailStatus = 'Zero-Miss Guardrail: Đang sẵn sàng';
      _safetyChecklist = const [];
      _triagePriority = ClinicalTriagePriority.p2SemiUrgent;
      _isScanning = false;
      _scanCompleted = true;
    });
  }

  Future<void> _loadEmergencyPhone() async {
    final phone = await DemoModeService.getEmergencyPhone();
    if (mounted) {
      setState(() => _emergencyPhone = phone);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  /// Mở Camera phần cứng thực tế để chụp ảnh vết thương
  Future<void> _takePhotoWithCamera() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (photo != null) {
        await _processCapturedImage(photo);
      }
    } catch (e) {
      debugPrint('[WoundScanner] Camera error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.videocam_off_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Không thể mở Camera: $e. Bạn có thể bấm "CHỌN TỪ THƯ VIỆN" để tải ảnh lên!'),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Chọn ảnh vết thương có sẵn trong Thư viện ảnh của máy
  Future<void> _pickImageFromGallery() async {
    try {
      try {
        await _cameraController?.pausePreview();
      } catch (_) {}
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (photo != null) {
        await _processCapturedImage(photo);
      } else if (_capturedImageFile == null) {
        try {
          await _cameraController?.resumePreview();
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[WoundScanner] Gallery error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi chọn ảnh: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Nạp ảnh vào động cơ TFLite Vision On-Device để phân loại vết thương tức thì (Zero Artificial Delay)
  Future<void> _processCapturedImage(XFile imageFile, {Rect? customCropRoi}) async {
    final isSameFileReCrop = customCropRoi != null &&
        _capturedImageFile?.path == imageFile.path &&
        _cachedImageBytes != null;

    setState(() {
      _capturedImageFile = imageFile;
      _isScanning = true;
      _scanCompleted = false;
      if (customCropRoi != null) {
        _viewfinderBox = customCropRoi;
      }
    });

    try {
      final bytes = isSameFileReCrop ? _cachedImageBytes! : await imageFile.readAsBytes();
      _cachedImageBytes = bytes;

      final classifier = ref.read(woundClassifierProvider);
      // Giải mã trực tiếp trên CPU RAM (~2ms) + Suy luận ARM64 SIMD (~4ms), có khóa chống treo 4 giây
      final result = await classifier
          .classify(
            TraumaClassificationInput(
              rawImageBytes: bytes,
              cropRoi: customCropRoi,
              viewAspect: _lastViewAspect,
            ),
          )
          .timeout(const Duration(seconds: 4));

      final detectedCase = _mapLabelToCase(result.label);
      final resolvedRoi = customCropRoi ?? result.woundRoi ?? _viewfinderBox;

      if (mounted) {
        setState(() {
          _originalVisionResult = result;
          _qualityGate = result.qualityGate;
          _isUncertain = result.isUncertain;
          _uncertaintyGuidance = result.uncertaintyGuidance;
          _selectedRedFlagIds.clear();
          _selectedCase = detectedCase;
          _aiConfidence = result.confidence;
          _aiLatencyMs = result.latencyMs;
          _customVisionLabel = result.label;
          _woundRoi = resolvedRoi;
          _viewfinderBox = resolvedRoi;
          _needsClarification = result.needsClarification;
          _clarificationQuestion = result.clarificationQuestion;
          _clarificationOptions = result.clarificationOptions;
          _selectedOption = null;
          _guardrailStatus = result.guardrailStatus;
          _safetyChecklist = result.safetyChecklist;
          _triagePriority = result.triagePriority;
          _isScanning = false;
          _scanCompleted = true;
        });

        ScaffoldMessenger.of(context).clearSnackBars();
        if (result.isUncertain) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFFBBF24),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'AI cảnh báo: ${result.label}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF78350F),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(
                    detectedCase == WoundCaseType.noWoundDetected
                        ? Icons.touch_app_rounded
                        : Icons.check_circle_rounded,
                    color: detectedCase == WoundCaseType.noWoundDetected
                        ? const Color(0xFF38BDF8)
                        : const Color(0xFF4ADE80),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      detectedCase == WoundCaseType.noWoundDetected
                          ? (result.isNonTraumaObject
                              ? 'AI: Không phát hiện vết thương (Đồ vật thông thường)'
                              : 'Chưa thấy tổn thương ở góc rộng — hãy CHẠM khung xanh vào đúng vị trí vết thương!')
                          : 'AI đã nhận diện: ${_getWoundDetails(detectedCase, _selectedBodyLocation).name} (${(_aiConfidence * 100).toStringAsFixed(1)}%)',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF0F172A),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[WoundScanner] Classification error: $e');
      if (mounted) {
        setState(() {
          _isScanning = false;
          _scanCompleted = true;
        });
      }
    } finally {
      if (mounted && _isScanning) {
        setState(() {
          _isScanning = false;
          _scanCompleted = true;
        });
      }
    }
  }

  void _toggleRedFlag(String flagId) {
    setState(() {
      if (_selectedRedFlagIds.contains(flagId)) {
        _selectedRedFlagIds.remove(flagId);
      } else {
        _selectedRedFlagIds.add(flagId);
      }

      if (_originalVisionResult != null) {
        final fused = TfliteVisionService.fuse(
          currentResult: _originalVisionResult!,
          activeRedFlagIds: _selectedRedFlagIds.toList(),
        );
        _selectedCase = _mapLabelToCase(fused.label);
        _aiConfidence = fused.confidence;
        _customVisionLabel = fused.label;
        _guardrailStatus = fused.guardrailStatus;
        _safetyChecklist = fused.safetyChecklist;
        _triagePriority = fused.triagePriority;
      }
    });
  }

  WoundCaseType _mapLabelToCase(String label) {
    final lower = label.toLowerCase();
    if (lower.contains('không phát hiện') ||
        lower.contains('đồ vật') ||
        lower.contains('bàn phím') ||
        lower.contains('thiết bị') ||
        lower.contains('lành lặn') ||
        lower.contains('không có vết thương')) {
      return WoundCaseType.noWoundDetected;
    }
    // Cảnh báo chất lượng ảnh
    if (lower.contains('chất lượng ảnh không đạt') || lower.contains('cảnh báo chất lượng')) {
      return WoundCaseType.minorAbrasion;
    }
    // ƯU TIÊN 0: ĐỨT RÁCH ĐỘNG MẠCH / BÓ MẠCH THẦN KINH CHI
    if (lower.contains('bó mạch thần kinh') ||
        lower.contains('thiếu máu chi') ||
        lower.contains('hoại tử thiếu máu')) {
      return WoundCaseType.deepWound;
    }
    // ƯU TIÊN 1: GÃY XƯƠNG / TRẬT KHỚP / BIẾN DẠNG CHI
    if (lower.contains('xương') ||
        lower.contains('gãy') ||
        lower.contains('trật khớp') ||
        lower.contains('biến dạng') ||
        lower.contains('nẹp bất động')) {
      return WoundCaseType.openFracture;
    }
    // ƯU TIÊN 2: CHÓ CẮN / ĐỘNG VẬT CÀO (NGUY CƠ DẠI)
    if (lower.contains('chó cắn') ||
        lower.contains('động vật') ||
        lower.contains('mèo cào') ||
        lower.contains('bệnh dại')) {
      return WoundCaseType.animalBite;
    }
    // ƯU TIÊN 3: ĐINH RỈ / KIM LOẠI RỈ SÉT (NGUY CƠ UỐN VÁN)
    if (lower.contains('rỉ sét') ||
        lower.contains('đinh') ||
        lower.contains('uốn ván') ||
        lower.contains('sat')) {
      return WoundCaseType.tetanusRisk;
    }
    // ƯU TIÊN 4: VẾT THƯƠNG HỞ SÂU / TOÁC MÉP LỘ CƠ GÂN
    if (lower.contains('hở sâu') ||
        lower.contains('toác mép') ||
        lower.contains('lộ cơ gân') ||
        lower.contains('khâu y tế')) {
      return WoundCaseType.deepWound;
    }
    // ƯU TIÊN 5: CHẢY MÁU ĐỘNG MẠCH Ồ ẠT
    if (lower.contains('động mạch') ||
        lower.contains('phun thành tia') ||
        lower.contains('ồ ạt')) {
      return WoundCaseType.arterialBleeding;
    }
    // ƯU TIÊN 6: BỎNG SÂU HOẠI TỬ ĐỘ 3
    if (lower.contains('bỏng sâu') ||
        lower.contains('độ 3') ||
        lower.contains('hoại tử') ||
        lower.contains('điện') ||
        lower.contains('cháy xém')) {
      return WoundCaseType.burnDegree3;
    }
    // ƯU TIÊN 7: BỎNG NƯỚC SÔI ĐỘ 2
    if (lower.contains('bỏng') ||
        lower.contains('nước sôi') ||
        lower.contains('bỏng nhiệt') ||
        lower.contains('độ 2')) {
      return WoundCaseType.burnDegree2;
    }
    // ƯU TIÊN 8: BẦM TÍM TỤ MÁU / SƯNG TẤY
    if (lower.contains('bầm tím') ||
        lower.contains('tụ máu') ||
        lower.contains('sưng tấy') ||
        lower.contains('mẩn đỏ') ||
        lower.contains('phù nề') ||
        lower.contains('viêm mô') ||
        lower.contains('côn trùng')) {
      return WoundCaseType.swollenInflammation;
    }
    // ƯU TIÊN 9: VẾT ĐỨT TAY / RÁCH DA CHẢY MÁU
    if (lower.contains('đứt tay') ||
        lower.contains('vết đứt') ||
        lower.contains('rách da') ||
        lower.contains('vật sắc nhọn') ||
        lower.contains('mô mềm')) {
      return WoundCaseType.cutLaceration;
    }
    if (lower.contains('máu') || lower.contains('rách') || lower.contains('chảy máu')) {
      return WoundCaseType.cutLaceration;
    }
    return WoundCaseType.minorAbrasion;
  }


  Future<void> _callEmergency(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Color _getTriagePriorityColor(ClinicalTriagePriority priority) {
    switch (priority) {
      case ClinicalTriagePriority.p0Catastrophic:
        return const Color(0xFFEF4444);
      case ClinicalTriagePriority.p1Urgent:
        return const Color(0xFFF97316);
      case ClinicalTriagePriority.p2SemiUrgent:
        return const Color(0xFFF59E0B);
      case ClinicalTriagePriority.p3NonUrgent:
        return const Color(0xFF10B981);
      case ClinicalTriagePriority.p4Normal:
        return const Color(0xFF64748B);
    }
  }

  IconData _getTriagePriorityIcon(ClinicalTriagePriority priority) {
    switch (priority) {
      case ClinicalTriagePriority.p0Catastrophic:
        return Icons.warning_amber_rounded;
      case ClinicalTriagePriority.p1Urgent:
        return Icons.emergency_rounded;
      case ClinicalTriagePriority.p2SemiUrgent:
        return Icons.healing_rounded;
      case ClinicalTriagePriority.p3NonUrgent:
        return Icons.health_and_safety_rounded;
      case ClinicalTriagePriority.p4Normal:
        return Icons.verified_user_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final emergencyPhone = _emergencyPhone;
    final caseData = _getWoundDetails(_selectedCase, _selectedBodyLocation);
    final screenH = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text(
          'QUÉT VẾT THƯƠNG AI',
          style: TextStyle(
            fontFamily: 'Roboto',
            fontWeight: FontWeight.w800,
            fontSize: 15,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Gọi cấp cứu 115',
            icon: const Icon(Icons.phone_in_talk_rounded, color: Color(0xFFEF4444)),
            onPressed: () => _callEmergency(emergencyPhone),
          ),
        ],
      ),
      body: Column(
        children: [
          // ═══════════════════════════════════════════════════
          // VÙNG CAMERA LỚN (chiếm ~55% chiều cao màn hình)
          // ═══════════════════════════════════════════════════
          Container(
            height: screenH * 0.52,
            margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isScanning
                    ? const Color(0xFF38BDF8)
                    : (_scanCompleted ? caseData.triageColor : const Color(0xFF334155)),
                width: 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: (_scanCompleted ? caseData.triageColor : const Color(0xFF38BDF8))
                      .withOpacity(0.2),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: LayoutBuilder(
                builder: (ctx, constraints) {
                  final boxW = constraints.maxWidth;
                  final boxH = constraints.maxHeight;
                  if (boxW > 20 && boxH > 20) {
                    _lastViewAspect = boxW / boxH;
                  }

                  return Stack(
                    children: [
                      // 1. HIỂN THỊ HÌNH ẢNH ĐÃ CHỤP HOẶC CAMERA TRỰC TIẾP
                      if (_capturedImageFile != null)
                        Positioned.fill(
                          child: Image.file(
                            File(_capturedImageFile!.path),
                            fit: BoxFit.cover,
                          ),
                        )
                      else if (_isCameraReady && _cameraController != null)
                        Positioned.fill(
                          child: FittedBox(
                            fit: BoxFit.cover,
                            child: SizedBox(
                              width: _cameraController!.value.previewSize?.height ?? 310,
                              height: _cameraController!.value.previewSize?.width ?? 310,
                              child: CameraPreview(_cameraController!),
                            ),
                          ),
                        )
                      else
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  const Color(0xFF0284C7).withOpacity(0.15),
                                  const Color(0xFF0F172A),
                                ],
                              ),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.photo_camera_rounded,
                                      size: 72, color: Colors.white24),
                                  const SizedBox(height: 12),
                                  Text(
                                    _cameraErrorMsg.isNotEmpty
                                        ? 'Camera không khả dụng\n$_cameraErrorMsg'
                                        : 'Đang khởi động camera...',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                      // 2. KHUNG NGẮM TƯƠNG TÁC (Interactive Viewfinder)
                      Positioned.fill(
                        child: CustomPaint(
                          painter: InteractiveReticlePainter(
                            roi: _viewfinderBox,
                            color: _isScanning
                                ? const Color(0xFF38BDF8)
                                : (_scanCompleted ? caseData.triageColor : const Color(0xFF38BDF8)),
                            isDragging: _isDraggingViewfinder,
                            label: _scanCompleted && _selectedCase != WoundCaseType.noWoundDetected
                                ? '🎯 VÙNG VẾT THƯƠNG'
                                : '🎯 CHẠM / KÉO ĐẾN VẾT THƯƠNG',
                          ),
                        ),
                      ),

                      // 3. LỚP BẮT CỬ CHỈ CHẠM VÀ KÉO KHUNG NGẮM (Tap to Focus / Drag ROI)
                      Positioned.fill(
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTapDown: (details) {
                            if (_isScanning) return;
                            final touchX = (details.localPosition.dx / boxW).clamp(0.05, 0.95);
                            final touchY = (details.localPosition.dy / boxH).clamp(0.05, 0.95);
                            final curW = _viewfinderBox.width;
                            final curH = _viewfinderBox.height;
                            final newLeft = (touchX - curW / 2).clamp(0.0, 1.0 - curW);
                            final newTop = (touchY - curH / 2).clamp(0.0, 1.0 - curH);
                            setState(() {
                              _viewfinderBox = Rect.fromLTWH(newLeft, newTop, curW, curH);
                            });
                            if (_capturedImageFile != null) {
                              _processCapturedImage(_capturedImageFile!, customCropRoi: _viewfinderBox);
                            }
                          },
                          onPanStart: (details) {
                            if (_isScanning) return;
                            setState(() => _isDraggingViewfinder = true);
                          },
                          onPanUpdate: (details) {
                            if (_isScanning) return;
                            final curW = _viewfinderBox.width;
                            final curH = _viewfinderBox.height;
                            final deltaX = details.delta.dx / boxW;
                            final deltaY = details.delta.dy / boxH;
                            final newLeft = (_viewfinderBox.left + deltaX).clamp(0.0, 1.0 - curW);
                            final newTop = (_viewfinderBox.top + deltaY).clamp(0.0, 1.0 - curH);
                            setState(() {
                              _viewfinderBox = Rect.fromLTWH(newLeft, newTop, curW, curH);
                            });
                          },
                          onPanEnd: (details) {
                            if (_isScanning) return;
                            setState(() => _isDraggingViewfinder = false);
                            if (_capturedImageFile != null) {
                              _processCapturedImage(_capturedImageFile!, customCropRoi: _viewfinderBox);
                            }
                          },
                        ),
                      ),

                      // 4. Laser quét khi đang phân tích
                      if (_isScanning)
                        AnimatedBuilder(
                          animation: _scanAnimation,
                          builder: (ctx, _) => Positioned(
                            top: (screenH * 0.52 - 24) * _scanAnimation.value,
                            left: 0,
                            right: 0,
                            child: Container(
                              height: 3,
                              decoration: BoxDecoration(
                                color: const Color(0xFF38BDF8),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF38BDF8).withOpacity(0.9),
                                    blurRadius: 12,
                                    spreadRadius: 3,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                      // 5. Badge trạng thái (trái trên)
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.72),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _isScanning
                                      ? Colors.amber
                                      : (_capturedImageFile != null
                                          ? Colors.greenAccent
                                          : const Color(0xFF22C55E)),
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                _isScanning
                                    ? 'AI ĐANG PHÂN TÍCH...'
                                    : (_capturedImageFile != null
                                        ? '📸 ẢNH ĐÃ CHỤP'
                                        : '● CAMERA TRỰC TIẾP'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // 6. Flash + flip camera (phải trên)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Row(
                          children: [
                            if (_isCameraReady) ...[
                              IconButton(
                                icon: Icon(
                                  _isFlashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                                  color: _isFlashOn ? Colors.amberAccent : Colors.white60,
                                  size: 20,
                                ),
                                onPressed: _toggleFlash,
                              ),
                              if (_cameras.length > 1)
                                IconButton(
                                  icon: const Icon(Icons.flip_camera_ios_rounded,
                                      color: Colors.white60, size: 20),
                                  onPressed: _switchCamera,
                                ),
                            ],
                            if (_scanCompleted)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.65),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'TFLite · ${_aiLatencyMs}ms',
                                  style: const TextStyle(
                                    color: Color(0xFF38BDF8),
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      // 7. THANH CÔNG CỤ ĐIỀU CHỈNH KÍCH THƯỚC KHUNG NGẮM (Size Toolbar)
                      Positioned(
                        bottom: 8,
                        left: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.78),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white24, width: 0.8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.touch_app_rounded, color: Color(0xFF38BDF8), size: 14),
                                  SizedBox(width: 4),
                                  Text(
                                    'KÉO/CHẠM KHUNG:',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildRoiSizeChip('🔍 Nhỏ', 0.40, 0.40),
                                  const SizedBox(width: 4),
                                  _buildRoiSizeChip('🎯 Vừa', 0.65, 0.65),
                                  const SizedBox(width: 4),
                                  _buildRoiSizeChip('📐 Lớn', 0.85, 0.85),
                                  const SizedBox(width: 4),
                                  _buildRoiResetChip(),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),

          // ═══════════════════════════════════════════════════
          // 2 NÚT CHÍNH: CHỤP ẢNH  |  CHỌN ẢNH
          // ═══════════════════════════════════════════════════
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: _capturedImageFile == null
                ? Row(
                    children: [
                      // Nút CHỤP (lớn hơn)
                      Expanded(
                        flex: 6,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 4,
                          ),
                          onPressed: _isScanning
                              ? null
                              : (_isCameraReady
                                  ? _captureFromLiveCamera
                                  : _takePhotoWithCamera),
                          icon: const Icon(Icons.photo_camera_rounded, size: 22),
                          label: const Text(
                            'CHỤP ẢNH',
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Nút CHỌN ẢNH (nhỏ hơn)
                      Expanded(
                        flex: 4,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF38BDF8),
                            side: const BorderSide(color: Color(0xFF38BDF8), width: 1.3),
                            backgroundColor: const Color(0xFF1E293B),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: _isScanning ? null : _pickImageFromGallery,
                          icon: const Icon(Icons.photo_library_rounded, size: 18),
                          label: const Text(
                            'CHỌN ẢNH',
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        flex: 6,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0284C7),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: _resetToLiveCamera,
                          icon: const Icon(Icons.videocam_rounded, size: 20),
                          label: const Text(
                            'MỞ LẠI CAMERA',
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 4,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF38BDF8),
                            side: const BorderSide(color: Color(0xFF38BDF8), width: 1.3),
                            backgroundColor: const Color(0xFF1E293B),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: _isScanning ? null : _pickImageFromGallery,
                          icon: const Icon(Icons.photo_library_rounded, size: 16),
                          label: const Text(
                            'ĐỔI ẢNH',
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),

          // ═══════════════════════════════════════════════════
          // KẾT QUẢ PHÂN TÍCH (cuộn được, chỉ hiện khi có kết quả)
          // ═══════════════════════════════════════════════════
          if (_scanCompleted)
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Cổng kiểm soát chất lượng ảnh (Quality Gate Warning) ──
                    if (_isUncertain) ...[
                      _buildQualityGateWarningCard(),
                      const SizedBox(height: 12),
                    ],

                    // ── Thanh chọn Vị trí tổn thương giải phẫu 1-chạm (Chân / Tay / Toàn thân) ──
                    _buildBodyLocationSelector(),

                    // ── Kết quả triage ──
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: caseData.triageColor.withOpacity(0.65), width: 1.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: caseData.triageColor,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    caseData.triageCode,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Độ tin cậy: ${(_aiConfidence * 100).toStringAsFixed(1)}%',
                                style: TextStyle(
                                  color: caseData.triageColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          if (_customVisionLabel != null) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0284C7).withOpacity(0.22),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                        color: const Color(0xFF38BDF8).withOpacity(0.35)),
                                  ),
                                  child: Text(
                                    'AI Vision: $_customVisionLabel',
                                    style: const TextStyle(
                                      color: Color(0xFF38BDF8),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3.5),
                                  decoration: BoxDecoration(
                                    color: _getTriagePriorityColor(_triagePriority).withOpacity(0.20),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                        color: _getTriagePriorityColor(_triagePriority).withOpacity(0.4)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(_getTriagePriorityIcon(_triagePriority),
                                          color: _getTriagePriorityColor(_triagePriority), size: 13),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          _guardrailStatus,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: _getTriagePriorityColor(_triagePriority),
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5.5),
                            decoration: BoxDecoration(
                              color: _getTriagePriorityColor(_triagePriority).withOpacity(0.16),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _getTriagePriorityColor(_triagePriority).withOpacity(0.45),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.medical_services_rounded,
                                  size: 14,
                                  color: _getTriagePriorityColor(_triagePriority),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'HÀNH ĐỘNG: ${_triagePriority.actionTitle}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: _getTriagePriorityColor(_triagePriority),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 10.5,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            caseData.clinicalDiagnosis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15.5,
                              fontWeight: FontWeight.bold,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            caseData.triageGuidance,
                            style: TextStyle(
                              color: Colors.grey.shade300,
                              fontSize: 12.5,
                              height: 1.4,
                            ),
                          ),
                          if (_safetyChecklist.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F766E).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFF14B8A6).withOpacity(0.35),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(
                                        Icons.health_and_safety_rounded,
                                        color: Color(0xFF14B8A6),
                                        size: 15,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'QUY TẮC AN TOÀN LÂM SÀNG (WHO / BỘ Y TẾ)',
                                        style: TextStyle(
                                          color: Color(0xFF2DD4BF),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  ..._safetyChecklist.map((item) => Padding(
                                        padding: const EdgeInsets.only(bottom: 4),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              '• ',
                                              style: TextStyle(
                                                color: Color(0xFF14B8A6),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                            Expanded(
                                              child: Text(
                                                item,
                                                style: const TextStyle(
                                                  color: Color(0xFFE2E8F0),
                                                  fontSize: 11.5,
                                                  height: 1.3,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      )),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ── Trợ lý Xác minh lâm sàng 1-chạm (Clinical Clarification) ──
                    if (_needsClarification &&
                        _clarificationQuestion != null &&
                        _clarificationOptions != null &&
                        _clarificationOptions!.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFF38BDF8).withOpacity(0.55),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0284C7).withOpacity(0.12),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0284C7).withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.medical_information_rounded,
                                    color: Color(0xFF38BDF8),
                                    size: 17,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'XÁC MINH LÂM SÀNG 1-CHẠM (CLINICAL TRIAGE)',
                                    style: TextStyle(
                                      color: Color(0xFF38BDF8),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11.5,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _clarificationQuestion!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 10),
                            ..._clarificationOptions!.map((opt) {
                              final isSelected = _selectedOption?.label == opt.label;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(10),
                                  onTap: () {
                                    setState(() {
                                      _selectedOption = opt;
                                      _selectedCase = _mapLabelToCase(opt.targetLabel);
                                      _customVisionLabel = opt.targetLabel;
                                      if (opt.isHighUrgency) {
                                        _guardrailStatus = 'P1 CẤP CỨU KHẨN: Xác nhận hạn chế vận động & biến dạng';
                                        _triagePriority = ClinicalTriagePriority.p1Urgent;
                                      } else {
                                        _guardrailStatus = 'P2 THEO DÕI MÔ MỀM: Chấn thương kín không kèm gãy xương';
                                        _triagePriority = ClinicalTriagePriority.p2SemiUrgent;
                                      }
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? (opt.isHighUrgency
                                              ? const Color(0xFFEF4444).withOpacity(0.22)
                                              : const Color(0xFF0284C7).withOpacity(0.22))
                                          : const Color(0xFF334155).withOpacity(0.45),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isSelected
                                            ? (opt.isHighUrgency
                                                ? const Color(0xFFEF4444)
                                                : const Color(0xFF38BDF8))
                                            : Colors.white12,
                                        width: isSelected ? 1.8 : 1.0,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          isSelected
                                              ? Icons.check_circle_rounded
                                              : Icons.radio_button_unchecked_rounded,
                                          color: isSelected
                                              ? (opt.isHighUrgency
                                                  ? const Color(0xFFEF4444)
                                                  : const Color(0xFF38BDF8))
                                              : Colors.white38,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                opt.label,
                                                style: TextStyle(
                                                  color: isSelected
                                                      ? Colors.white
                                                      : Colors.white70,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12.5,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                opt.description,
                                                style: TextStyle(
                                                  color: Colors.grey.shade400,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // ── Đánh giá Dấu hiệu Cảnh báo Đỏ Lâm sàng (Clinical Red-Flags) ──
                    _buildClinicalRedFlagsCard(),
                    const SizedBox(height: 12),

                    // ── Quy trình sơ cứu ──
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.format_list_numbered_rounded,
                                  color: Color(0xFF38BDF8), size: 18),
                              SizedBox(width: 7),
                              Text(
                                'QUY TRÌNH SƠ CỨU CHUẨN Y TẾ',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ...caseData.steps.map((s) => _buildStepTile(s)),
                          const SizedBox(height: 10),
                          // Cảnh báo nguy hiểm
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF450A0A),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFEF4444)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.dangerous_rounded,
                                    color: Color(0xFFEF4444), size: 18),
                                const SizedBox(width: 7),
                                Expanded(
                                  child: Text(
                                    caseData.dangerWarning,
                                    style: const TextStyle(
                                      color: Color(0xFFFECACA),
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // ── Nút GỌI CẤP CỨU ──
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 5,
                        ),
                        onPressed: () => _callEmergency(emergencyPhone),
                        icon: const Icon(Icons.phone_in_talk_rounded, size: 22),
                        label: Text(
                          'GỌI CẤP CỨU $emergencyPhone NGAY',
                          style: const TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            // Khi chưa có kết quả: gợi ý nhỏ bên dưới nút
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Column(
                children: [
                  const Icon(Icons.arrow_upward_rounded,
                      color: Colors.white24, size: 20),
                  const SizedBox(height: 4),
                  Text(
                    'Chụp ảnh hoặc chọn ảnh vết thương để AI phân tích',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }


  Widget _buildQualityGateWarningCard() {
    final qg = _qualityGate;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF451A03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFFBBF24),
                  size: 20,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'CẢNH BÁO CHẤT LƯỢNG ẢNH (QUALITY GATE)',
                  style: TextStyle(
                    color: Color(0xFFFBBF24),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            qg?.failureMessage ?? 'Chất lượng ảnh không đạt tiêu chuẩn y tế',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _uncertaintyGuidance ??
                'Hệ thống AI từ chối đưa ra kết luận chẩn đoán vội vã để bảo đảm an toàn tính mạng. Vui lòng chụp lại ảnh rõ nét, giữ máy chắc tay và đảm bảo đủ ánh sáng.',
            style: const TextStyle(
              color: Color(0xFFFDE68A),
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF292524),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Độ nét Laplacian: ${qg?.sharpnessScore.toStringAsFixed(1) ?? 'N/A'} (Chuẩn: ≥ 35)',
                  style: TextStyle(
                    color: (qg?.isBlurry ?? false) ? const Color(0xFFF87171) : const Color(0xFF4ADE80),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Luma: ${qg?.meanLuma.toStringAsFixed(1) ?? 'N/A'}',
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: _resetToLiveCamera,
              icon: const Icon(Icons.camera_alt_rounded, size: 16),
              label: const Text(
                'CHỤP LẠI ẢNH RÕ NÉT',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClinicalRedFlagsCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _selectedRedFlagIds.isNotEmpty
              ? const Color(0xFFEF4444)
              : const Color(0xFF64748B).withOpacity(0.4),
          width: _selectedRedFlagIds.isNotEmpty ? 1.6 : 1.0,
        ),
        boxShadow: _selectedRedFlagIds.isNotEmpty
            ? [
                BoxShadow(
                  color: const Color(0xFFEF4444).withOpacity(0.18),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _selectedRedFlagIds.isNotEmpty
                      ? const Color(0xFFEF4444).withOpacity(0.2)
                      : const Color(0xFF64748B).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.crisis_alert_rounded,
                  color: _selectedRedFlagIds.isNotEmpty
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF38BDF8),
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DẤU HIỆU CẢNH BÁO ĐỎ (CLINICAL RED-FLAGS)',
                      style: TextStyle(
                        color: _selectedRedFlagIds.isNotEmpty
                            ? const Color(0xFFF87171)
                            : const Color(0xFF38BDF8),
                        fontWeight: FontWeight.bold,
                        fontSize: 11.5,
                        letterSpacing: 0.4,
                      ),
                    ),
                    Text(
                      _selectedRedFlagIds.isNotEmpty
                          ? 'Đã kích hoạt ${_selectedRedFlagIds.length} cờ khẩn cấp -> Tự động leo thang Triage'
                          : 'Tích chọn dấu hiệu nguy cấp để AI lập tức leo thang mức độ sơ cứu:',
                      style: TextStyle(
                        color: _selectedRedFlagIds.isNotEmpty
                            ? const Color(0xFFFECACA)
                            : Colors.grey.shade400,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...TfliteVisionService.defaultRedFlags.map((flag) {
            final isChecked = _selectedRedFlagIds.contains(flag.id);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => _toggleRedFlag(flag.id),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isChecked
                        ? const Color(0xFFEF4444).withOpacity(0.18)
                        : const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isChecked ? const Color(0xFFEF4444) : Colors.white10,
                      width: isChecked ? 1.4 : 1.0,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(
                          isChecked
                              ? Icons.check_box_rounded
                              : Icons.check_box_outline_blank_rounded,
                          color: isChecked
                              ? const Color(0xFFEF4444)
                              : Colors.grey.shade500,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    flag.title,
                                    style: TextStyle(
                                      color: isChecked ? Colors.white : Colors.grey.shade200,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _getTriagePriorityColor(flag.escalatedPriority).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: _getTriagePriorityColor(flag.escalatedPriority).withOpacity(0.5),
                                    ),
                                  ),
                                  child: Text(
                                    flag.escalatedPriority == ClinicalTriagePriority.p0Catastrophic
                                        ? 'LEO THANG P0'
                                        : 'LEO THANG P1',
                                    style: TextStyle(
                                      color: _getTriagePriorityColor(flag.escalatedPriority),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 9.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              flag.question,
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 11,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRoiSizeChip(String title, double w, double h) {
    final isSelected = (_viewfinderBox.width - w).abs() < 0.08;
    return InkWell(
      onTap: () {
        final curCx = _viewfinderBox.center.dx;
        final curCy = _viewfinderBox.center.dy;
        final newLeft = (curCx - w / 2).clamp(0.0, 1.0 - w);
        final newTop = (curCy - h / 2).clamp(0.0, 1.0 - h);
        setState(() {
          _viewfinderBox = Rect.fromLTWH(newLeft, newTop, w, h);
        });
        if (_capturedImageFile != null && !_isScanning) {
          _processCapturedImage(_capturedImageFile!, customCropRoi: _viewfinderBox);
        }
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0284C7) : Colors.white10,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? const Color(0xFF38BDF8) : Colors.white24,
            width: isSelected ? 1.2 : 0.8,
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontSize: 9.5,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildRoiResetChip() {
    return InkWell(
      onTap: () {
        setState(() {
          _viewfinderBox = const Rect.fromLTWH(0.15, 0.15, 0.70, 0.70);
        });
        if (_capturedImageFile != null && !_isScanning) {
          _processCapturedImage(_capturedImageFile!, customCropRoi: null);
        }
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white24, width: 0.8),
        ),
        child: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 12),
      ),
    );
  }

  Widget _buildBodyLocationSelector() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.accessibility_new_rounded, color: Color(0xFF38BDF8), size: 16),
              const SizedBox(width: 6),
              const Text(
                'VỊ TRÍ TỔN THƯƠNG:',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.4,
                ),
              ),
              const Spacer(),
              Text(
                _selectedBodyLocation == BodyLocation.legOrKnee
                    ? 'Chân / Khớp gối'
                    : (_selectedBodyLocation == BodyLocation.armOrHand ? 'Tay / Ngón tay' : 'Vị trí khác'),
                style: const TextStyle(
                  color: Color(0xFF38BDF8),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildLocationChoiceChip(
                  location: BodyLocation.legOrKnee,
                  title: '🦵 Vùng Chân / Gối',
                  subtitle: 'Đầu gối, cẳng chân, đùi',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildLocationChoiceChip(
                  location: BodyLocation.armOrHand,
                  title: '✋ Tay / Ngón tay',
                  subtitle: 'Cùi chỏ, cánh tay, ngón',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildLocationChoiceChip(
                  location: BodyLocation.general,
                  title: '👤 Vị trí khác',
                  subtitle: 'Thân mình, vai, lưng',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocationChoiceChip({
    required BodyLocation location,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _selectedBodyLocation == location;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedBodyLocation = location;
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0284C7).withOpacity(0.25) : const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF38BDF8) : Colors.white12,
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Column(
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected ? const Color(0xFF7DD3FC) : Colors.grey.shade500,
                fontSize: 8.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepTile(WoundStep step) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF0284C7),
            ),
            child: Center(
              child: Text(
                '${step.number}',
                style: const TextStyle(
                  fontFamily: 'Roboto',
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  step.detail,
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    color: Colors.grey.shade400,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  _WoundCaseDetails _getWoundDetails(WoundCaseType caseType, [BodyLocation location = BodyLocation.legOrKnee]) {
    switch (caseType) {
      case WoundCaseType.noWoundDetected:
        return _WoundCaseDetails(
          name: 'Không Phát Hiện Vết Thương / Đồ Vật Thông Thường',
          visualSymptoms: 'Khung hình là đồ vật (bàn phím, bàn ghế, thiết bị) hoặc vùng không có tổn thương da',
          icon: Icons.search_off_rounded,
          triageColor: const Color(0xFF64748B),
          triageCode: 'P4 • KHÔNG CÓ THƯƠNG TÍCH',
          clinicalDiagnosis: 'Không phát hiện tổn thương ngoại khoa hoặc vết thương hở',
          triageGuidance: 'Khung ngắm đang hướng vào đồ vật thông thường (Bàn phím, mặt bàn, tài liệu...) hoặc không có dấu hiệu chấn thương. Hãy di chuyển khung ngắm đến đúng vùng vết thương hoặc người bị nạn để AI phân loại.',
          dangerWarning: 'LƯU Ý: Hướng camera trực diện vào vết thương ở khoảng cách 15-30cm, giữ yên máy 1 giây và bật đèn Flash nếu môi trường tối.',
          steps: [
            WoundStep(1, 'Di chuyển khung ngắm', 'Đưa khung ngắm nhắm trọn vào vùng da hoặc vết thương của người bị nạn.'),
            WoundStep(2, 'Bật đèn Flash nếu tối', 'Bấm nút biểu tượng Đèn Flash ở góc trên khung ngắm nếu môi trường thiếu sáng.'),
            WoundStep(3, 'Bấm nút CHỤP ĐỂ PHÂN TÍCH', 'Nhấn nút chụp ảnh màu xanh để AI bắt trọn khung hình và phân loại sơ cứu tức thì.'),
          ],
        );
      case WoundCaseType.burnDegree2:
        return _WoundCaseDetails(
          name: 'Vết Bỏng Nước Sôi / Bỏng Nhiệt (Độ 2)',
          visualSymptoms: 'Da ửng đỏ, có bọng nước phồng chứa dịch trong, đau rát dữ dội',
          icon: Icons.local_fire_department_rounded,
          triageColor: const Color(0xFFF59E0B),
          triageCode: 'P1 • CẦN XỬ TRÍ Y TẾ',
          clinicalDiagnosis: 'Bỏng biểu bì sâu / Trung bì độ 2 (Ước tính diện tích ~8-12%)',
          triageGuidance: 'Tổn thương lớp thượng bì và một phần trung bì. Nguy cơ nhiễm trùng và sốc đau nếu không hạ nhiệt đúng cách.',
          dangerWarning: 'CẤM bôi kem đánh răng, nước mắm, mỡ trăn, cồn lên vết bỏng. CẤM dùng đá lạnh chườm trực tiếp hoặc chọc vỡ các bọng nước.',
          steps: [
            WoundStep(1, 'Hạ nhiệt ngay bằng nước mát', 'Để vết bỏng dưới vòi nước sạch chảy nhẹ (15-20°C) liên tục trong 15-20 phút nhằm ngăn nhiệt độ lan sâu vào mô.'),
            WoundStep(2, 'Cởi bỏ đồ trang sức/y phục', 'Nhẹ nhàng tháo nhẫn, đồng hồ trước khi vùng bỏng sưng phù. Cắt quần áo quanh vết thương, không cố giật nếu vải dính chặt.'),
            WoundStep(3, 'Bảo vệ bọng nước & che phủ', 'Dùng gạc vô trùng ẩm hoặc màng bọc thực phẩm sạch quấn nhẹ lên vết bỏng. Bọng nước là màng sinh học tự nhiên chống nhiễm khuẩn.'),
            WoundStep(4, 'Ủ ấm & di chuyển tới cơ sở y tế', 'Đắp chăn mỏng giữ ấm phần cơ thể không bị bỏng để tránh hạ thân nhiệt. Gọi 115 nếu diện tích bỏng rộng.'),
          ],
        );
      case WoundCaseType.burnDegree3:
        return _WoundCaseDetails(
          name: 'Bỏng Lửa / Hóa Chất / Điện Sâu (Độ 3)',
          visualSymptoms: 'Da cháy xém hóa than, trắng bệch hoặc xám tro, mất cảm giác đau',
          icon: Icons.warning_amber_rounded,
          triageColor: const Color(0xFFEF4444),
          triageCode: 'P0 • CỰC KỲ NGUY KỊCH',
          clinicalDiagnosis: 'Bỏng toàn bộ các lớp da & cơ độ 3 (Nguy cơ sốc bỏng nặng)',
          triageGuidance: 'Toàn bộ lớp da và dây thần kinh bị hủy hoại. Nạn nhân có nguy cơ suy tuần hoàn, nhiễm trùng máu và co rút sẹo nghiêm trọng.',
          dangerWarning: 'NGUY CƠ TỬ VONG CAO: Tuyệt đối không xả nước đá lạnh diện rộng (gây hạ thân nhiệt nguy kịch). Khẩn cấp chuyển viện 115.',
          steps: [
            WoundStep(1, 'Dập lửa & ngắt hoàn toàn nguồn nhiệt/điện', 'Bảo đảm an toàn tuyệt đối cho người sơ cứu trước khi tiếp cận nạn nhân.'),
            WoundStep(2, 'Che phủ kín bằng vải sạch vô trùng', 'Dùng khăn hoặc gạc vô trùng che phủ nhẹ nhàng vùng bỏng, không chà xát.'),
            WoundStep(3, 'Ủ ấm cơ thể và nâng cao chân', 'Đặt nạn nhân nằm thoải mái, đắp chăn ấm để chống tụt huyết áp và sốc trụy mạch.'),
            WoundStep(4, 'Khởi động CPR nếu ngừng tim', 'Nếu nạn nhân bất tỉnh, không thấy lồng ngực di động -> lập tức mở máy đếm nhịp CPR 110 BPM ép tim.'),
          ],
        );
      case WoundCaseType.arterialBleeding:
        return _WoundCaseDetails(
          name: 'Vết Rách Sâu Chảy Máu Động Mạch',
          visualSymptoms: 'Máu đỏ tươi phun thành tia mạnh theo nhịp đập của tim',
          icon: Icons.bloodtype_rounded,
          triageColor: const Color(0xFFEF4444),
          triageCode: 'P0 • ĐE DỌA TÍNH MẠNG',
          clinicalDiagnosis: 'Tổn thương đứt động mạch ngoại vi (Nguy cơ sốc mất máu trong 3 phút)',
          triageGuidance: 'Mất máu ồ ạt dẫn đến tử vong nhanh chóng nếu không thực hiện cầm máu khẩn cấp ngay tại hiện trường.',
          dangerWarning: 'Không chần chừ tìm kiếm bông băng hoàn hảo. Ép ngón tay hoặc bàn tay trần (qua gạc/vải) trực tiếp lên điểm chảy máu ngay lập tức.',
          steps: [
            WoundStep(1, 'Băng ép trực tiếp liên tục', 'Dùng cuộn gạc hoặc vải sạch ấn thật chặt trực tiếp lên miệng vết thương không buông trong 5-10 phút.'),
            WoundStep(2, 'Nâng cao chi bị tổn thương', 'Nâng cao phần chi bị thương cao hơn mức của tim để giảm áp lực dồn máu.'),
            WoundStep(3, 'Đặt ga-rô khi ép trực tiếp không hiệu quả', 'Buộc dải ga-rô phía trên vết thương 5cm. Siết chặt cho đến khi máu ngừng phun. GHI RÕ GIỜ ĐẶT GA-RÔ!'),
            WoundStep(4, 'Gọi 115 và chống sốc', 'Cho nạn nhân nằm đầu thấp, nâng chân cao 30cm, ủ ấm và di chuyển cấp cứu khẩn.'),
          ],
        );
      case WoundCaseType.openFracture:
        if (location == BodyLocation.legOrKnee) {
          return _WoundCaseDetails(
            name: 'Gãy Xương / Trật Khớp Chi Dưới / Khớp Gối',
            visualSymptoms: 'Chi dưới biến dạng trục, gập góc bất thường, sưng nề đau chói, mất hoàn toàn khả năng chịu lực',
            icon: Icons.healing_rounded,
            triageColor: const Color(0xFFF59E0B),
            triageCode: 'P1 • CẤP CỨU CHẤN THƯƠNG CHỈNH HÌNH',
            clinicalDiagnosis: 'Gãy xương / Trật khớp chi dưới - khớp gối (Cần nẹp bất động khẩn)',
            triageGuidance: 'Biến dạng trục chi dưới thể hiện tổn thương gãy xương hoặc trật khớp hoàn toàn. Bắt buộc phải bất động chi ở nguyên tư thế hiện tại, không tự ý nắn bẻ, tuyệt đối không để nạn nhân đứng chịu lực.',
            dangerWarning: 'TUYỆT ĐỐI CẤM tự ý bẻ thẳng, nắn kéo hoặc kéo giật chân. Không để nạn nhân thử đứng dậy hay đi lại.',
            steps: [
              WoundStep(1, 'Bất động giữ nguyên tư thế biến dạng', 'Để chi dưới ở nguyên tư thế gập góc hiện tại. Tuyệt đối không cố nắn chỉnh.'),
              WoundStep(2, 'Nẹp cố định chi dưới (Nẹp gỗ / Nẹp cứng)', 'Dùng 2 thanh nẹp cứng hoặc nẹp gỗ áp vào mặt trong và mặt ngoài từ bắp đùi qua khớp gối đến cổ chân, dùng khăn/vải quấn cố định nhẹ nhàng.'),
              WoundStep(3, 'Chườm lạnh bọc khăn 15-20 phút', 'Bọc túi đá trong khăn vải áp nhẹ quanh vùng sưng nề để co mạch, hạ nhiệt và giảm đau dữ dội.'),
              WoundStep(4, 'Kê cao chân & gọi 115 chuyển viện', 'Kê cao chân bị thương lên gối mềm cao hơn mức tim, gọi xe cấp cứu 115 chuyển đến khoa Chấn thương Chỉnh hình.'),
            ],
          );
        } else if (location == BodyLocation.armOrHand) {
          return _WoundCaseDetails(
            name: 'Gãy Xương / Trật Khớp Bàn Tay / Cánh Tay',
            visualSymptoms: 'Trục ngón tay / cẳng tay gập góc bất thường, trật khớp gập góc, sưng đau mất vận động',
            icon: Icons.healing_rounded,
            triageColor: const Color(0xFFF59E0B),
            triageCode: 'P1 • CẤP CỨU CHẤN THƯƠNG CHỈNH HÌNH',
            clinicalDiagnosis: 'Gãy xương / Trật khớp ngón tay - chi trên biến dạng trục cơ học (Cần nẹp bất động khẩn)',
            triageGuidance: 'Biến dạng góc trục ngón tay/khớp thể hiện tổn thương gãy xương hoặc trật khớp hoàn toàn. Bắt buộc phải bất động ở nguyên tư thế hiện tại, không tự ý nắn bẻ để tránh đứt bó mạch thần kinh.',
            dangerWarning: 'TUYỆT ĐỐI CẤM tự ý bẻ thẳng, nắn kéo hoặc giật ngón tay bị trật. Không xoa dầu nóng/cao dán làm tăng phù nề xuất huyết chèn ép khoang.',
            steps: [
              WoundStep(1, 'Bất động giữ nguyên tư thế biến dạng', 'Để ngón tay hoặc cánh tay ở nguyên tư thế gập góc hiện tại. Tuyệt đối không cố nắn chỉnh.'),
              WoundStep(2, 'Nẹp cố định sinh lý (Buddy Taping / Treo tay)', 'Nếu ngón tay: dùng ngón lành liền kề làm điểm tựa Buddy Taping; Nếu cẳng tay: dùng nẹp phẳng và treo tay bằng khăn tam giác áp vào ngực.'),
              WoundStep(3, 'Chườm lạnh bọc khăn 10-15 phút', 'Bọc túi đá trong khăn vải áp nhẹ quanh vùng khớp tổn thương để co mạch, hạ nhiệt và giảm đau dữ dội.'),
              WoundStep(4, 'Nâng cao bàn tay & đến viện chụp X-quang', 'Giữ bàn tay cao hơn tim để giảm phù nề, chuyển ngay đến khoa Chấn thương Chỉnh hình để bác sĩ gây tê nắn khớp.'),
            ],
          );
        } else {
          return _WoundCaseDetails(
            name: 'Gãy Xương / Trật Khớp / Biến Dạng Chi Thể',
            visualSymptoms: 'Vùng chấn thương gập góc bất thường, sưng nề đau chói, mất vận động cơ học',
            icon: Icons.healing_rounded,
            triageColor: const Color(0xFFF59E0B),
            triageCode: 'P1 • CẤP CỨU CHẤN THƯƠNG CHỈNH HÌNH',
            clinicalDiagnosis: 'Gãy xương / Biến dạng trục cơ học chi thể (Cần nẹp bất động khẩn)',
            triageGuidance: 'Bắt buộc phải bất động ở nguyên tư thế hiện tại, không tự ý nắn bẻ để tránh tổn thương thứ phát.',
            dangerWarning: 'TUYỆT ĐỐI CẤM tự ý bẻ thẳng hoặc nắn kéo vùng chấn thương.',
            steps: [
              WoundStep(1, 'Bất động giữ nguyên tư thế biến dạng', 'Để vùng chi thể ở nguyên tư thế hiện tại, tuyệt đối không cố nắn chỉnh.'),
              WoundStep(2, 'Cố định nẹp tạm thời qua 2 khớp', 'Dùng nẹp cứng hoặc vật phẳng cố định qua 2 khớp lân cận của đoạn nghi gãy.'),
              WoundStep(3, 'Chườm lạnh bọc khăn 10-15 phút', 'Chườm đá lạnh bọc khăn quanh vùng sưng nề để hạ nhiệt và giảm đau.'),
              WoundStep(4, 'Nâng cao vùng tổn thương & chuyển viện', 'Kê cao phần chi bị thương và chuyển ngay đến bệnh viện gần nhất.'),
            ],
          );
        }
      case WoundCaseType.deepWound:
        return _WoundCaseDetails(
          name: 'Vết Thương Hở Sâu / Toác Mép Lộ Cơ Gân',
          visualSymptoms: 'Vết rách sâu toác hoác mép, thấy lớp mỡ vàng hoặc gân cơ, đáy vết thương sẫm máu',
          icon: Icons.emergency_rounded,
          triageColor: const Color(0xFFEF4444),
          triageCode: 'P1 • CẦN KHÂU Y TẾ TRONG 6H',
          clinicalDiagnosis: 'Vết thương phần mềm sâu toác mép tổn thương cân cơ (Cần khâu phẫu thuật & tiêm SAT)',
          triageGuidance: 'Tổn thương đứt rách qua toàn bộ lớp trung bì đến mô dưới da hoặc gân. Cần sơ cứu cầm máu và đến bệnh viện khâu trong thời gian vàng 6 giờ.',
          dangerWarning: 'CẤM tự ý rắc thuốc kháng sinh, bột lá cây, tro bếp vào vết thương sâu gây hoại tử dị vật. Nếu có dị vật cắm sâu -> KHÔNG rút ra tại chỗ.',
          steps: [
            WoundStep(1, 'Băng ép trực tiếp liên tục', 'Đặt nhiều lớp gạc vô trùng ấn chặt trực tiếp lên miệng vết toác trong 5-10 phút để cầm máu.'),
            WoundStep(2, 'Không cố rửa sâu nếu máu đang chảy', 'Chỉ rửa nhẹ bờ ngoài da bằng nước muối sinh lý. Không xối mạnh làm trôi cục máu đông.'),
            WoundStep(3, 'Băng cuộn ép vừa phải giữ mép', 'Băng cuộn cố định gạc, kéo sát 2 mép da lại gần nhau (nếu được) nhưng không siết quá chặt làm tím đầu ngón.'),
            WoundStep(4, 'Đến bệnh viện khâu trong 6 giờ', 'Cần bác sĩ xử trí cắt lọc vô khuẩn và khâu đóng vết thương thẩm mỹ trong 6 giờ đầu.'),
          ],
        );
      case WoundCaseType.tetanusRisk:
        return _WoundCaseDetails(
          name: 'Vết Thương Kim Loại Rỉ Sét / Giẫm Đinh (Nguy Cơ Uốn Ván)',
          visualSymptoms: 'Vết đâm sâu lỗ hẹp do đinh rỉ, mảnh sắt han gỉ hoặc vật nhọn bẩn bám dính đất cát',
          icon: Icons.report_problem_rounded,
          triageColor: const Color(0xFFF97316),
          triageCode: 'P2 • TIÊM HUYẾT THANH SAT TRONG 24H',
          clinicalDiagnosis: 'Vết thương đâm xuyên kim loại bẩn kỵ khí (Nguy cơ nhiễm nha bào uốn ván Clostridium tetani)',
          triageGuidance: 'Vết đâm hẹp và sâu là môi trường kỵ khí lý tưởng cho vi khuẩn uốn ván phát triển và tiết ngoại độc tố thần kinh cực độc. Phải tiêm SAT trong 24 giờ.',
          dangerWarning: 'CẤM bịt kín vết đâm bằng băng keo kín hơi hoặc bôi sáp/dầu mỡ (tạo môi trường yếm khí cho vi khuẩn uốn ván bùng phát).',
          steps: [
            WoundStep(1, 'Rửa sạch dưới vòi nước chảy 10 phút', 'Xối nước sạch liên tục để đẩy dị vật và rỉ sét ra ngoài. Có thể bóp nhẹ quanh vết đâm để máu tống vi khuẩn ra.'),
            WoundStep(2, 'Sát trùng kỹ bằng Povidone-Iodine', 'Dùng dung dịch sát khuẩn Iodine hoặc cồn 70 độ rửa sạch quanh miệng vết thương.'),
            WoundStep(3, 'Băng gạc thoáng khí', 'Che phủ bằng miếng gạc sạch thoáng khí, không dán kín mít để vết thương tiếp xúc với oxy.'),
            WoundStep(4, 'Tiêm huyết thanh SAT trong 24 giờ', 'Đến ngay Trung tâm Y tế dự phòng hoặc bệnh viện để tiêm SAT (kháng độc tố uốn ván) và vắc xin VAT.'),
          ],
        );
      case WoundCaseType.animalBite:
        return _WoundCaseDetails(
          name: 'Vết Thương Chó Mèo Cắn / Động Vật Cào (Nguy Cơ Bệnh Dại)',
          visualSymptoms: 'Dấu răng nanh đâm thủng hoặc vết cào rách chảy máu kèm bầm dập mô quanh vết cắn',
          icon: Icons.pets_rounded,
          triageColor: const Color(0xFFEF4444),
          triageCode: 'P1 • CẤP BÁCH PHÒNG BỆNH DẠI 100%',
          clinicalDiagnosis: 'Vết thương động vật cắn/cào độ III (Nguy cơ lây nhiễm virus dại Rhabdovirus qua nước bọt)',
          triageGuidance: 'Bệnh dại khi đã phát bệnh có tỷ lệ tử vong 100%. Sơ cứu xối rửa xà phòng 15 phút ngay tại chỗ là chìa khóa sống còn trước khi tiêm vắc xin.',
          dangerWarning: 'TUYỆT ĐỐI KHÔNG nặn bóp làm dập nát thêm mô, KHÔNG khâu kín vết thương chó cắn (tạo điều kiện virus xâm nhập thần kinh).',
          steps: [
            WoundStep(1, 'Xối rửa xà phòng 15 phút lập tức', 'Rửa vết cắn liên tục dưới vòi nước chảy mạnh với xà phòng hoặc nước rửa tay diệt khuẩn trong ít nhất 15 phút.'),
            WoundStep(2, 'Sát khuẩn bằng cồn 70° hoặc Betadine', 'Sau khi rửa xà phòng, sát trùng kỹ vết thương bằng dung dịch Povidone-Iodine hoặc cồn y tế.'),
            WoundStep(3, 'Đến trung tâm tiêm chủng tiêm vắc xin', 'Đến VNVC hoặc Trạm Y tế tiêm vắc xin ngừa dại (và huyết thanh kháng dại SAR nếu vết cắn sâu/ở đầu mặt cổ).'),
            WoundStep(4, 'Theo dõi động vật 10-14 ngày', 'Nhốt theo dõi chó/mèo trong 10-14 ngày. Nếu con vật ốm, biến mất hoặc chết -> báo ngay bác sĩ tiêm phác đồ khẩn cấp.'),
          ],
        );
      case WoundCaseType.cutLaceration:
        return _WoundCaseDetails(
          name: location == BodyLocation.legOrKnee
              ? 'Vết Đứt / Rách Da Chảy Máu Bàn Chân & Chi Dưới'
              : 'Vết Đứt Tay / Rách Da Chảy Máu Sắc Gọn',
          visualSymptoms: 'Vết rách thẳng do dao kéo/mảnh kính, rỉ hoặc trào máu, hở mô mềm dưới da',
          icon: Icons.cut_rounded,
          triageColor: const Color(0xFFEF4444),
          triageCode: 'P2 • XỬ TRÍ CẦM MÁU TẠI CHỖ',
          clinicalDiagnosis: 'Vết thương hở đứt rách phần mềm ngoài da (Có nguy cơ nhiễm trùng uốn ván)',
          triageGuidance: 'Vết cắt sắc nhọn gây rách biểu bì và mao mạch. Cần nhanh chóng ép trực tiếp cầm máu, sát khuẩn phòng uốn ván và đánh giá xem có cần khâu thẩm mỹ hay không.',
          dangerWarning: 'CẤM rắc bột thuốc lào, tro bếp, đường lên vết đứt. Nếu vết đứt sâu thấy mỡ/gân hoặc tê bì đầu ngón -> phải đến viện khâu.',
          steps: [
            WoundStep(1, 'Rửa sạch dưới vòi nước mát', 'Xối nhẹ nước sạch hoặc nước muối sinh lý 0.9% để làm sạch dị vật và bụi bẩn quanh miệng vết cắt.'),
            WoundStep(2, 'Băng ép trực tiếp cầm máu 3-5 phút', 'Dùng miếng gạc vô trùng hoặc khăn sạch ấn chặt trực tiếp lên miệng vết đứt, nâng cao vùng bị thương hơn mức tim.'),
            WoundStep(3, 'Sát trùng bờ mép & dán băng ép', 'Chấm dung dịch sát khuẩn Povidone-Iodine quanh rìa vết cắt, khép sát mép da và dán băng Urgo hoặc băng cuộn nhẹ.'),
            WoundStep(4, 'Đánh giá nguy cơ & tiêm SAT', 'Nếu mép rách toạc hở sâu >0.5cm hoặc do kim loại gỉ sét gây ra -> đến trạm y tế khâu và tiêm vắc xin uốn ván.'),
          ],
        );
      case WoundCaseType.swollenInflammation:
        return _WoundCaseDetails(
          name: location == BodyLocation.legOrKnee ? 'Sưng Nề / Bầm Tím Tụ Máu Khớp Gối & Chi Dưới' : 'Tổn Thương Sưng Tấy / Mẩn Đỏ / Viêm Mô',
          visualSymptoms: 'Vùng da sưng nề phồng rộp, ửng đỏ lan tỏa, nóng rát, ngứa hoặc đau tức',
          icon: Icons.grain_rounded,
          triageColor: const Color(0xFFF97316),
          triageCode: 'P2 • GIẢM PHÙ NỀ & THEO DÕI',
          clinicalDiagnosis: 'Phản ứng viêm phù nề cục bộ / Mẩn đỏ dị ứng / Côn trùng đốt / Viêm mô tế bào nông',
          triageGuidance: 'Tổn thương sưng tấy do phản ứng viêm mao mạch mô mềm hoặc nọc độc côn trùng. Cần chườm lạnh hạ nhiệt phù nề và theo dõi sát dấu hiệu lan rộng.',
          dangerWarning: 'TUYỆT ĐỐI KHÔNG cào gãi làm xước da, không chọc nặn mủ dịch, không xoa dầu nóng hoặc cao dán trực tiếp lên vùng sưng tấy.',
          steps: [
            WoundStep(1, 'Chườm mát hạ sưng nề 15-20 phút', 'Bọc túi đá lạnh vào khăn vải sạch chườm ngắt quãng 15 phút lên chỗ sưng (không áp đá trực tiếp lên da).'),
            WoundStep(2, 'Rửa sạch da bằng xà phòng dịu nhẹ', 'Dùng nước mát và xà phòng kháng khuẩn rửa nhẹ nhàng nếu nghi ngờ bị côn trùng hoặc sâu bọ đốt.'),
            WoundStep(3, 'Kê cao vùng chi sưng phù', location == BodyLocation.legOrKnee ? 'Kê cao chân lên gối mềm cao hơn mức tim để máu và dịch bạch huyết lưu thông giảm tụ dịch.' : 'Nâng cao bàn tay/cánh tay lên gối mềm cao hơn mức tim để giảm phù nề.'),
            WoundStep(4, 'Theo dõi phản ứng toàn thân', 'Nếu vùng đỏ lan nhanh, sốt cao, hoặc xuất hiện khó thở/sưng môi mắt -> lập tức đi cấp cứu chống sốc phản vệ.'),
          ],
        );
      case WoundCaseType.minorAbrasion:
        return _WoundCaseDetails(
          name: location == BodyLocation.legOrKnee ? 'Trầy Xước / Trợt Da Đầu Gối & Chi Dưới' : 'Chấn Thương Trầy Xước & Đụng Dập Nhẹ',
          visualSymptoms: 'Trầy xước biểu bì nông, rớm máu nhẹ hoặc mài đỏ, sưng bầm bề mặt',
          icon: Icons.health_and_safety_rounded,
          triageColor: const Color(0xFF10B981),
          triageCode: 'P3 • CHĂM SÓC TẠI NHÀ',
          clinicalDiagnosis: 'Tổn thương trợt biểu bì nông rớm máu (Tự lành sau 3-7 ngày)',
          triageGuidance: 'Tổn thương lớp nông của da do ma sát (ngã trầy cùi chỏ, ngã xe xước đầu gối). Sơ cứu tại chỗ tốt để tránh để lại sẹo xấu.',
          dangerWarning: 'Tránh cọ xát mạnh làm rách rộng thêm vết thương. Rửa sạch đất cát bằng nước muối sinh lý.',
          steps: [
            WoundStep(1, 'Rửa sạch vết thương', 'Rửa nhẹ nhàng dưới vòi nước sạch hoặc nước muối sinh lý NaCl 0.9% để loại bỏ dị vật, bụi bẩn.'),
            WoundStep(2, 'Sát khuẩn bằng Betadine/Povidone', 'Thoa dung dịch sát khuẩn ngoài rìa vết thương, tránh đổ cồn 90 độ trực tiếp vào vết rách hở.'),
            WoundStep(3, 'Băng bảo vệ vô trùng nhẹ', 'Dùng băng cá nhân Urgo hoặc gạc mỏng che phủ để ngăn bụi bẩn bám dính.'),
            WoundStep(4, 'Kiểm tra tiêm phòng uốn ván', 'Nếu vết thương do đinh gỉ hoặc đất cát nhiễm bẩn, cần đi tiêm phòng uốn ván trong vòng 24 giờ.'),
          ],
        );
    }
  }
}

class _WoundCaseDetails {
  final String name;
  final String visualSymptoms;
  final IconData icon;
  final Color triageColor;
  final String triageCode;
  final String clinicalDiagnosis;
  final String triageGuidance;
  final String dangerWarning;
  final List<WoundStep> steps;

  _WoundCaseDetails({
    required this.name,
    required this.visualSymptoms,
    required this.icon,
    required this.triageColor,
    required this.triageCode,
    required this.clinicalDiagnosis,
    required this.triageGuidance,
    required this.dangerWarning,
    required this.steps,
  });
}

class WoundStep {
  final int number;
  final String title;
  final String detail;

  WoundStep(this.number, this.title, this.detail);
}

/// Painter vẽ khung ngắm tương tác có thể KÉO RÊ và CHẠM để chọn vùng vết thương
class InteractiveReticlePainter extends CustomPainter {
  final Rect roi;
  final Color color;
  final bool isDragging;
  final String label;

  InteractiveReticlePainter({
    required this.roi,
    required this.color,
    this.isDragging = false,
    this.label = '🎯 CHẠM / KÉO ĐẾN VẾT THƯƠNG',
  });

  @override
  void paint(Canvas canvas, Size size) {
    final left = (roi.left * size.width).clamp(4.0, size.width - 24.0);
    final top = (roi.top * size.height).clamp(4.0, size.height - 24.0);
    final right = (roi.right * size.width).clamp(left + 24.0, size.width - 4.0);
    final bottom = (roi.bottom * size.height).clamp(top + 24.0, size.height - 4.0);
    final rect = Rect.fromLTRB(left, top, right, bottom);

    // Vùng mờ nổi bật bên trong hộp
    final fillPaint = Paint()
      ..color = color.withOpacity(isDragging ? 0.16 : 0.08)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(10)), fillPaint);

    // Viền sáng bounding box
    final borderPaint = Paint()
      ..color = color.withOpacity(isDragging ? 1.0 : 0.85)
      ..strokeWidth = isDragging ? 2.5 : 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(10)), borderPaint);

    // 4 Góc ngắm định vị nổi bật (Corner Brackets)
    final cornerPaint = Paint()
      ..color = color
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final double cl = min(22.0, min(rect.width / 4, rect.height / 4));
    // Top-Left
    canvas.drawLine(Offset(rect.left, rect.top), Offset(rect.left + cl, rect.top), cornerPaint);
    canvas.drawLine(Offset(rect.left, rect.top), Offset(rect.left, rect.top + cl), cornerPaint);
    // Top-Right
    canvas.drawLine(Offset(rect.right, rect.top), Offset(rect.right - cl, rect.top), cornerPaint);
    canvas.drawLine(Offset(rect.right, rect.top), Offset(rect.right, rect.top + cl), cornerPaint);
    // Bottom-Left
    canvas.drawLine(Offset(rect.left, rect.bottom), Offset(rect.left + cl, rect.bottom), cornerPaint);
    canvas.drawLine(Offset(rect.left, rect.bottom), Offset(rect.left, rect.bottom - cl), cornerPaint);
    // Bottom-Right
    canvas.drawLine(Offset(rect.right, rect.bottom), Offset(rect.right - cl, rect.bottom), cornerPaint);
    canvas.drawLine(Offset(rect.right, rect.bottom), Offset(rect.right, rect.bottom + cl), cornerPaint);

    // Tâm chữ thập ngay chính giữa khung ngắm
    final centerPaint = Paint()
      ..color = color.withOpacity(0.85)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    final cx = rect.center.dx;
    final cy = rect.center.dy;
    const crossLen = 14.0;
    canvas.drawLine(Offset(cx - crossLen, cy), Offset(cx + crossLen, cy), centerPaint);
    canvas.drawLine(Offset(cx, cy - crossLen), Offset(cx, cy + crossLen), centerPaint);
    canvas.drawCircle(Offset(cx, cy), 5.0, centerPaint);

    // Tag nhãn nhỏ: tránh đè lên huy hiệu "ẢNH ĐÃ CHỤP" ở góc trên trái (y < 44)
    final tagBgPaint = Paint()
      ..color = color.withOpacity(0.92)
      ..style = PaintingStyle.fill;
    const tagH = 18.0;
    const tagW = 176.0;
    final bool nearTopOverlay = rect.top < 46.0;
    final double tagLeft = nearTopOverlay
        ? ((size.width - tagW) / 2.0).clamp(8.0, max(8.0, size.width - tagW - 8.0))
        : rect.left.clamp(6.0, max(6.0, size.width - tagW - 6.0));
    final double tagTop = nearTopOverlay
        ? max(38.0, rect.top + 6.0)
        : max(4.0, rect.top - tagH - 4.0);
    final tagRect = Rect.fromLTWH(tagLeft, tagTop, tagW, tagH);
    canvas.drawRRect(RRect.fromRectAndRadius(tagRect, const Radius.circular(5)), tagBgPaint);

    final textSpan = TextSpan(
      text: label,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 9.0,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.3,
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout(maxWidth: tagW - 8);
    textPainter.paint(canvas, Offset(tagRect.left + 5, tagRect.top + 2.5));
  }

  @override
  bool shouldRepaint(covariant InteractiveReticlePainter oldDelegate) => true;
}

/// Painter vẽ hộp giới hạn Bounding Box tự động nhận diện vùng vết thương (Auto-ROI)
class WoundRoiPainter extends CustomPainter {
  final Rect roi;
  final Color color;
  final String label;

  WoundRoiPainter({
    required this.roi,
    required this.color,
    this.label = 'VÙNG TỔN THƯƠNG (AUTO-ROI)',
  });

  @override
  void paint(Canvas canvas, Size size) {
    final left = (roi.left * size.width).clamp(6.0, size.width - 24.0);
    final top = (roi.top * size.height).clamp(6.0, size.height - 24.0);
    final right = (roi.right * size.width).clamp(left + 24.0, size.width - 6.0);
    final bottom = (roi.bottom * size.height).clamp(top + 24.0, size.height - 6.0);
    final rect = Rect.fromLTRB(left, top, right, bottom);

    // Vùng mờ nổi bật bên trong bounding box
    final fillPaint = Paint()
      ..color = color.withOpacity(0.08)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)), fillPaint);

    // Viền sáng bounding box
    final borderPaint = Paint()
      ..color = color.withOpacity(0.85)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)), borderPaint);

    // 4 Góc ngắm định vị (Corner Brackets)
    final cornerPaint = Paint()
      ..color = color
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke;

    final double cl = min(18.0, min(rect.width / 4, rect.height / 4));
    // Top-Left
    canvas.drawLine(Offset(rect.left, rect.top), Offset(rect.left + cl, rect.top), cornerPaint);
    canvas.drawLine(Offset(rect.left, rect.top), Offset(rect.left, rect.top + cl), cornerPaint);
    // Top-Right
    canvas.drawLine(Offset(rect.right, rect.top), Offset(rect.right - cl, rect.top), cornerPaint);
    canvas.drawLine(Offset(rect.right, rect.top), Offset(rect.right, rect.top + cl), cornerPaint);
    // Bottom-Left
    canvas.drawLine(Offset(rect.left, rect.bottom), Offset(rect.left + cl, rect.bottom), cornerPaint);
    canvas.drawLine(Offset(rect.left, rect.bottom), Offset(rect.left, rect.bottom - cl), cornerPaint);
    // Bottom-Right
    canvas.drawLine(Offset(rect.right, rect.bottom), Offset(rect.right - cl, rect.bottom), cornerPaint);
    canvas.drawLine(Offset(rect.right, rect.bottom), Offset(rect.right, rect.bottom - cl), cornerPaint);

    // Tag nhãn nhỏ phía trên hộp
    final tagBgPaint = Paint()
      ..color = color.withOpacity(0.92)
      ..style = PaintingStyle.fill;
    const tagH = 18.0;
    const tagW = 140.0;
    final tagRect = Rect.fromLTWH(rect.left, max(4.0, rect.top - tagH - 3), tagW, tagH);
    canvas.drawRRect(RRect.fromRectAndRadius(tagRect, const Radius.circular(5)), tagBgPaint);

    final textSpan = TextSpan(
      text: label,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 8.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.3,
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout(maxWidth: tagW - 8);
    textPainter.paint(canvas, Offset(tagRect.left + 5, tagRect.top + 3));
  }

  @override
  bool shouldRepaint(covariant WoundRoiPainter oldDelegate) =>
      oldDelegate.roi != roi || oldDelegate.color != color || oldDelegate.label != label;
}
