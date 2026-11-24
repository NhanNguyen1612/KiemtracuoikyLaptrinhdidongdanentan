import 'dart:async';
import 'dart:convert';
import '../../../core/database/app_database.dart';
import '../domain/incident_model.dart';

class DispatcherRealtimeService {
  static final DispatcherRealtimeService shared = DispatcherRealtimeService();

  final _incidentsController = StreamController<List<IncidentModel>>.broadcast();
  List<IncidentModel> _incidents = [
    IncidentModel(
      id: 'INC-001',
      clientUuid: 'CLIENT-CPR-99',
      callerName: 'Nguyễn Văn A',
      callerPhone: '0905123456',
      incidentType: 'Ngưng tim ngưng thở (Ép tim CPR)',
      priority: PriorityTier.p0Critical,
      status: IncidentLifecycle.dispatched,
      lat: 16.0678,
      lng: 108.2208,
      address: 'Số 12 Đường Bạch Đằng, Hải Châu, Đà Nẵng',
      reportedAt: DateTime(2026, 11, 15, 14, 30),
      assignedAmbulance: 'Xe 115-01 (Bệnh viện Đà Nẵng)',
      etaMinutes: 4,
      liveCcf: 0.85,
      liveBpm: 110,
      elapsedSeconds: 120,
      aiTriageRecommendation: 'Nghi ngờ nhồi máu cơ tim cấp. Hướng dẫn ép tim 110 BPM, chuẩn bị máy AED.',
      requiredEquipment: const ['Máy khử rung tim AED', 'Bóng bóp Ambu', 'Oxy cao áp'],
    ),
    IncidentModel(
      id: 'INC-002',
      clientUuid: 'CLIENT-BEACH-02',
      callerName: 'Trần Thị B',
      callerPhone: '0914987654',
      incidentType: 'Đuối nước ngạt thở bãi biển',
      priority: PriorityTier.p1Urgent,
      status: IncidentLifecycle.accepted,
      lat: 16.0612,
      lng: 108.2456,
      address: 'Bãi tắm Mỹ Khê, Ngũ Hành Sơn, Đà Nẵng',
      reportedAt: DateTime(2026, 11, 15, 14, 32),
      assignedAmbulance: null,
      etaMinutes: null,
      aiTriageRecommendation: 'Ngạt nước, đã vớt lên bờ. Ưu tiên thổi ngạt 5 nhịp đầu tiên, sau đó ép tim 30:2.',
      requiredEquipment: const ['Máy hút đờm', 'Oxy'],
    ),
    IncidentModel(
      id: 'INC-003',
      clientUuid: 'CLIENT-TRAFFIC-03',
      callerName: 'Lê Hoàng C',
      callerPhone: '0935112233',
      incidentType: 'Tai nạn giao thông gãy hở xương đùi',
      priority: PriorityTier.p2Priority,
      status: IncidentLifecycle.enRoute,
      lat: 16.0421,
      lng: 108.2134,
      address: 'Ngã tư Nguyễn Tri Phương - Điện Biên Phủ, Đà Nẵng',
      reportedAt: DateTime(2026, 11, 15, 14, 25),
      assignedAmbulance: 'Xe 115-03 (Bệnh viện C)',
      etaMinutes: 8,
      aiTriageRecommendation: 'Gãy hở xương đùi kèm chảy máu. Nẹp cố định 2 khớp, băng vô trùng vết thương hở.',
      requiredEquipment: const ['Nẹp Kramer', 'Băng ép vô trùng'],
    ),
  ];

  Stream<List<IncidentModel>> get incidentsStream => _incidentsController.stream;
  List<IncidentModel> get currentIncidents => _incidents;

  DispatcherRealtimeService() {
    _notify();
  }

  void _notify() {
    if (!_incidentsController.isClosed) {
      _incidentsController.add(List.unmodifiable(_incidents));
    }
  }

  /// Cập nhật trạng thái tiến trình 7 bước
  void updateIncidentStatus(String incidentId, IncidentLifecycle newStatus) {
    _incidents = _incidents.map((inc) {
      if (inc.id == incidentId) {
        return inc.copyWith(status: newStatus);
      }
      return inc;
    }).toList();
    _notify();
  }

  /// Điều phối kíp xe cứu thương
  void dispatchAmbulance(String incidentId, String ambulanceName, int etaMinutes) {
    _incidents = _incidents.map((inc) {
      if (inc.id == incidentId) {
        return inc.copyWith(
          status: IncidentLifecycle.dispatched,
          assignedAmbulance: ambulanceName,
          etaMinutes: etaMinutes,
        );
      }
      return inc;
    }).toList();
    _notify();
  }

  /// Cập nhật dữ liệu Telemetry P2 thời gian thực từ hiện trường
  void updateLiveTelemetry(String clientUuid, {required double ccf, required int bpm, required int elapsed}) {
    _incidents = _incidents.map((inc) {
      if (inc.clientUuid == clientUuid) {
        return inc.copyWith(
          liveCcf: ccf,
          liveBpm: bpm,
          elapsedSeconds: elapsed,
        );
      }
      return inc;
    }).toList();
    _notify();
  }

  /// Tiếp nhận trực tiếp tín hiệu P0 SOS vừa kích hoạt từ SQLite Outbox trên thiết bị
  void registerLiveSosIncident({
    required String clientUuid,
    required String incidentType,
    required double lat,
    required double lng,
    required String callerPhone,
  }) {
    final shortId = 'SOS-${clientUuid.substring(0, 4).toUpperCase()}';
    if (_incidents.any((e) => e.clientUuid == clientUuid || e.id == shortId)) return;

    final liveIncident = IncidentModel(
      id: shortId,
      clientUuid: clientUuid,
      callerName: 'Người dùng Thiết bị Hiện tại (Live SOS)',
      callerPhone: callerPhone,
      incidentType: incidentType == 'CARDIAC_ARREST'
          ? 'P0 SOS Thực tế: Ngưng tim / Ép tim CPR'
          : 'P0 SOS Thực tế: $incidentType',
      priority: PriorityTier.p0Critical,
      status: IncidentLifecycle.accepted,
      lat: lat,
      lng: lng,
      address: 'Tọa độ GPS trực tiếp: ${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
      reportedAt: DateTime.now(),
      aiTriageRecommendation: 'Ca SOS vừa ghi nhận từ SQLite Outbox cục bộ. Ưu tiên điều xe 115 và hướng dẫn CPR 110 BPM.',
      requiredEquipment: const ['Máy khử rung tim AED', 'Bóng Ambu', 'Oxy cấp cứu'],
    );
    _incidents = [liveIncident, ..._incidents];
    _notify();
  }

  /// Đồng bộ các bản ghi SOS_TRIGGERED đang lưu trong bảng outbox_events của Drift SQLite
  void ingestOutboxEvents(List<OutboxEventEntry> events) {
    for (final ev in events) {
      if (ev.eventType != 'SOS_TRIGGERED') continue;
      try {
        final decoded = jsonDecode(ev.payloadJson) as Map<String, dynamic>;
        final uuid = decoded['client_uuid']?.toString() ?? ev.id;
        final incType = decoded['incident_type']?.toString() ?? 'EMERGENCY_SOS';
        final loc = decoded['location'] as Map<String, dynamic>?;
        final lat = (loc?['lat'] as num?)?.toDouble() ?? 15.9752;
        final lng = (loc?['lng'] as num?)?.toDouble() ?? 108.2523;
        registerLiveSosIncident(
          clientUuid: uuid,
          incidentType: incType,
          lat: lat,
          lng: lng,
          callerPhone: '115 / Local Outbox',
        );
      } catch (_) {}
    }
  }

  void dispose() {
    if (!identical(this, shared)) {
      _incidentsController.close();
    }
  }
}
