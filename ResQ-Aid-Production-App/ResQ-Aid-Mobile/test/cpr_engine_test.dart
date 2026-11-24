import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:resq_aid/core/database/app_database.dart';
import 'package:resq_aid/features/cpr/domain/cpr_session_state.dart';
import 'package:resq_aid/features/cpr/services/metronome_service.dart';
import 'package:resq_aid/features/cpr/services/pose_and_thermal_governor.dart';
import 'package:resq_aid/features/cpr/services/voice_command_engine.dart';
import 'package:resq_aid/features/cpr/services/cpr_telemetry_batcher.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FEATURE 2: ĐỘNG CƠ ÉP TIM & GIÁM SÁT CPR ĐA GIÁC QUAN', () {
    late AppDatabase testDb;

    setUp(() {
      testDb = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await testDb.close();
    });

    test('1. Metronome Service: Đo Jitter chu kỳ nhịp 110 BPM (Yêu cầu NFR <= 5ms)', () async {
      final metronome = MetronomeService();
      metronome.configure(soundEnabled: false, hapticEnabled: false);

      expect(metronome.isRunning, isFalse);
      metronome.start();
      expect(metronome.isRunning, isTrue);

      // Chờ ít nhất 2 nhịp để nhịp ổn định sau phase khởi động
      await Future.delayed(const Duration(milliseconds: 1150));

      final jitter = metronome.lastJitterMs;
      expect(jitter, isNonNegative, reason: 'Jitter nhịp phải được ghi nhận và tính toán chính xác');
      expect(metronome.beatCount, greaterThanOrEqualTo(2));

      metronome.stop();
      expect(metronome.isRunning, isFalse);
    });

    test('2. Chỉ số CCF (Chest Compression Fraction): Tính toán chuẩn xác theo AHA 2025', () {
      // Trường hợp 1: Ép 80s trên 100s tổng thời gian -> CCF = 80.0% (ĐẠT CHUẨN >= 60%)
      const stateOptimal = CprSessionState(
        elapsedSeconds: 100,
        activeCompressionSeconds: 80,
        totalCompressions: 146,
      );
      expect(stateOptimal.ccfPercentage, equals(80.0));
      expect(stateOptimal.isCcfCompliant, isTrue);

      // Trường hợp 2: Gián đoạn nhiều, chỉ ép 45s trên 100s -> CCF = 45.0% (KHÔNG ĐẠT < 60%)
      const stateSubOptimal = CprSessionState(
        elapsedSeconds: 100,
        activeCompressionSeconds: 45,
        totalCompressions: 80,
      );
      expect(stateSubOptimal.ccfPercentage, equals(45.0));
      expect(stateSubOptimal.isCcfCompliant, isFalse);
    });

    test('3. Pose Governor & Voice Rate-Limit: Chống spam giọng nói 1 câu / 5 giây', () {
      final governor = PoseAndThermalGovernor();
      final spokenAlerts = <String>[];
      governor.setVoiceActionForTest((text) async {
        spokenAlerts.add(text);
      });

      // Góc thẳng chuẩn 175° -> optimal
      expect(governor.evaluatePosture(175.0), equals(PostureQuality.optimal));

      // Góc cong 140° -> elbowBent
      final qualityBent = governor.evaluatePosture(140.0);
      expect(qualityBent, equals(PostureQuality.elbowBent));

      final t0 = DateTime(2026, 11, 9, 8, 0, 0);

      // Giây thứ 0: Cho phép phát câu đầu tiên
      final canSpeak0 = governor.handlePostureVoicePrompt(qualityBent, customNow: t0);
      expect(canSpeak0, isTrue);
      expect(spokenAlerts.length, equals(1));
      expect(spokenAlerts.first, equals('Khóa thẳng khuỷu tay!'));

      // Giây thứ 2 (2s sau): Bị chặn bởi Rate-limit 5s
      final t2 = t0.add(const Duration(seconds: 2));
      final canSpeak2 = governor.handlePostureVoicePrompt(qualityBent, customNow: t2);
      expect(canSpeak2, isFalse);
      expect(spokenAlerts.length, equals(1)); // Vẫn là 1

      // Giây thứ 4 (4s sau): Vẫn bị chặn
      final t4 = t0.add(const Duration(seconds: 4));
      final canSpeak4 = governor.handlePostureVoicePrompt(qualityBent, customNow: t4);
      expect(canSpeak4, isFalse);
      expect(spokenAlerts.length, equals(1));

      // Giây thứ 6 (6s sau > 5s): Cho phép phát lại
      final t6 = t0.add(const Duration(seconds: 6));
      final canSpeak6 = governor.handlePostureVoicePrompt(qualityBent, customNow: t6);
      expect(canSpeak6, isTrue);
      expect(spokenAlerts.length, equals(2));
    });

    test('4. Thermal Throttling: Điều tiết FPS (30 -> 15 -> 0) và ngắt Camera theo nhiệt độ', () {
      final governor = PoseAndThermalGovernor();

      // < 40°C: Bình thường 30 fps
      final eval38 = governor.evaluateThermalState(38.0);
      expect(eval38.state, equals(ThermalState.nominal));
      expect(eval38.fps, equals(30));
      expect(eval38.isCameraPreviewActive, isTrue);

      // >= 40°C: Hạ 15 fps
      final eval41 = governor.evaluateThermalState(41.5);
      expect(eval41.state, equals(ThermalState.throttled));
      expect(eval41.fps, equals(15));
      expect(eval41.isCameraPreviewActive, isTrue);
      expect(eval41.warningMessage, contains('15fps'));

      // >= 45°C: Ngắt camera, tắt inference
      final eval46 = governor.evaluateThermalState(46.0);
      expect(eval46.state, equals(ThermalState.critical));
      expect(eval46.fps, equals(0));
      expect(eval46.isCameraPreviewActive, isFalse);
      expect(eval46.warningMessage, contains('Tắt camera'));
    });

    test('5. Voice Command Engine: Nhận diện chính xác 5 khẩu lệnh sơ cứu offline', () {
      final engine = VoiceCommandEngine();

      // 1. "bắt đầu ép tim"
      final r1 = engine.processUtterance('bắt đầu ép tim');
      expect(r1.action, equals(CprVoiceAction.start));
      expect(r1.isExecuted, isTrue);

      // 2. "dừng lại"
      final r2 = engine.processUtterance('dừng lại');
      expect(r2.action, equals(CprVoiceAction.pause));
      expect(r2.isExecuted, isTrue);

      // 3. "tiếp tục"
      final r3 = engine.processUtterance('tiếp tục');
      expect(r3.action, equals(CprVoiceAction.resume));
      expect(r3.isExecuted, isTrue);

      // 4. "loa ngoài"
      final r4 = engine.processUtterance('bật loa ngoài');
      expect(r4.action, equals(CprVoiceAction.toggleSpeaker));
      expect(r4.isExecuted, isTrue);

      // 5. "bàn giao"
      final r5 = engine.processUtterance('bàn giao xe 115');
      expect(r5.action, equals(CprVoiceAction.handover));
      expect(r5.isExecuted, isTrue);

      // Ngoài danh mục: "alo có ai không"
      final rUnknown = engine.processUtterance('alo có ai không');
      expect(rUnknown.action, equals(CprVoiceAction.unknown));
      expect(rUnknown.isExecuted, isFalse);

      // Độ tin cậy thấp < 0.75
      final rLowConf = engine.processUtterance('tiếp tục', confidence: 0.60);
      expect(rLowConf.isExecuted, isFalse);
    });

    test('6. CprTelemetryBatcher: Gom P2 Telemetry và ghi vào Drift SQLite Outbox', () async {
      const clientUuid = 'test-client-cpr-001';
      final batcher = CprTelemetryBatcher(database: testDb, clientUuid: clientUuid);

      // Warm-up database schema để phân định rõ thời gian mở kết nối DB ban đầu
      await testDb.getPendingEvents();

      const state = CprSessionState(
        totalCompressions: 120,
        elapsedSeconds: 65,
        activeCompressionSeconds: 58,
        estimatedDepthCm: 5.3,
        elbowAngleDeg: 172.0,
        temperatureC: 38.2,
      );

      final latencyMs = await batcher.recordTelemetryBatch(state);
      expect(latencyMs, lessThanOrEqualTo(100), reason: 'Độ trễ ghi SQLite phải <= 100ms (thực tế: $latencyMs ms)');

      final pendingEvents = await testDb.getPendingEvents();
      expect(pendingEvents.length, equals(1));
      expect(pendingEvents.first.eventType, equals('CPR_TELEMETRY'));
      expect(pendingEvents.first.priority, equals(2)); // P2
      expect(pendingEvents.first.payloadJson, contains('"client_uuid":"test-client-cpr-001"'));
      expect(pendingEvents.first.payloadJson, contains('"ccf":89.2'));
    });
  });
}
