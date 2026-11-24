import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:resq_aid/core/services/ppg_pipeline.dart';

void main() {
  group('PPG Pipeline DSP & SQI Multi-Gate Test Suite', () {
    late PpgPipeline pipeline;

    setUp(() {
      pipeline = PpgPipeline();
    });

    test('1. Clean synthetic pulse at 75 BPM yields accurate BPM with high SQI', () {
      // 75 BPM = 1.25 Hz. Tại 30 Hz -> chu kỳ T = 24 mẫu
      const targetBpm = 75;
      const freqHz = targetBpm / 60.0;
      PpgAnalysisResult? lastResult;

      // Mô phỏng 300 khung hình (~7.5-10 giây) với VFR
      int simulatedTimeMs = 1000;
      for (int i = 0; i < 300; i++) {
        final tSec = simulatedTimeMs / 1000.0;
        // Tín hiệu DC = 160 (mô mềm ngón tay), AC = 6.0 sin(2pi * f * t) + hài bậc 2
        final rawVal = 160.0 + 6.0 * sin(2 * pi * freqHz * tSec) + 1.5 * sin(4 * pi * freqHz * tSec);
        lastResult = pipeline.processFrame(rawVal, simulatedTimeMs);
        simulatedTimeMs += (20 + (i % 7)); // Mô phỏng VFR jitter
      }

      expect(lastResult, isNotNull);
      expect(lastResult!.isValid, isTrue);
      expect(lastResult.bpm, inInclusiveRange(70, 80));
      expect(lastResult.quality, anyOf(PpgQuality.good, PpgQuality.fair));
      expect(lastResult.signalQualityIndex, greaterThanOrEqualTo(0.50));
    });

    test('2. Flatline / Mất mạch (Không có biến thiên AC) -> BẮT BUỘC trả về null, KHÔNG đoán bừa', () {
      PpgAnalysisResult? lastResult;
      int simulatedTimeMs = 1000;

      for (int i = 0; i < 250; i++) {
        // Tín hiệu phẳng DC = 150 kèm nhiễu nền li ti 0.05
        final rawVal = 150.0 + ((i % 3) * 0.02);
        lastResult = pipeline.processFrame(rawVal, simulatedTimeMs);
        simulatedTimeMs += 33;
      }

      expect(lastResult, isNotNull);
      expect(lastResult!.bpm, isNull, reason: 'Tín hiệu phẳng không được tự ý báo có mạch!');
      expect(lastResult.quality, equals(PpgQuality.unreliable));
      expect(lastResult.reason, equals(PpgRejectionReason.lowPerfusion));
    });

    test('3. CPR Lockout: Khi cờ ép tim isCprActive = true, lập tức từ chối đo để tránh nhầm nhịp ép tim', () {
      pipeline.isCprActive = true;
      final result = pipeline.processFrame(150.0, 1000);

      expect(result.bpm, isNull);
      expect(result.quality, equals(PpgQuality.unreliable));
      expect(result.reason, equals(PpgRejectionReason.cprLockout));
    });

    test('4. Rung lắc gia tốc kế (Motion Artifacts) -> Từ chối đo ngay lập tức', () {
      pipeline.isMotionDetected = true;
      final result = pipeline.processFrame(150.0, 1000);

      expect(result.bpm, isNull);
      expect(result.quality, equals(PpgQuality.unreliable));
      expect(result.reason, equals(PpgRejectionReason.motionArtifact));
    });

    test('5. Cổng DC: Tín hiệu tối mịt (<15) hoặc cháy sáng bão hòa (>250) bị từ chối', () {
      int simulatedTimeMs = 1000;
      PpgAnalysisResult? darkResult;

      // Quá tối
      for (int i = 0; i < 160; i++) {
        darkResult = pipeline.processFrame(8.0, simulatedTimeMs);
        simulatedTimeMs += 33;
      }
      expect(darkResult!.bpm, isNull);
      expect(darkResult.reason, equals(PpgRejectionReason.tooDark));

      pipeline.reset();
      PpgAnalysisResult? saturatedResult;
      for (int i = 0; i < 160; i++) {
        saturatedResult = pipeline.processFrame(254.0, simulatedTimeMs);
        simulatedTimeMs += 33;
      }
      expect(saturatedResult!.bpm, isNull);
      expect(saturatedResult.reason, equals(PpgRejectionReason.saturated));
    });

    test('6. Nhiễu trắng hỗn loạn (Random Noise) -> Hệ thống từ chối, không báo nhịp tim giả', () {
      final random = Random(42);
      PpgAnalysisResult? lastResult;
      int simulatedTimeMs = 1000;

      for (int i = 0; i < 200; i++) {
        final rawVal = 140.0 + (random.nextDouble() - 0.5) * 15.0; // Nhiễu trắng biên độ lớn
        lastResult = pipeline.processFrame(rawVal, simulatedTimeMs);
        simulatedTimeMs += 33;
      }

      // Nhiễu ngẫu nhiên không có tính tuần hoàn sinh lý -> CV cao hoặc SNR phổ thấp -> Bị từ chối
      expect(lastResult!.bpm, isNull, reason: 'Nhiễu trắng không được báo nhịp tim!');
      expect(lastResult.quality, equals(PpgQuality.unreliable));
    });

    test('7. Nhiễu cảm biến khi nhìn vào vật thể tĩnh (bàn, dây cáp) -> Hệ thống từ chối, trả về null BPM', () {
      final random = Random(123);
      PpgAnalysisResult? lastResult;
      int simulatedTimeMs = 1000;

      for (int i = 0; i < 300; i++) {
        // Tín hiệu cảm biến camera trên vật thể tĩnh: DC = 47 kèm nhiễu cảm biến li ti
        final rawVal = 47.0 + (random.nextDouble() - 0.5) * 1.5;
        lastResult = pipeline.processFrame(rawVal, simulatedTimeMs);
        simulatedTimeMs += 33;
      }

      expect(lastResult, isNotNull);
      expect(lastResult!.bpm, isNull, reason: 'Nhiễu cảm biến trên vật thể tĩnh không bao giờ được sinh nhịp tim giả!');
      expect(lastResult.isValid, isFalse);
    });

    test('8. Phản hồi nhanh: Bắt đầu xuất BPM hợp lệ sớm trong vòng 2.0s (dưới 65 frames)', () {
      const targetBpm = 75;
      const freqHz = targetBpm / 60.0;
      int simulatedTimeMs = 1000;
      int? firstValidFrame;
      int? firstValidBpm;

      for (int i = 0; i < 70; i++) {
        final tSec = simulatedTimeMs / 1000.0;
        final rawVal = 160.0 + 6.0 * sin(2 * pi * freqHz * tSec) + 1.5 * sin(4 * pi * freqHz * tSec);
        final result = pipeline.processFrame(rawVal, simulatedTimeMs);
        if (result.isValid && firstValidFrame == null) {
          firstValidFrame = i;
          firstValidBpm = result.bpm;
        }
        simulatedTimeMs += 33;
      }

      expect(firstValidFrame, isNotNull, reason: 'Phải xuất hiện kết quả BPM sớm để người dùng không thấy trống --!');
      expect(firstValidFrame!, lessThanOrEqualTo(65));
      expect(firstValidBpm, inInclusiveRange(70, 80));
    });

    test('9. Kháng nhiễu tức thời: Sự cố rung chuyển động không xóa trắng lịch sử lastValidBpm', () {
      const targetBpm = 72;
      const freqHz = targetBpm / 60.0;
      int simulatedTimeMs = 1000;

      // 100 khung hình chuẩn
      for (int i = 0; i < 100; i++) {
        final tSec = simulatedTimeMs / 1000.0;
        final rawVal = 160.0 + 5.0 * sin(2 * pi * freqHz * tSec);
        pipeline.processFrame(rawVal, simulatedTimeMs);
        simulatedTimeMs += 33;
      }
      expect(pipeline.lastValidBpm, isNotNull);

      // Cờ rung lắc phát hiện chuyển động (motion artifact)
      pipeline.isMotionDetected = true;
      final motionResult = pipeline.processFrame(160.0, simulatedTimeMs);
      pipeline.isMotionDetected = false;

      // Khung hình rung lắc trả về null, nhưng lastValidBpm vẫn được lưu giữ
      expect(motionResult.bpm, isNull);
      expect(pipeline.lastValidBpm, isNotNull, reason: 'lastValidBpm vẫn được giữ lại để chống chớp giật --');
    });
  });
}
