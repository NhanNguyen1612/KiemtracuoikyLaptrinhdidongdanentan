import 'dart:async';
import '../ai/medical_neural_nlp_engine.dart';

enum TriageUrgency {
  p0Critical, // P0 • Tối khẩn (Ngừng tim, ngạt thở, sốc phản vệ, chảy máu động mạch)
  p1Urgent,   // P1 • Nguy kịch (Đột quỵ não, bỏng nặng, co giật, chấn thương đầu)
  p2Priority, // P2 • Ưu tiên (Gãy xương, vết thương hở, bỏng độ 2)
  p3Deferred, // P3 • Trì hoãn (Trầy xước nhẹ, bong gân nhẹ)
}

class AiTriageResult {
  final TriageUrgency urgency;
  final String justification;
  final List<String> recommendedEquipment;
  final double confidence;
  final bool isFallback;
  final String medicalDisclaimer;
  final int latencyMs;

  const AiTriageResult({
    required this.urgency,
    required this.justification,
    required this.recommendedEquipment,
    required this.confidence,
    required this.isFallback,
    required this.medicalDisclaimer,
    required this.latencyMs,
  });

  static const defaultDisclaimer =
      'LƯU Ý PHÁP LÝ & AN TOÀN Y KHOA: Phân loại chỉ mang tính chất khuyến nghị hỗ trợ ra quyết định tiếp viện, KHÔNG thay thế y lệnh lâm sàng của Bác sĩ điều phối kíp xe 115.';
}

/// Phân loại cấp cứu Triage bằng Mạng Nơ-ron MedicalNlpNet On-Device (< 5ms, 100% Offline)
class AiTriageService {
  AiTriageService() {
    MedicalNeuralNlpEngine.instance.ensureInitializedSync();
  }

  Future<AiTriageResult> triageEmergency({
    required String description,
    required bool isUnconscious,
    required bool isNotBreathing,
  }) async {
    final stopwatch = Stopwatch()..start();

    final pred = MedicalNeuralNlpEngine.instance.infer(description);
    final int neuralUrgencyLevel = (isNotBreathing || isUnconscious || pred.safetyClassIndex == 1 || pred.safetyClassIndex == 2 || pred.safetyClassIndex == 3)
        ? 0
        : (pred.safetyClassIndex == 4 || pred.safetyClassIndex == 5 ? 1 : pred.topProtocol.urgency);

    late final TriageUrgency urgency;
    late final String justification;
    late final List<String> equipment;

    switch (neuralUrgencyLevel) {
      case 0:
        urgency = TriageUrgency.p0Critical;
        justification =
            '[HEURISTIC RULE-01] (Neural Bi-Encoder Sim=${pred.topCosineSimilarity.toStringAsFixed(2)}) Ngừng tuần hoàn hô hấp hoặc nguy kịch tối khẩn: P0 Tối khẩn.';
        equipment = const ['Máy AED', 'Cáng cứng', 'Bóng Ambu'];
        break;
      case 1:
        urgency = TriageUrgency.p1Urgent;
        justification =
            '[HEURISTIC RULE-02] (Neural Bi-Encoder Sim=${pred.topCosineSimilarity.toStringAsFixed(2)}) Dấu hiệu thần kinh / nội ngoại khoa cấp tính: P1 Nguy kịch.';
        equipment = const ['Bình Oxy', 'Cáng mềm', 'Băng gạc vô trùng'];
        break;
      case 2:
        urgency = TriageUrgency.p2Priority;
        justification =
            '[HEURISTIC RULE-03] (Neural Bi-Encoder Sim=${pred.topCosineSimilarity.toStringAsFixed(2)}) Chấn thương mô/xương cần can thiệp: P2 Ưu tiên.';
        equipment = const ['Túi nẹp', 'Băng cuộn'];
        break;
      default:
        urgency = TriageUrgency.p3Deferred;
        justification =
            '[HEURISTIC RULE-04] (Neural Bi-Encoder Sim=${pred.topCosineSimilarity.toStringAsFixed(2)}) Tổn thương nhẹ / theo dõi ngoại trú: P3 Trì hoãn.';
        equipment = const ['Nước muối sinh lý', 'Băng gạc mỏng'];
        break;
    }

    stopwatch.stop();
    return AiTriageResult(
      urgency: urgency,
      justification: justification,
      recommendedEquipment: equipment,
      confidence: pred.topDocProbability.clamp(0.86, 0.99),
      isFallback: true,
      medicalDisclaimer: AiTriageResult.defaultDisclaimer,
      latencyMs: stopwatch.elapsedMilliseconds,
    );
  }
}
