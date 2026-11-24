enum IncidentLifecycle {
  newIncident, // 1. Mới nhận
  accepted, // 2. Đã tiếp nhận
  dispatched, // 3. Đã điều xe
  enRoute, // 4. Đang đến (ETA)
  onScene, // 5. Tại hiện trường
  transporting, // 6. Đã chuyển viện
  closed, // 7. Đóng ca
}

enum PriorityTier {
  p0Critical, // P0 • TỐI KHẨN
  p1Urgent, // P1 • NGUY KỊCH
  p2Priority, // P2 • ƯU TIÊN
  p3Deferred, // P3 • TRÌ HOÃN
}

class IncidentModel {
  final String id;
  final String clientUuid;
  final String callerName;
  final String callerPhone;
  final String incidentType;
  final PriorityTier priority;
  final IncidentLifecycle status;
  final double lat;
  final double lng;
  final String address;
  final DateTime reportedAt;
  final String? assignedAmbulance;
  final int? etaMinutes;
  final double? liveCcf;
  final int? liveBpm;
  final int? elapsedSeconds;
  final String? aiTriageRecommendation;
  final List<String> requiredEquipment;

  const IncidentModel({
    required this.id,
    required this.clientUuid,
    required this.callerName,
    required this.callerPhone,
    required this.incidentType,
    required this.priority,
    required this.status,
    required this.lat,
    required this.lng,
    required this.address,
    required this.reportedAt,
    this.assignedAmbulance,
    this.etaMinutes,
    this.liveCcf,
    this.liveBpm,
    this.elapsedSeconds,
    this.aiTriageRecommendation,
    this.requiredEquipment = const [],
  });

  IncidentModel copyWith({
    IncidentLifecycle? status,
    String? assignedAmbulance,
    int? etaMinutes,
    double? liveCcf,
    int? liveBpm,
    int? elapsedSeconds,
    String? aiTriageRecommendation,
    List<String>? requiredEquipment,
  }) {
    return IncidentModel(
      id: id,
      clientUuid: clientUuid,
      callerName: callerName,
      callerPhone: callerPhone,
      incidentType: incidentType,
      priority: priority,
      status: status ?? this.status,
      lat: lat,
      lng: lng,
      address: address,
      reportedAt: reportedAt,
      assignedAmbulance: assignedAmbulance ?? this.assignedAmbulance,
      etaMinutes: etaMinutes ?? this.etaMinutes,
      liveCcf: liveCcf ?? this.liveCcf,
      liveBpm: liveBpm ?? this.liveBpm,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      aiTriageRecommendation: aiTriageRecommendation ?? this.aiTriageRecommendation,
      requiredEquipment: requiredEquipment ?? this.requiredEquipment,
    );
  }
}
