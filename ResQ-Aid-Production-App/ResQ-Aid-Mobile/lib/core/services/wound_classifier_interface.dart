import 'dart:ui' as ui;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'tflite_vision_service.dart';

/// 4 Bậc hành động cấp cứu lâm sàng (Action-oriented Triage Classes theo Đề xuất B1)
enum TraumaActionClass {
  immediate115,     // Bậc 1: Gọi 115 ngay lập tức (P0 Cực kỳ nguy kịch)
  urgentHospital,   // Bậc 2: Sơ cứu bất động/cầm máu rồi đến bệnh viện (P1 Cấp cứu khẩn)
  semiUrgentClinic, // Bậc 3: Sơ cứu tại chỗ + theo dõi sát dấu hiệu lan rộng (P2 Bán cấp cứu)
  homeCareSafe,     // Bậc 4: Tự chăm sóc tại nhà / Da lành lặn an toàn (P3/P4)
  uncertainQuality, // Bậc đặc biệt: Chất lượng ảnh không đạt tiêu chuẩn (Cần chụp lại)
}

/// Chuyển đổi từ ClinicalTriagePriority sang TraumaActionClass
extension ClinicalTriagePriorityActionExt on ClinicalTriagePriority {
  TraumaActionClass toActionClass() {
    switch (this) {
      case ClinicalTriagePriority.p0Catastrophic:
        return TraumaActionClass.immediate115;
      case ClinicalTriagePriority.p1Urgent:
        return TraumaActionClass.urgentHospital;
      case ClinicalTriagePriority.p2SemiUrgent:
        return TraumaActionClass.semiUrgentClinic;
      case ClinicalTriagePriority.p3NonUrgent:
      case ClinicalTriagePriority.p4Normal:
        return TraumaActionClass.homeCareSafe;
    }
  }

  String get actionTitle {
    switch (this) {
      case ClinicalTriagePriority.p0Catastrophic:
        return 'GỌI 115 NGAY LẬP TỨC (CẤP CỨU HỒI SỨC)';
      case ClinicalTriagePriority.p1Urgent:
        return 'SƠ CỨU KHẨN & ĐẾN TRUNG TÂM CHẤN THƯƠNG';
      case ClinicalTriagePriority.p2SemiUrgent:
        return 'SƠ CỨU TẠI CHỖ & THEO DÕI BIẾN CHỨNG';
      case ClinicalTriagePriority.p3NonUrgent:
        return 'CHĂM SÓC VẾT THƯƠNG TẠI NHÀ';
      case ClinicalTriagePriority.p4Normal:
        return 'AN TOÀN / KHÔNG CẦN CAN THIỆP Y TẾ';
    }
  }
}

/// Dữ liệu đầu vào cho quá trình phân loại vết thương
class TraumaClassificationInput {
  final List<int> rawImageBytes;
  final String? preferredProtocolHint;
  final Map<String, dynamic> metadata;
  final ui.Rect? cropRoi;
  final double? viewAspect;

  const TraumaClassificationInput({
    required this.rawImageBytes,
    this.preferredProtocolHint,
    this.metadata = const {},
    this.cropRoi,
    this.viewAspect,
  });
}

/// Interface trừu tượng cho Động cơ Phân loại Vết thương & Triage On-Device
abstract class WoundClassifier {
  Future<void> initialize();
  Future<TfliteInferenceResult> classify(TraumaClassificationInput input);
  void dispose();
}

/// Riverpod Provider cung cấp thể hiện WoundClassifier cho toàn ứng dụng
final woundClassifierProvider = Provider<WoundClassifier>((ref) {
  return TfliteVisionService();
});
