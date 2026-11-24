import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/services/device_health_service.dart';
import '../../../core/services/tts_service.dart';
import '../../../core/services/voice_bubble_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/voice_dialogue_widget.dart';
import '../domain/cpr_session_state.dart';
import '../services/cpr_camera_pose_tracker.dart';
import '../services/cpr_telemetry_batcher.dart';
import '../services/metronome_service.dart';
import '../services/pose_and_thermal_governor.dart';
import '../services/voice_command_engine.dart';
import 'cpr_handover_screen.dart';

class CPRCoachScreen extends ConsumerStatefulWidget {
  final String? clientUuid;
  final CprSessionState? initialState;

  const CPRCoachScreen({super.key, this.clientUuid, this.initialState});

  @override
  ConsumerState<CPRCoachScreen> createState() => _CPRCoachScreenState();
}

class _CPRCoachScreenState extends ConsumerState<CPRCoachScreen> with SingleTickerProviderStateMixin {
  late final String _sessionId;
  late final MetronomeService _metronomeService;
  late final PoseAndThermalGovernor _governor;
  late final VoiceCommandEngine _voiceEngine;
  CprTelemetryBatcher? _telemetryBatcher;

  late CprSessionState _state;
  Timer? _elapsedTimer;
  Timer? _batterySensorTimer;
  CameraController? _poseCameraController;
  final CprCameraPoseTracker _poseTracker = CprCameraPoseTracker();
  int _poseFrameSubsample = 0;
  bool _isSoundEnabled = true;
  bool _isVoiceCommandActive = true;
  final bool _isCall115Connected = true;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  bool _isManualTapMode = false; // False: Dẫn nhịp tự động (Metronome 110 BPM); True: Đo nhịp ép thực tế (Manual Tap)
  final List<DateTime> _manualTapTimestamps = [];
  int _manualTapBpm = 0;

  void _recordManualTapCompression() {
    final now = DateTime.now();
    _manualTapTimestamps.add(now);
    if (_manualTapTimestamps.length > 8) {
      _manualTapTimestamps.removeAt(0);
    }

    if (_manualTapTimestamps.length >= 2) {
      final intervals = <int>[];
      for (int i = 1; i < _manualTapTimestamps.length; i++) {
        intervals.add(_manualTapTimestamps[i].difference(_manualTapTimestamps[i - 1]).inMilliseconds);
      }
      final avgMs = intervals.reduce((a, b) => a + b) / intervals.length;
      if (avgMs > 0) {
        final computedBpm = (60000 / avgMs).round().clamp(40, 200);
        setState(() {
          _manualTapBpm = computedBpm;
        });
      }
    }

    // Tăng số nhịp ép thực tế
    setState(() {
      int newTotal = _state.totalCompressions + 1;
      int newInCycle;
      int newCycles = _state.totalCycles;

      if (_state.isContinuousMode) {
        newInCycle = newTotal;
      } else {
        newInCycle = _state.currentCompressionInCycle + 1;
        if (newInCycle >= 30) {
          newInCycle = 0;
          newCycles++;
          if (_isSoundEnabled) {
            TtsService.speak('Thổi ngạt 2 nhịp');
          }
        }
      }

      _state = _state.copyWith(
        totalCompressions: newTotal,
        currentCompressionInCycle: newInCycle,
        totalCycles: newCycles,
        isRunning: true,
      );
    });

    if (!_pulseController.isAnimating) {
      _pulseController.forward(from: 0.0).then((_) {
        if (mounted) _pulseController.reverse();
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _sessionId = widget.clientUuid ?? const Uuid().v4();
    _state = widget.initialState ?? const CprSessionState();

    _metronomeService = MetronomeService();
    _governor = PoseAndThermalGovernor();
    _voiceEngine = VoiceCommandEngine();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 545), // ~110 BPM (60,000 / 110 ≈ 545ms)
    );
    _pulseAnimation = Tween<double>(begin: 0.94, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _metronomeService.configure(
      soundEnabled: _isSoundEnabled,
      hapticEnabled: true,
      onBeat: (beatIndex, jitterMs) {
        if (!mounted) return;
        setState(() {
          int newTotal = _state.totalCompressions + 1;
          int newInCycle;
          int newCycles = _state.totalCycles;

          if (_state.isContinuousMode) {
            newInCycle = newTotal;
          } else {
            newInCycle = _state.currentCompressionInCycle + 1;
            if (newInCycle >= 30) {
              newInCycle = 0;
              newCycles++;
              if (_isSoundEnabled) {
                TtsService.speak('Thổi ngạt 2 nhịp');
              }
            }
          }

          _state = _state.copyWith(
            totalCompressions: newTotal,
            currentCompressionInCycle: newInCycle,
            totalCycles: newCycles,
            lastJitterMs: jitterMs,
          );
        });
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final db = ref.read(databaseProvider);
      _telemetryBatcher = CprTelemetryBatcher(database: db, clientUuid: _sessionId);
      _telemetryBatcher!.startBatching(() => _state);
      _startCpr();
      if (!Platform.environment.containsKey('FLUTTER_TEST')) {
        DeviceHealthService.setKeepScreenOn(true);
        _initHardwareSensorsAndPoseCamera();
      }
    });
  }

  Future<void> _initHardwareSensorsAndPoseCamera() async {
    // 1. Đọc nhiệt độ pin thực tế từ Android BatteryManager mỗi 5 giây
    final initialTemp = await DeviceHealthService.getBatteryTemperatureC();
    if (mounted) updateBatteryTemperature(initialTemp);

    _batterySensorTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      final temp = await DeviceHealthService.getBatteryTemperatureC();
      if (mounted) updateBatteryTemperature(temp);
    });

    // 2. Mở camera góc rộng/trước để đo góc khuỷu tay & nhịp nhún thực tế nếu nhiệt độ cho phép
    if (!_state.isCameraPreviewActive) return;
    try {
      final cams = await availableCameras();
      if (cams.isEmpty) return;
      final frontCam = cams.where((c) => c.lensDirection == CameraLensDirection.front).toList();
      final chosen = frontCam.isNotEmpty ? frontCam.first : cams.first;
      final ctrl = CameraController(chosen, ResolutionPreset.low, enableAudio: false);
      await ctrl.initialize();
      if (!mounted) {
        await ctrl.dispose();
        return;
      }
      _poseCameraController = ctrl;
      await ctrl.startImageStream((CameraImage img) {
        if (!mounted || !_state.isRunning || !_state.isCameraPreviewActive) return;
        _poseFrameSubsample++;
        final stride = _state.currentFps <= 15 ? 4 : 2;
        if (_poseFrameSubsample % stride != 0) return;

        final res = _poseTracker.processCameraFrame(img);
        if (res.motionConfidence > 0.15) {
          updateElbowAngle(res.elbowAngleDeg);
        }
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    DeviceHealthService.setKeepScreenOn(false);
    _batterySensorTimer?.cancel();
    _poseCameraController?.dispose();
    _metronomeService.stop();
    _elapsedTimer?.cancel();
    _telemetryBatcher?.stop();
    _pulseController.dispose();
    super.dispose();
  }

  void _startCpr() {
    if (_state.isRunning) return;
    setState(() {
      _state = _state.copyWith(isRunning: true);
    });

    _pulseController.repeat(reverse: true);
    _metronomeService.start();

    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _state = _state.copyWith(
          elapsedSeconds: _state.elapsedSeconds + 1,
          activeCompressionSeconds: _state.isRunning
              ? _state.activeCompressionSeconds + 1
              : _state.activeCompressionSeconds,
        );
      });
    });

    if (_isSoundEnabled) {
      TtsService.speak('Bắt đầu ép tim 110 nhịp một phút. Khóa thẳng khuỷu tay.');
    }
  }

  void _stopCpr() {
    _metronomeService.stop();
    _elapsedTimer?.cancel();
    _pulseController.stop();
    setState(() {
      _state = _state.copyWith(
        isRunning: false,
        pauseCount: _state.pauseCount + 1,
      );
    });
  }

  void _toggleCpr() {
    if (_state.isRunning) {
      _stopCpr();
    } else {
      _startCpr();
    }
  }

  void _resetCpr() {
    _stopCpr();
    _metronomeService.reset();
    setState(() {
      _state = _state.copyWith(
        currentCompressionInCycle: 0,
        totalCompressions: 0,
        totalCycles: 0,
        elapsedSeconds: 0,
        activeCompressionSeconds: 0,
        pauseCount: 0,
      );
    });
  }

  /// Xử lý khẩu lệnh giọng nói 5 từ khóa
  void handleVoiceUtterance(String text) {
    if (!_isVoiceCommandActive) return;
    final result = _voiceEngine.processUtterance(text);
    if (!result.isExecuted) return;

    switch (result.action) {
      case CprVoiceAction.start:
      case CprVoiceAction.resume:
        if (!_state.isRunning) _startCpr();
        break;
      case CprVoiceAction.pause:
        if (_state.isRunning) _stopCpr();
        break;
      case CprVoiceAction.toggleSpeaker:
        setState(() {
          _isSoundEnabled = !_isSoundEnabled;
          _metronomeService.configure(soundEnabled: _isSoundEnabled);
        });
        break;
      case CprVoiceAction.handover:
        _finishAndHandover();
        break;
      case CprVoiceAction.unknown:
        break;
    }
  }

  /// Cập nhật góc khuỷu tay mô phỏng/thực tế từ MoveNet
  void updateElbowAngle(double angleDeg) {
    final quality = _governor.evaluatePosture(angleDeg);
    setState(() {
      _state = _state.copyWith(
        elbowAngleDeg: angleDeg,
        postureQuality: quality,
      );
    });
    _governor.handlePostureVoicePrompt(quality);
  }

  /// Cập nhật nhiệt độ pin thiết bị để kích hoạt Thermal Throttling
  void updateBatteryTemperature(double tempC) {
    final eval = _governor.evaluateThermalState(tempC);
    setState(() {
      _state = _state.copyWith(
        temperatureC: tempC,
        currentFps: eval.fps,
        thermalState: eval.state,
        isCameraPreviewActive: eval.isCameraPreviewActive,
      );
    });
    if (eval.warningMessage != null) {
      TtsService.speak(eval.warningMessage!);
    }
  }

  void _showAedGuide() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.bolt_rounded, color: Colors.amber, size: 28),
                  SizedBox(width: 10),
                  Text(
                    'HƯỚNG DẪN DÙNG MÁY AED',
                    style: TextStyle(fontFamily: 'Roboto', color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                ],
              ),
              const Divider(color: Colors.white24, height: 24),
              const Text('1. Mở nắp máy AED (Máy sẽ tự phát âm thanh hướng dẫn).', style: TextStyle(color: Colors.white, fontSize: 13)),
              const SizedBox(height: 6),
              const Text('2. Bóc và dán 2 bản cực: Bản 1 dưới xương đòn phải, bản 2 dưới nách trái.', style: TextStyle(color: Colors.white, fontSize: 13)),
              const SizedBox(height: 6),
              const Text('3. Hô to: "Tránh xa nạn nhân" khi máy đang phân tích nhịp tim.', style: TextStyle(color: Colors.orangeAccent, fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text('4. Bấm nút SỐC (Shock) nếu máy yêu cầu. Tiếp tục ép tim ngay sau đó.', style: TextStyle(color: Colors.white, fontSize: 13)),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emergencyRed),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('ĐÃ HIỂU, TIẾP TỤC ÉP TIM', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPostureGuide() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          expand: false,
          builder: (_, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    children: [
                      Icon(Icons.accessibility_new_rounded, color: Color(0xFF38BDF8), size: 26),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'TƯ THẾ ÉP TIM CHUẨN AHA 2025',
                          style: TextStyle(fontFamily: 'Roboto', color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white24, height: 20),

                  // Graphic Diagram
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.5)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildPosturePoint('1. VỊ TRÍ', '1/2 Dưới Xương Ức', Icons.place_rounded, const Color(0xFFEF4444)),
                            _buildPosturePoint('2. TAY', 'Khóa thẳng 90°', Icons.straighten_rounded, const Color(0xFF38BDF8)),
                            _buildPosturePoint('3. ĐỘ SÂU', '5 - 6 cm', Icons.vertical_align_bottom_rounded, const Color(0xFF4ADE80)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline, color: Color(0xFF38BDF8), size: 18),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Dùng sức nặng nửa thân trên nhún xuống, không gập khuỷu tay. Để ngực nở hoàn toàn sau mỗi lần ép.',
                                  style: TextStyle(color: Colors.white, fontSize: 11.5, height: 1.35),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  const Text('5 QUY TẮC VÀNG KHI ÉP TIM:', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  _buildPostureStep('1', 'Đặt nạn nhân nằm ngửa trên nền phẳng cứng (không ép trên nệm mềm).'),
                  _buildPostureStep('2', 'Quỳ sát cạnh ngực, đặt gót một bàn tay vào chính giữa 1/2 dưới xương ức.'),
                  _buildPostureStep('3', 'Đặt bàn tay kia đan lên trên, các ngón tay nâng lên không tỳ vào sườn.'),
                  _buildPostureStep('4', 'Hai cánh tay thẳng tuyệt đối (góc 90°), vai thẳng trục với bàn tay.'),
                  _buildPostureStep('5', 'Ép liên tục theo nhịp 110 lần/phút của âm thanh máy, sâu 5-6 cm.'),

                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('ĐÃ RÕ TƯ THẾ — TIẾP TỤC ÉP TIM', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showVoiceDialogueModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            top: 16,
            left: 16,
            right: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 12),
              const Row(
                children: [
                  Icon(Icons.record_voice_over_rounded, color: Color(0xFF38BDF8), size: 22),
                  SizedBox(width: 8),
                  Text(
                    'ĐỐI THOẠI RẢNH TAY 2 CHIỀU (CPR COCKPIT)',
                    style: TextStyle(fontFamily: 'Roboto', color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13.5),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const VoiceDialogueWidget(
                contextHint: 'CPR Coach - Ép tim 110 BPM & Đo nhịp tim',
                suggestedPrompts: [
                  'Nạn nhân có mạch lại rồi',
                  'Mỏi tay quá xử lý sao?',
                  'Tư thế tay đã đúng chưa?',
                  'Độ sâu ép tim bao nhiêu?',
                  'Đã có máy AED rồi',
                  'Nhịp tim chuẩn bao nhiêu?',
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPosturePoint(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 9.5, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800)),
      ],
    );
  }

  Widget _buildPostureStep(String num, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF1E293B)),
            alignment: Alignment.center,
            child: Text(num, style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(desc, style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 12, height: 1.35)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleBackPress() async {
    if (!_state.isRunning) {
      if (mounted) Navigator.pop(context);
      return;
    }
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444)),
            SizedBox(width: 8),
            Text(
              'Tạm dừng phiên CPR?',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: const Text(
          'Nạn nhân đang cần ép tim liên tục không gián đoạn quá 10 giây (theo khuyến nghị AHA). Bạn có chắc muốn tạm dừng phiên cấp cứu?',
          style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('TIẾP TỤC ÉP TIM', style: TextStyle(color: Color(0xFF4ADE80), fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () {
              _stopCpr();
              Navigator.pop(ctx, true);
            },
            child: const Text('TẠM DỪNG & RỜI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (shouldLeave == true && mounted) {
      Navigator.pop(context);
    }
  }

  void _finishAndHandover() {
    _stopCpr();
    _telemetryBatcher?.recordTelemetryBatch(_state); // Ghi nhận batch chốt cuối ca
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CPRHandoverScreen(
          totalCompressions: _state.totalCompressions,
          elapsedSeconds: _state.elapsedSeconds,
          ccfPercentage: _state.ccfPercentage,
          pauseCount: _state.pauseCount,
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final ccf = _state.ccfPercentage;
    final isPostureWarning = _state.postureQuality == PostureQuality.elbowBent;
    final isThermalCritical = _state.thermalState == ThermalState.critical;

    return PopScope(
      canPop: !_state.isRunning,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleBackPress();
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.amoledBlack,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleBackPress,
            tooltip: 'Quay lại',
          ),
          title: Row(
            children: [
              const Icon(Icons.favorite, color: AppTheme.emergencyRed, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isThermalCritical
                      ? 'CPR (TIẾT KIỆM PIN)'
                      : 'CPR (AHA)',
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14.0,
                    letterSpacing: 0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.graphic_eq_rounded, color: Color(0xFF38BDF8)),
              tooltip: 'Bác sĩ AI Giọng nói (Bong bóng nổi PiP)',
              onPressed: () {
                VoiceBubbleController().startLiveSession(contextHint: 'CPR_COCKPIT', startMinimized: true);
              },
            ),
            IconButton(
              icon: const Icon(Icons.record_voice_over_rounded, color: Color(0xFF38BDF8)),
              tooltip: 'Đối thoại giọng nói 2 chiều rảnh tay',
              onPressed: _showVoiceDialogueModal,
            ),
            IconButton(
              icon: const Icon(Icons.accessibility_new_rounded, color: Color(0xFF38BDF8)),
              tooltip: 'Xem tư thế ép tim chuẩn AHA',
              onPressed: _showPostureGuide,
            ),
            IconButton(
              icon: Icon(
                _isSoundEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                color: _isSoundEnabled ? AppTheme.safeGreen : Colors.white38,
              ),
              tooltip: 'Âm thanh nhịp đập',
              onPressed: () {
                setState(() {
                  _isSoundEnabled = !_isSoundEnabled;
                  _metronomeService.configure(soundEnabled: _isSoundEnabled);
                });
              },
            ),
          ],
        ),
      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            border: isPostureWarning
                ? Border.all(color: Colors.redAccent, width: 3.5)
                : null,
          ),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      // CẢNH BÁO TƯ THẾ HOẶC NHIỆT ĐỘ
              if (isPostureWarning)
                Container(
                  width: double.infinity,
                  color: Colors.red.shade900,
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'CẢNH BÁO TƯ THẾ: Khóa thẳng khuỷu tay! (Rate-limit: 1 câu/5s)',
                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

              if (isThermalCritical)
                Container(
                  width: double.infinity,
                  color: Colors.amber.shade900,
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.thermostat_rounded, color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'NHIỆT ĐỘ CAO (≥45°C): Tắt camera bảo vệ máy. Tiếp tục ép tim!',
                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

              // DẢI TRẠNG THÁI CỐ ĐỊNH: ĐÃ GỌI 115 & NÚT CÓ MÁY AED
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF131D31),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF24324D)),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isCall115Connected ? Icons.phone_in_talk_rounded : Icons.phone_missed_rounded,
                      color: _isCall115Connected ? const Color(0xFF4ADE80) : Colors.orangeAccent,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _isCall115Connected ? 'Đã gọi 115 (Loa ngoài bật)' : 'Chưa kết nối 115',
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          color: _isCall115Connected ? const Color(0xFF4ADE80) : Colors.orangeAccent,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    InkWell(
                      onTap: _showAedGuide,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.withAlpha(40),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.shade700),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.bolt, color: Colors.amberAccent, size: 14),
                            SizedBox(width: 4),
                            Text(
                              'CÓ MÁY AED',
                              style: TextStyle(fontFamily: 'Roboto', color: Colors.amberAccent, fontSize: 10.5, fontWeight: FontWeight.w900),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // BANNER: HƯỚNG DẪN KHỬ RUNG TIM AED (CHUẨN AHA/ILCOR 2025 BLS)
              // Tuyệt đối không dừng ép tim để bắt mạch hay đo camera; AED là thiết bị duy nhất phân tích nhịp tim
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.6)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.bolt_rounded, color: Color(0xFFF59E0B), size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CHUẨN BỊ MÁY KHỬ RUNG TIM (AED)',
                            style: TextStyle(fontFamily: 'Roboto', color: Color(0xFFFDE68A), fontSize: 11.5, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Tiếp tục ép tim liên tục. Khi có AED, dán điện cực và làm theo lệnh máy (Không dừng ép tim để bắt mạch)',
                            style: TextStyle(fontFamily: 'Roboto', color: Color(0xFF94A3B8), fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Top HUD: Thước đo Thời gian, CCF (Ghi rõ "Ước lượng"), Gián đoạn
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.darkSlateCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.darkSlateBorder),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'THỜI GIAN ÉP',
                            style: TextStyle(fontFamily: 'Roboto', color: AppTheme.darkTextSecondary, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            _formatDuration(_state.elapsedSeconds),
                            style: const TextStyle(
                              fontFamily: 'Roboto',
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            'Gián đoạn: ${_state.pauseCount} lần',
                            style: const TextStyle(fontFamily: 'Roboto', color: Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 38, color: AppTheme.darkSlateBorder),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'CCF (ƯỚC LƯỢNG)',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontFamily: 'Roboto', color: AppTheme.darkTextSecondary, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: ccf >= 60 ? Colors.green.withAlpha(50) : Colors.amber.withAlpha(50),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  ccf >= 60 ? 'ĐẠT' : 'TĂNG LỰC',
                                  style: TextStyle(
                                    fontFamily: 'Roboto',
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.bold,
                                    color: ccf >= 60 ? Colors.lightGreenAccent : Colors.orangeAccent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '${ccf.toStringAsFixed(0)}% (Chuẩn ≥60%)',
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              color: ccf >= 60 ? Colors.lightGreenAccent : Colors.orangeAccent,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            'Jitter: ${_state.lastJitterMs.toStringAsFixed(1)}ms (≤5ms)',
                            style: const TextStyle(fontFamily: 'Roboto', color: Color(0xFF64748B), fontSize: 9.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // CHỌN PHƯƠNG THỨC: DẪN NHỊP METRONOME 110 BPM VS ĐO NHỊP ÉP THỰC TẾ
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF131D31),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF24324D)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (_isManualTapMode) {
                            setState(() => _isManualTapMode = false);
                            if (!_state.isRunning) _startCpr();
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          decoration: BoxDecoration(
                            color: !_isManualTapMode ? const Color(0xFFDC2626) : Colors.transparent,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.volume_up_rounded, size: 14, color: !_isManualTapMode ? Colors.white : Colors.white60),
                              const SizedBox(width: 4),
                              Text(
                                'Dẫn nhịp 110 BPM',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'Roboto',
                                  color: !_isManualTapMode ? Colors.white : Colors.white60,
                                  fontSize: 11,
                                  fontWeight: !_isManualTapMode ? FontWeight.w800 : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (!_isManualTapMode) {
                            _stopCpr();
                            setState(() => _isManualTapMode = true);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          decoration: BoxDecoration(
                            color: _isManualTapMode ? const Color(0xFF0284C7) : Colors.transparent,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.touch_app_rounded, size: 14, color: _isManualTapMode ? Colors.white : Colors.white60),
                              const SizedBox(width: 4),
                              Text(
                                'Đo nhịp ép thực tế',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'Roboto',
                                  color: _isManualTapMode ? Colors.white : Colors.white60,
                                  fontSize: 11,
                                  fontWeight: _isManualTapMode ? FontWeight.w800 : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // CHUYỂN CHẾ ĐỘ: LIÊN TỤC (HANDS-ONLY) VS 30:2
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF131D31),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _state = _state.copyWith(isContinuousMode: true)),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          decoration: BoxDecoration(
                            color: _state.isContinuousMode ? const Color(0xFF334155) : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Ép liên tục (Phổ thông)',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: _state.isContinuousMode ? FontWeight.w800 : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _state = _state.copyWith(isContinuousMode: false)),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          decoration: BoxDecoration(
                            color: !_state.isContinuousMode ? const Color(0xFF334155) : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Tỉ lệ 30:2 (Ngạt nước)',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: !_state.isContinuousMode ? FontWeight.w800 : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Visual Center: Pulsing Metronome Orb & Beat Count
              ScaleTransition(
                scale: _pulseAnimation,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _state.isRunning
                              ? (_isManualTapMode ? const Color(0xFF38BDF8).withAlpha(80) : AppTheme.emergencyRed.withAlpha(70))
                              : Colors.white10,
                          width: 4,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: _isManualTapMode ? _recordManualTapCompression : _toggleCpr,
                      child: Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: _state.isRunning
                                ? (_isManualTapMode
                                    ? [const Color(0xFF38BDF8), const Color(0xFF0369A1)]
                                    : [const Color(0xFFFF5252), AppTheme.emergencyDarkRed])
                                : [const Color(0xFF334155), const Color(0xFF1E293B)],
                          ),
                          boxShadow: [
                            if (_state.isRunning)
                              BoxShadow(
                                color: (_isManualTapMode ? const Color(0xFF38BDF8) : AppTheme.emergencyRed).withAlpha(120),
                                blurRadius: 30,
                                spreadRadius: 6,
                              ),
                          ],
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _state.isRunning
                                    ? '${_state.currentCompressionInCycle}'
                                    : (_isManualTapMode ? 'CHẠM ÉP' : 'BẮT ĐẦU'),
                                style: TextStyle(
                                  fontFamily: 'Roboto',
                                  color: Colors.white,
                                  fontSize: _state.isRunning ? 50 : 20,
                                  fontWeight: FontWeight.w900,
                                  height: 1.0,
                                ),
                              ),
                              if (_state.isRunning)
                                Text(
                                  _state.isContinuousMode ? 'TỔNG NHỊP ÉP' : '/ 30 NHỊP',
                                  style: const TextStyle(fontFamily: 'Roboto', color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.bold),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // BẢNG BÁO TỐC ĐỘ ÉP THỰC TẾ CHO CHẾ ĐỘ THỦ CÔNG
              if (_isManualTapMode) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _manualTapBpm >= 100 && _manualTapBpm <= 120
                          ? Colors.greenAccent
                          : (_manualTapBpm > 0 ? Colors.amber : const Color(0xFF38BDF8)),
                    ),
                  ),
                  child: Text(
                    _manualTapBpm > 0
                        ? (_manualTapBpm < 100
                            ? '⚠️ Tốc độ của bạn: $_manualTapBpm BPM (Hơi chậm! Mục tiêu 100-120)'
                            : (_manualTapBpm > 120
                                ? '⚠️ Tốc độ của bạn: $_manualTapBpm BPM (Quá nhanh! Hãy chậm lại)'
                                : '✅ Tốc độ của bạn: $_manualTapBpm BPM (Chuẩn AHA 2025!)'))
                        : '👉 Chạm liên tục vào nút tròn theo từng nhịp ép tim thật',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      color: _manualTapBpm >= 100 && _manualTapBpm <= 120
                          ? Colors.greenAccent
                          : (_manualTapBpm > 0 ? Colors.amberAccent : const Color(0xFF38BDF8)),
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 14),

              // CLINICAL DEPTH GUIDANCE & PHẦN CỨNG
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.darkSlateCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.darkSlateBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.speed, color: AppTheme.medicalBlue, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Độ sâu: ${_state.estimatedDepthCm.toStringAsFixed(1)} cm (Ước lượng AI ±1cm)',
                            style: const TextStyle(fontFamily: 'Roboto', color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
                          ),
                          Text(
                            isThermalCritical
                                ? 'AI MoveNet: Đã tắt (Bảo vệ nhiệt)'
                                : 'Góc tay MoveNet: ${_state.elbowAngleDeg.toStringAsFixed(0)}° • ${isPostureWarning ? "CONG TAY (CẢNH BÁO)" : "Chuẩn 90°"}',
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              color: isPostureWarning ? Colors.redAccent : const Color(0xFF94A3B8),
                              fontSize: 10.5,
                              fontWeight: isPostureWarning ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isThermalCritical
                            ? Colors.red.withAlpha(40)
                            : Colors.green.withAlpha(30),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${_state.temperatureC.toStringAsFixed(1)}°C • ${_state.currentFps}fps',
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          color: isThermalCritical ? Colors.redAccent : const Color(0xFF4ADE80),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 6),

              // ĐỐI THOẠI RẢNH TAY 2 CHIỀU (VOICE AI ASSISTANT)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFF131D31),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF0284C7).withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.record_voice_over_rounded, color: Color(0xFF38BDF8), size: 16),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ĐỐI THOẠI RẢNH TAY 2 CHIỀU',
                            style: TextStyle(fontFamily: 'Roboto', color: Color(0xFF38BDF8), fontSize: 10.5, fontWeight: FontWeight.w800),
                          ),
                          Text(
                            'Nói trực tiếp: "Mỏi tay", "Nạn nhân tỉnh", "Tư thế đúng chưa"',
                            style: TextStyle(fontFamily: 'Roboto', color: Color(0xFF94A3B8), fontSize: 9.5),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: _showVoiceDialogueModal,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284C7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.mic_rounded, color: Colors.white, size: 14),
                            SizedBox(width: 4),
                            Text('MỞ MIC', style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
                    ],
                  ),
                ),
              ),

              // Bottom Action Controls + NÚT BÀN GIAO Y TẾ
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _state.isRunning ? const Color(0xFF334155) : AppTheme.emergencyRed,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: _toggleCpr,
                            icon: Icon(_state.isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 22),
                            label: Text(
                              _state.isRunning ? 'TẠM DỪNG' : 'TIẾP TỤC ÉP TIM',
                              style: const TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w800, fontSize: 14),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        IconButton.filled(
                          style: IconButton.styleFrom(
                            backgroundColor: AppTheme.darkSlateCard,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.all(14),
                          ),
                          onPressed: _resetCpr,
                          icon: const Icon(Icons.refresh_rounded, size: 20),
                          tooltip: 'Thiết lập lại đếm nhịp',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // NÚT KẾT THÚC CA & BÀN GIAO CHO KÍP 115
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: _finishAndHandover,
                        icon: const Icon(Icons.handshake_rounded, size: 20),
                        label: const Text(
                          'XE 115 ĐÃ ĐẾN → KẾT THÚC & BÀN GIAO',
                          style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w900, fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }
}
