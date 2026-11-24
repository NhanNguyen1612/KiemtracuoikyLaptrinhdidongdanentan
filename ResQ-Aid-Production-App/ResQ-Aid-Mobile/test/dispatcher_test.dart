import 'package:flutter_test/flutter_test.dart';
import 'package:resq_aid/features/dispatcher/domain/incident_model.dart';
import 'package:resq_aid/features/dispatcher/services/dispatcher_realtime_service.dart';

void main() {
  group('FEATURE 4: ĐIỀU PHỐI TRỰC CHIẾN 115 TRÊN FLUTTER WEB', () {
    test('1. Quản trị vòng đời ca cấp cứu 7 bước (Incident Lifecycle Transitions)', () {
      final service = DispatcherRealtimeService();
      final incident = service.currentIncidents.first;
      expect(incident.status, equals(IncidentLifecycle.dispatched));

      // Bước 4: Xe đang đến
      service.updateIncidentStatus(incident.id, IncidentLifecycle.enRoute);
      var updated = service.currentIncidents.firstWhere((i) => i.id == incident.id);
      expect(updated.status, equals(IncidentLifecycle.enRoute));

      // Bước 5: Tiếp cận hiện trường
      service.updateIncidentStatus(incident.id, IncidentLifecycle.onScene);
      updated = service.currentIncidents.firstWhere((i) => i.id == incident.id);
      expect(updated.status, equals(IncidentLifecycle.onScene));

      // Bước 6: Đang chuyển viện
      service.updateIncidentStatus(incident.id, IncidentLifecycle.transporting);
      updated = service.currentIncidents.firstWhere((i) => i.id == incident.id);
      expect(updated.status, equals(IncidentLifecycle.transporting));

      // Bước 7: Đóng ca cấp cứu
      service.updateIncidentStatus(incident.id, IncidentLifecycle.closed);
      updated = service.currentIncidents.firstWhere((i) => i.id == incident.id);
      expect(updated.status, equals(IncidentLifecycle.closed));

      service.dispose();
    });

    test('2. Ra lệnh điều xe cứu thương kèm ETA dự kiến tiếp cận', () {
      final service = DispatcherRealtimeService();
      final targetInc = service.currentIncidents[1]; // Ca bãi biển chưa điều xe
      expect(targetInc.assignedAmbulance, isNull);

      service.dispatchAmbulance(targetInc.id, 'Xe 115-02 (Trạm Sơn Trà)', 5);

      final updated = service.currentIncidents.firstWhere((i) => i.id == targetInc.id);
      expect(updated.status, equals(IncidentLifecycle.dispatched));
      expect(updated.assignedAmbulance, equals('Xe 115-02 (Trạm Sơn Trà)'));
      expect(updated.etaMinutes, equals(5));

      service.dispose();
    });

    test('3. Cập nhật Telemetry CCF thời gian thực từ hiện trường (NFR <= 500ms)', () {
      final service = DispatcherRealtimeService();
      final targetInc = service.currentIncidents.first;

      final stopwatch = Stopwatch()..start();
      service.updateLiveTelemetry(
        targetInc.clientUuid,
        ccf: 84.5,
        bpm: 112,
        elapsed: 240,
      );
      stopwatch.stop();

      final latencyMs = stopwatch.elapsedMilliseconds;
      expect(latencyMs, lessThanOrEqualTo(500), reason: 'Độ trễ cập nhật Telemetry phải <= 500ms');

      final updated = service.currentIncidents.firstWhere((i) => i.clientUuid == targetInc.clientUuid);
      expect(updated.liveCcf, equals(84.5));
      expect(updated.liveBpm, equals(112));
      expect(updated.elapsedSeconds, equals(240));

      service.dispose();
    });
  });
}
