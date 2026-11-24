import 'dart:convert';
import '../services/tflite_vision_service.dart';

/// Nhóm tuổi nạn nhân
enum PatientAgeGroup {
  infant, // Trẻ nhũ nhi (< 1 tuổi)
  child,  // Trẻ em (1 - 8 tuổi)
  adult,  // Người lớn (8 - 60 tuổi)
  elderly // Người cao tuổi (> 60 tuổi)
}

/// Mức độ chảy máu
enum BleedSeverity {
  none,
  minorOozing,       // Rỉ máu / trầy xước mao mạch
  venousFlow,        // Chảy máu tĩnh mạch (máu đỏ thẫm chảy đều)
  arterialSpurting,  // Chảy máu động mạch (máu đỏ tươi phun thành tia)
}

/// Sự kiện cập nhật trạng thái ca lâm sàng (Clinical Case Event)
abstract class CaseEvent {
  final DateTime timestamp;
  CaseEvent({DateTime? timestamp}) : timestamp = timestamp ?? DateTime.now();
}

class UpdateVitalSignsEvent extends CaseEvent {
  final bool? isConscious;
  final bool? isBreathing;
  final bool? hasPulse;
  UpdateVitalSignsEvent({this.isConscious, this.isBreathing, this.hasPulse});
}

class TriggerRedFlagEvent extends CaseEvent {
  final String flagId;
  final String description;
  final ClinicalTriagePriority escalatedPriority;
  TriggerRedFlagEvent({
    required this.flagId,
    required this.description,
    this.escalatedPriority = ClinicalTriagePriority.p0Catastrophic,
  });
}

class UpdateBleedingEvent extends CaseEvent {
  final String? site;
  final BleedSeverity severity;
  final bool isControlled;
  UpdateBleedingEvent({
    this.site,
    required this.severity,
    this.isControlled = false,
  });
}

class RecordInterventionEvent extends CaseEvent {
  final String action;
  final String note;
  RecordInterventionEvent({required this.action, required this.note});
}

class UpdateDemographicsEvent extends CaseEvent {
  final PatientAgeGroup? ageGroup;
  final int? approxAge;
  final bool? isMale;
  final bool? isPregnant;
  UpdateDemographicsEvent({this.ageGroup, this.approxAge, this.isMale, this.isPregnant});
}

class MarkEmergencyCalledEvent extends CaseEvent {
  final bool called;
  MarkEmergencyCalledEvent({this.called = true});
}

/// Trạng thái Ca Lâm sàng Bất biến (Immutable Clinical CaseState)
/// Quản lý dữ liệu bệnh nhân, sinh hiệu, protocol, can thiệp và timeline cấp cứu.
class CaseState {
  // 1. Thông tin nạn nhân (Demographics)
  final PatientAgeGroup ageGroup;
  final int? approxAge;
  final bool? isMale;
  final bool isPregnant;

  // 2. Dấu hiệu sinh tồn (Vital Signs)
  final bool? isConscious;
  final bool? isBreathing;
  final bool? hasPulse;

  // 3. Phân loại khẩn cấp (Clinical Triage)
  final ClinicalTriagePriority triagePriority;
  final Set<String> activeRedFlags;

  // 4. Tổn thương & Chảy máu
  final String? bleedingSite;
  final BleedSeverity bleedSeverity;
  final bool isBleedingControlled;
  final DateTime? tourniquetAppliedTime;

  // 5. Nhật ký can thiệp & Mốc thời gian (Interventions & Timelines)
  final DateTime sessionStartTime;
  final DateTime? cprStartTime;
  final bool isEmergency115Called;
  final List<String> interventionLog;
  final String currentProtocolStep;

  const CaseState({
    this.ageGroup = PatientAgeGroup.adult,
    this.approxAge,
    this.isMale,
    this.isPregnant = false,
    this.isConscious,
    this.isBreathing,
    this.hasPulse,
    this.triagePriority = ClinicalTriagePriority.p4Normal,
    this.activeRedFlags = const {},
    this.bleedingSite,
    this.bleedSeverity = BleedSeverity.none,
    this.isBleedingControlled = false,
    this.tourniquetAppliedTime,
    required this.sessionStartTime,
    this.cprStartTime,
    this.isEmergency115Called = false,
    this.interventionLog = const [],
    this.currentProtocolStep = 'Khởi đầu tiếp cận',
  });

  factory CaseState.initial() {
    return CaseState(
      sessionStartTime: DateTime.now(),
    );
  }

  /// Trọng số ưu tiên cấp cứu để đảm bảo "CHỈ LEO THANG, KHÔNG ÂM THẦM HẠ CẤP"
  static int _priorityWeight(ClinicalTriagePriority priority) {
    switch (priority) {
      case ClinicalTriagePriority.p0Catastrophic:
        return 4;
      case ClinicalTriagePriority.p1Urgent:
        return 3;
      case ClinicalTriagePriority.p2SemiUrgent:
        return 2;
      case ClinicalTriagePriority.p3NonUrgent:
        return 1;
      case ClinicalTriagePriority.p4Normal:
        return 0;
    }
  }

  /// Bộ biến đổi trạng thái thuần túy (Pure Reducer Function)
  /// Đảm bảo tính toán toàn vẹn, deterministic, dễ kiểm thử tự động.
  CaseState reduce(CaseEvent event) {
    if (event is UpdateVitalSignsEvent) {
      final newConscious = event.isConscious ?? isConscious;
      final newBreathing = event.isBreathing ?? isBreathing;
      final newPulse = event.hasPulse ?? hasPulse;

      var newPriority = triagePriority;
      final newFlags = Set<String>.from(activeRedFlags);
      final newLogs = List<String>.from(interventionLog);
      DateTime? newCprStart = cprStartTime;

      // Cờ đỏ ngừng thở / ngừng tim -> Kích hoạt ngay P0 Cực kỳ nguy kịch
      if (newBreathing == false || newConscious == false) {
        newPriority = ClinicalTriagePriority.p0Catastrophic;
        newFlags.add('APNEA_UNRESPONSIVE');
        if (newCprStart == null) {
          newCprStart = event.timestamp;
          newLogs.add('[${_formatTime(event.timestamp)}] Phát hiện ngừng thở/bất tỉnh -> Bắt đầu ép tim CPR');
        }
      }

      return copyWith(
        isConscious: newConscious,
        isBreathing: newBreathing,
        hasPulse: newPulse,
        triagePriority: _priorityWeight(newPriority) > _priorityWeight(triagePriority)
            ? newPriority
            : triagePriority,
        activeRedFlags: newFlags,
        cprStartTime: newCprStart,
        interventionLog: newLogs,
      );
    }

    if (event is TriggerRedFlagEvent) {
      final newFlags = Set<String>.from(activeRedFlags)..add(event.flagId);
      final newPriority = _priorityWeight(event.escalatedPriority) > _priorityWeight(triagePriority)
          ? event.escalatedPriority
          : triagePriority;
      final newLogs = List<String>.from(interventionLog)
        ..add('[${_formatTime(event.timestamp)}] CẢNH BÁO ĐỎ: ${event.description}');

      return copyWith(
        activeRedFlags: newFlags,
        triagePriority: newPriority,
        interventionLog: newLogs,
      );
    }

    if (event is UpdateBleedingEvent) {
      var newPriority = triagePriority;
      DateTime? newTourniquet = tourniquetAppliedTime;
      final newLogs = List<String>.from(interventionLog);

      if (event.severity == BleedSeverity.arterialSpurting) {
        newPriority = ClinicalTriagePriority.p0Catastrophic;
        newLogs.add('[${_formatTime(event.timestamp)}] Chảy máu động mạch phun tia tại ${event.site ?? "chi"}');
      } else if (event.severity == BleedSeverity.venousFlow) {
        if (_priorityWeight(ClinicalTriagePriority.p1Urgent) > _priorityWeight(newPriority)) {
          newPriority = ClinicalTriagePriority.p1Urgent;
        }
        newLogs.add('[${_formatTime(event.timestamp)}] Chảy máu nhiều tại ${event.site ?? "chi"}');
      }

      return copyWith(
        bleedingSite: event.site ?? bleedingSite,
        bleedSeverity: event.severity,
        isBleedingControlled: event.isControlled,
        tourniquetAppliedTime: newTourniquet,
        triagePriority: _priorityWeight(newPriority) > _priorityWeight(triagePriority)
            ? newPriority
            : triagePriority,
        interventionLog: newLogs,
      );
    }

    if (event is RecordInterventionEvent) {
      final newLogs = List<String>.from(interventionLog)
        ..add('[${_formatTime(event.timestamp)}] ${event.action}: ${event.note}');
      return copyWith(
        interventionLog: newLogs,
      );
    }

    if (event is UpdateDemographicsEvent) {
      return copyWith(
        ageGroup: event.ageGroup ?? ageGroup,
        approxAge: event.approxAge ?? approxAge,
        isMale: event.isMale ?? isMale,
        isPregnant: event.isPregnant ?? isPregnant,
      );
    }

    if (event is MarkEmergencyCalledEvent) {
      final newLogs = List<String>.from(interventionLog)
        ..add('[${_formatTime(event.timestamp)}] ${event.called ? "Đã kết nối gọi Cấp cứu 115" : "Chưa gọi 115"}');
      return copyWith(
        isEmergency115Called: event.called,
        interventionLog: newLogs,
      );
    }

    return this;
  }

  /// Xuất tóm tắt Ca Cấp Cứu chuẩn y tế để người dùng đọc cho Điều phối viên 115
  String exportHandoverSummary() {
    final sb = StringBuffer();
    sb.writeln('📋 TÓM TẮT CA CẤP CỨU BÀN GIAO 115:');
    
    // Nạn nhân
    final ageStr = approxAge != null ? '$approxAge tuổi' : (ageGroup == PatientAgeGroup.child ? 'Trẻ em' : 'Người lớn');
    final genderStr = isMale == null ? 'Không rõ giới' : (isMale! ? 'Nam' : 'Nữ');
    final pregStr = isPregnant ? ' (Đang mang thai)' : '';
    sb.writeln('• Nạn nhân: $genderStr, $ageStr$pregStr');

    // Sinh hiệu
    final consciousStr = isConscious == null ? 'Chưa rõ ý thức' : (isConscious! ? 'Tỉnh táo' : 'BẤT TỈNH');
    final breathingStr = isBreathing == null ? 'Chưa rõ nhịp thở' : (isBreathing! ? 'Còn thở' : 'NGỪNG THỞ');
    sb.writeln('• Tình trạng sinh tồn: $consciousStr, $breathingStr');

    // Chảy máu
    if (bleedSeverity != BleedSeverity.none) {
      final bleedType = bleedSeverity == BleedSeverity.arterialSpurting
          ? 'MÁU ĐỘNG MẠCH PHUN TIA'
          : (bleedSeverity == BleedSeverity.venousFlow ? 'Chảy máu nhiều' : 'Rỉ máu');
      final ctrlStr = isBleedingControlled ? 'Đã tạm cầm' : 'CHƯA CẦM ĐƯỢC';
      sb.writeln('• Xuất huyết: $bleedType tại ${bleedingSite ?? "vùng tổn thương"} ($ctrlStr)');
    }

    // CPR
    if (cprStartTime != null) {
      final cprMinutes = DateTime.now().difference(cprStartTime!).inMinutes;
      sb.writeln('• Ép tim CPR: Bắt đầu lúc ${_formatTime(cprStartTime!)}, đã ép $cprMinutes phút');
    }

    // Garô
    if (tourniquetAppliedTime != null) {
      sb.writeln('• Đặt ga-rô: Lúc ${_formatTime(tourniquetAppliedTime!)}');
    }

    // Cờ đỏ
    if (activeRedFlags.isNotEmpty) {
      sb.writeln('• Cảnh báo đỏ: ${activeRedFlags.join(", ")}');
    }

    sb.writeln('• Trạng thái 115: ${isEmergency115Called ? "Đã gọi xe cấp cứu" : "CẦN GỌI 115 NGAY"}');
    return sb.toString();
  }

  static String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }

  CaseState copyWith({
    PatientAgeGroup? ageGroup,
    int? approxAge,
    bool? isMale,
    bool? isPregnant,
    bool? isConscious,
    bool? isBreathing,
    bool? hasPulse,
    ClinicalTriagePriority? triagePriority,
    Set<String>? activeRedFlags,
    String? bleedingSite,
    BleedSeverity? bleedSeverity,
    bool? isBleedingControlled,
    DateTime? tourniquetAppliedTime,
    DateTime? sessionStartTime,
    DateTime? cprStartTime,
    bool? isEmergency115Called,
    List<String>? interventionLog,
    String? currentProtocolStep,
  }) {
    return CaseState(
      ageGroup: ageGroup ?? this.ageGroup,
      approxAge: approxAge ?? this.approxAge,
      isMale: isMale ?? this.isMale,
      isPregnant: isPregnant ?? this.isPregnant,
      isConscious: isConscious ?? this.isConscious,
      isBreathing: isBreathing ?? this.isBreathing,
      hasPulse: hasPulse ?? this.hasPulse,
      triagePriority: triagePriority ?? this.triagePriority,
      activeRedFlags: activeRedFlags ?? this.activeRedFlags,
      bleedingSite: bleedingSite ?? this.bleedingSite,
      bleedSeverity: bleedSeverity ?? this.bleedSeverity,
      isBleedingControlled: isBleedingControlled ?? this.isBleedingControlled,
      tourniquetAppliedTime: tourniquetAppliedTime ?? this.tourniquetAppliedTime,
      sessionStartTime: sessionStartTime ?? this.sessionStartTime,
      cprStartTime: cprStartTime ?? this.cprStartTime,
      isEmergency115Called: isEmergency115Called ?? this.isEmergency115Called,
      interventionLog: interventionLog ?? this.interventionLog,
      currentProtocolStep: currentProtocolStep ?? this.currentProtocolStep,
    );
  }
}
