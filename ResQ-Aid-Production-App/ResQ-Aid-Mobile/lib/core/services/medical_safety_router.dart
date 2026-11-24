import '../ai/medical_neural_nlp_engine.dart';
import 'tflite_vision_service.dart';

/// Kết quả định tuyến khẩn cấp Tầng 0 từ Head Safety L0 của Mạng Nơ-ron
class SafetyRouteResult {
  final bool isTriggered;
  final String redFlagId;
  final String title;
  final String criticalAction;
  final ClinicalTriagePriority priority;
  final bool shouldStartCprMetronome;
  final bool shouldCall115Immediately;
  final String initialVoiceResponse;
  final double neuralConfidence;

  const SafetyRouteResult({
    required this.isTriggered,
    this.redFlagId = '',
    this.title = '',
    this.criticalAction = '',
    this.priority = ClinicalTriagePriority.p4Normal,
    this.shouldStartCprMetronome = false,
    this.shouldCall115Immediately = false,
    this.initialVoiceResponse = '',
    this.neuralConfidence = 0.0,
  });

  static const noMatch = SafetyRouteResult(isTriggered: false);
}

/// TẦNG 0: BỘ ĐỊNH TUYẾN AN TOÀN LÂM SÀNG THUẦN MẠNG NƠ-RON (NEURAL L0 SAFETY HEAD)
/// Phân loại xác suất Softmax 6 lớp nguy kịch trực tiếp từ vector ngữ nghĩa 128D (< 1ms).
class MedicalSafetyRouter {
  static String removeDiacritics(String str) => MedicalNeuralNlpEngine.stripDiacritics(str);

  static const List<SafetyRouteResult> _safetyClassTemplates = [
    SafetyRouteResult.noMatch,
    // 1: CARDIAC_ARREST_P0
    SafetyRouteResult(
      isTriggered: true,
      redFlagId: 'CARDIAC_ARREST_P0',
      title: 'NGỪNG TIM - NGỪNG THỞ CẤP TÍNH',
      criticalAction: 'Đặt nạn nhân nằm ngửa nền cứng. Bắt đầu ép tim liên tục 110 BPM (100-120 nhịp/phút) ngay!',
      priority: ClinicalTriagePriority.p0Catastrophic,
      shouldStartCprMetronome: true,
      shouldCall115Immediately: true,
      initialVoiceResponse: 'Cảnh báo nguy kịch: Nạn nhân ngừng thở! Gọi 115 ngay lập tức. Đặt hai tay chồng lên giữa ngực nạn nhân và bắt đầu ép tim 110 BPM!',
    ),
    // 2: ARTERIAL_BLEED_P0
    SafetyRouteResult(
      isTriggered: true,
      redFlagId: 'ARTERIAL_BLEED_P0',
      title: 'XUẤT HUYẾT ĐỘNG MẠCH NGUY KỊCH',
      criticalAction: 'Dùng gạc ép chặt trực tiếp lên miệng vết thương không buông! Chuẩn bị ga-rô nếu ở chi!',
      priority: ClinicalTriagePriority.p0Catastrophic,
      shouldStartCprMetronome: false,
      shouldCall115Immediately: true,
      initialVoiceResponse: 'Cảnh báo mất máu cấp: Dùng tay hoặc vải sạch ấn thật chặt trực tiếp lên vị trí máu phun! Gọi 115 khẩn cấp!',
    ),
    // 3: CHOKING_HEIMLICH_P0
    SafetyRouteResult(
      isTriggered: true,
      redFlagId: 'CHOKING_HEIMLICH_P0',
      title: 'TẮC NGHẼN ĐƯỜNG THỞ CẤP (HÓC NGHẸN)',
      criticalAction: 'Thực hiện ngay 5 cú vỗ lưng và thủ thuật Heimlich ấn bụng dứt khoát!',
      priority: ClinicalTriagePriority.p0Catastrophic,
      shouldStartCprMetronome: false,
      shouldCall115Immediately: true,
      initialVoiceResponse: 'Cảnh báo tắc đường thở: Thực hiện 5 cú vỗ lưng và vòng hai tay ôm eo làm thủ thuật Heimlich giật mạnh vào trong và lên trên!',
    ),
    // 4: SEIZURE_P1
    SafetyRouteResult(
      isTriggered: true,
      redFlagId: 'SEIZURE_P1',
      title: 'CO GIẬT CẤP TÍNH',
      criticalAction: 'Kê vật mềm dưới đầu, nằm nghiêng an toàn. TUYỆT ĐỐI CẤM nhét bất cứ thứ gì vào miệng!',
      priority: ClinicalTriagePriority.p1Urgent,
      shouldStartCprMetronome: false,
      shouldCall115Immediately: true,
      initialVoiceResponse: 'Cảnh báo CO GIẬT: Dọn sạch vật sắc nhọn xung quanh, lót gối dưới đầu, nằm nghiêng an toàn. CẤM nhét thìa hay ngón tay vào miệng nạn nhân!',
    ),
    // 5: ANAPHYLAXIS_P1
    SafetyRouteResult(
      isTriggered: true,
      redFlagId: 'ANAPHYLAXIS_P1',
      title: 'NGHI NGỜ SỐC PHẢN VỆ NGUY KỊCH',
      criticalAction: 'Đặt nằm nâng cao chân 30cm. Tiêm bút tiêm Epinephrine (EpiPen) nếu có. Gọi 115 ngay!',
      priority: ClinicalTriagePriority.p1Urgent,
      shouldStartCprMetronome: false,
      shouldCall115Immediately: true,
      initialVoiceResponse: 'Cảnh báo SỐC PHẢN VỆ: Đặt nạn nhân nằm đầu thấp kê chân cao 30cm. Tiêm bút tiêm Epinephrine (EpiPen) mặt ngoài đùi nếu có và gọi 115 ngay!',
    ),
  ];

  static SafetyRouteResult evaluate(String rawText) {
    if (rawText.trim().isEmpty) return SafetyRouteResult.noMatch;

    final pred = MedicalNeuralNlpEngine.instance.infer(rawText);
    // Nếu có đa bệnh lý đồng mắc (ví dụ chó cắn + co giật), chuyển xuống bộ tổng hợp đa phác đồ
    if (pred.discourseModeIndex == 3 && pred.comorbidProtocols.length >= 2) {
      return SafetyRouteResult.noMatch;
    }

    final idx = pred.safetyClassIndex;
    if (idx >= 1 && idx < _safetyClassTemplates.length && pred.safetyConfidence >= 0.72) {
      final tmpl = _safetyClassTemplates[idx];
      return SafetyRouteResult(
        isTriggered: true,
        redFlagId: tmpl.redFlagId,
        title: tmpl.title,
        criticalAction: tmpl.criticalAction,
        priority: tmpl.priority,
        shouldStartCprMetronome: tmpl.shouldStartCprMetronome,
        shouldCall115Immediately: tmpl.shouldCall115Immediately,
        initialVoiceResponse: tmpl.initialVoiceResponse,
        neuralConfidence: pred.safetyConfidence,
      );
    }

    return SafetyRouteResult.noMatch;
  }
}
