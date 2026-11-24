import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' as drift;
import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/tts_service.dart';
import '../../../core/services/demo_mode_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../dispatcher/services/dispatcher_realtime_service.dart';
import '../data/sos_payload.dart';

class EmergencySosScreen extends ConsumerStatefulWidget {
  final bool autoTriggerCpr;

  const EmergencySosScreen({super.key, this.autoTriggerCpr = false});

  @override
  ConsumerState<EmergencySosScreen> createState() => _EmergencySosScreenState();
}

class _EmergencySosScreenState extends ConsumerState<EmergencySosScreen> {
  int _currentStep = 0; // 0: An toàn hiện trường, 1: Phản ứng, 2: Nhịp thở 10s
  int _breathingCountdown = 10;
  Timer? _countdownTimer;
  bool _isCountdownRunning = false;
  bool _isTriggering = false;
  String? _statusLog;
  String? _clientUuid;
  LocationData? _currentLocation;
  int _dbWriteMs = 0;
  int _p0ByteSize = 0;

  @override
  void initState() {
    super.initState();
    if (widget.autoTriggerCpr) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _triggerEmergencySos('CARDIAC_ARREST');
      });
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startBreathingTimer() {
    setState(() {
      _breathingCountdown = 10;
      _isCountdownRunning = true;
    });
    TtsService.speak('Quan sát lồng ngực nạn nhân trong 10 giây xem có phập phồng không.');
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_breathingCountdown > 0) {
          _breathingCountdown--;
        } else {
          _isCountdownRunning = false;
          _countdownTimer?.cancel();
        }
      });
    });
  }

  Future<void> _triggerEmergencySos(String incidentType) async {
    setState(() {
      _isTriggering = true;
      _statusLog = 'Đang kích hoạt P0 SOS... Lấy tọa độ GPS...';
    });

    try {
      final location = await LocationService.getCurrentLocation();
      final uuid = const Uuid().v4();
      final isDemo = ref.read(demoModeProvider);

      setState(() {
        _currentLocation = location;
        _clientUuid = uuid;
      });

      final p0 = SosPayloadP0(
        clientUuid: uuid,
        deviceId: 'anon_dev_${uuid.substring(0, 8)}',
        createdAt: DateTime.now(),
        incidentType: incidentType,
        location: location,
        isDemo: isDemo,
      );

      final p0Json = p0.toJsonString();
      _p0ByteSize = p0.byteSize;

      final db = ref.read(databaseProvider);
      final stopwatch = Stopwatch()..start();
      await db.insertOutboxEvent(
        OutboxEventsCompanion(
          id: drift.Value(uuid),
          eventType: const drift.Value('SOS_TRIGGERED'),
          priority: const drift.Value(0),
          payloadJson: drift.Value(p0Json),
          status: const drift.Value('PENDING'),
          createdAt: drift.Value(DateTime.now()),
        ),
      );
      stopwatch.stop();
      _dbWriteMs = stopwatch.elapsedMilliseconds;

      final phone = await DemoModeService.getEmergencyPhone();
      DispatcherRealtimeService.shared.registerLiveSosIncident(
        clientUuid: uuid,
        incidentType: incidentType,
        lat: location.lat,
        lng: location.lng,
        callerPhone: phone,
      );

      setState(() {
        _statusLog = 'Đã lưu Outbox ($_dbWriteMs ms, $_p0ByteSize bytes).\nĐang phát loa ngoài & kết nối 115...';
      });

      await TtsService.speak('Đã gửi tọa độ cấp cứu 115. Bắt đầu ép tim ngay.');

      final uri = Uri.parse('tel:$phone');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã hoàn tất gửi tin khẩn cấp SOS và kết nối cuộc gọi 115.'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _statusLog = 'Lỗi kích hoạt: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isTriggering = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('ĐÁNH GIÁ CẤP CỨU (3 BƯỚC)'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // STEPPER PROGRESS BAR (3 BƯỚC)
            Row(
              children: [
                _buildStepIndicator(0, '1. An toàn', _currentStep >= 0),
                Expanded(child: Container(height: 2, color: _currentStep >= 1 ? AppTheme.emergencyRed : const Color(0xFFCBD5E1))),
                _buildStepIndicator(1, '2. Phản xạ', _currentStep >= 1),
                Expanded(child: Container(height: 2, color: _currentStep >= 2 ? AppTheme.emergencyRed : const Color(0xFFCBD5E1))),
                _buildStepIndicator(2, '3. Nhịp thở', _currentStep >= 2),
              ],
            ),

            const SizedBox(height: 18),

            // BƯỚC 1: AN TOÀN HIỆN TRƯỜNG
            if (_currentStep == 0) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 24),
                        SizedBox(width: 8),
                        Text(
                          'BƯỚC 1: AN TOÀN HIỆN TRƯỜNG',
                          style: TextStyle(fontFamily: 'Roboto', fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Quan sát nhanh xung quanh: Có điện giật, cháy nổ, tường sập, khói độc hoặc xe cộ đang lao tới không?',
                      style: TextStyle(fontFamily: 'Roboto', fontSize: 13, height: 1.4, color: Color(0xFF334155)),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'CẢNH BÁO: Nếu hiện trường không an toàn, KHÔNG lao vào. Hãy đứng từ xa gọi 115 và 114 hỗ trợ.',
                        style: TextStyle(fontFamily: 'Roboto', fontSize: 11.5, color: Color(0xFF991B1B), fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  setState(() => _currentStep = 1);
                },
                icon: const Icon(Icons.check_circle_outline, size: 20),
                label: const Text('HIỆN TRƯỜNG AN TOÀN → TIẾP TỤC', style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w800)),
              ),
            ],

            // BƯỚC 2: KIỂM TRA PHẢN ỨNG
            if (_currentStep == 1) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.pan_tool_rounded, color: Color(0xFF0284C7), size: 24),
                        SizedBox(width: 8),
                        Text(
                          'BƯỚC 2: KIỂM TRA PHẢN ỨNG',
                          style: TextStyle(fontFamily: 'Roboto', fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Vỗ mạnh vào hai vai nạn nhân và gọi to bên tai: "Anh/Chị có sao không?!".',
                      style: TextStyle(fontFamily: 'Roboto', fontSize: 13, height: 1.4, color: Color(0xFF334155)),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Quan sát xem nạn nhân có cử động, mở mắt hoặc trả lời không.',
                      style: TextStyle(fontFamily: 'Roboto', fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                      onPressed: () => setState(() => _currentStep = 0),
                      child: const Text('← QUAY LẠI', style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.emergencyRed,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () {
                        setState(() => _currentStep = 2);
                        _startBreathingTimer();
                      },
                      child: const Text('BẤT TỈNH, KHÔNG PHẢN XẠ →', style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            ],

            // BƯỚC 3: KIỂM TRA NHỊP THỞ (ĐẾM 10S)
            if (_currentStep == 2) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    const Text(
                      'BƯỚC 3: QUAN SÁT LỒNG NGỰC (TỐI ĐA 10 GIÂY)',
                      style: TextStyle(fontFamily: 'Roboto', fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 14),

                    // Countdown Display
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _breathingCountdown > 0 ? const Color(0xFFFEF2F2) : const Color(0xFFDC2626),
                        border: Border.all(color: AppTheme.emergencyRed, width: 3),
                      ),
                      child: Center(
                        child: Text(
                          '${_breathingCountdown}s',
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: _breathingCountdown > 0 ? AppTheme.emergencyRed : Colors.white,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),
                    const Text(
                      'Ngửa nhẹ đầu, nâng cằm. Ghé tai sát mũi nạn nhân và nhìn lồng ngực xem có phập phồng không.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: 'Roboto', fontSize: 12.5, color: Color(0xFF475569), height: 1.35),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Hai Nút Quyết định
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.emergencyRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _isTriggering ? null : () => _triggerEmergencySos('CARDIAC_ARREST'),
                icon: const Icon(Icons.favorite, size: 22),
                label: _isTriggering
                    ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 3)
                    : const Text(
                        'KHÔNG THỞ / THỞ NGÁP CÁ → ÉP TIM NGAY',
                        style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w900, fontSize: 13.5),
                      ),
              ),

              const SizedBox(height: 10),

              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: Color(0xFF16A34A), width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Nạn nhân còn thở: Đặt nằm nghiêng an toàn và theo dõi sát.')),
                  );
                },
                icon: const Icon(Icons.check, color: Color(0xFF16A34A)),
                label: const Text(
                  'CÒN THỞ BÌNH THƯỜNG → NẰM NGHIÊNG AN TOÀN',
                  style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w800, color: Color(0xFF15803D), fontSize: 12.5),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator(int stepIndex, String label, bool isActive) {
    return Column(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: isActive ? AppTheme.emergencyRed : const Color(0xFFE2E8F0),
          child: Text(
            '${stepIndex + 1}',
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isActive ? Colors.white : const Color(0xFF64748B),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 10.5,
            fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
            color: isActive ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }
}
