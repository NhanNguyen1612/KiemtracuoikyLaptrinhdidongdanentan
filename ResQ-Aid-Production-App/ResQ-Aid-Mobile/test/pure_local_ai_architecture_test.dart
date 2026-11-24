import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:resq_aid/core/ai/medical_neural_nlp_engine.dart';
import 'package:resq_aid/core/database/app_database.dart';
import 'package:resq_aid/features/dispatcher/services/dispatcher_realtime_service.dart';
import 'package:resq_aid/features/medical_facilities/services/offline_graph_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PURE ON-DEVICE LOCAL AI & GRAPH A* ARCHITECTURE VERIFICATION', () {
    test('1. MedicalNeuralNlpEngine: 128D Unit-Sphere Embedding & Vector RAG Cosine Retrieval', () {
      final engine = MedicalNeuralNlpEngine.instance;
      engine.ensureInitializedSync();
      expect(engine.protocolCount, greaterThanOrEqualTo(60));

      final pred = engine.infer('bất tỉnh không thở nữa');
      // Kiểm chứng chuẩn L2 ||e||_2 == 1.0
      double normSq = 0.0;
      for (final v in pred.embedding128d) {
        normSq += v * v;
      }
      expect(math.sqrt(normSq), closeTo(1.0, 1e-4));
      expect(pred.topProtocol.urgency, equals(0));
      expect(pred.safetyClassIndex, equals(1)); // CARDIAC_ARREST_P0
      expect(pred.docEntropy, lessThan(0.6));
    });

    test('2. Conv1D Sequence Negation Sensitivity: Phân biệt có triệu chứng vs phủ định triệu chứng', () {
      final engine = MedicalNeuralNlpEngine.instance;
      final posPred = engine.infer('bị đau thắt ngực nhồi máu cơ tim');
      final negPred = engine.infer('tôi hơi mệt nhưng không đau ngực');

      expect(posPred.topProtocol.id, equals('heart_attack_acute'));
      expect(negPred.topProtocol.id, isNot(equals('heart_attack_acute')));
    });

    test('3. OfflineGraphRouter A*: Tìm đường bám sát mặt đường thật tại Đà Nẵng, Hà Nội, TP.HCM', () {
      final router = OfflineGraphRouter.instance();
      expect(router.nodes.length, greaterThan(15));

      // VKU (15.9752, 108.2523) -> Bệnh Viện Đà Nẵng (16.0732, 108.2144)
      final routeDn = router.computeRoute(
        startLat: 15.9752,
        startLng: 108.2523,
        destLat: 16.0732,
        destLng: 108.2144,
        destinationName: 'Bệnh Viện Đà Nẵng',
      );

      expect(routeDn.isGraphRouted, isTrue);
      expect(routeDn.waypoints.length, greaterThanOrEqualTo(4), reason: 'Lộ trình A* phải đi qua nhiều nút giao đường bộ thay vì kẻ 2 điểm chim bay');
      expect(routeDn.turnByTurnSteps, isNotEmpty);
    });

    test('4. Live SQLite Outbox -> DispatcherRealtimeService Synchronization', () {
      final svc = DispatcherRealtimeService();
      final beforeCount = svc.currentIncidents.length;

      final fakeOutboxEvent = OutboxEventEntry(
        id: '12345678-abcd-ef00-1122-334455667788',
        eventType: 'SOS_TRIGGERED',
        priority: 0,
        payloadJson:
            '{"client_uuid":"12345678-abcd-ef00-1122-334455667788","incident_type":"CARDIAC_ARREST","location":{"lat":15.9752,"lng":108.2523}}',
        status: 'PENDING',
        retryCount: 0,
        createdAt: DateTime.now(),
      );

      svc.ingestOutboxEvents([fakeOutboxEvent]);
      expect(svc.currentIncidents.length, equals(beforeCount + 1));
      expect(svc.currentIncidents.first.id, equals('SOS-1234'));
      svc.dispose();
    });
  });
}
