import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';
import 'package:resq_aid/core/database/app_database.dart';
import 'package:resq_aid/core/services/outbox_sync_service.dart';
import 'package:resq_aid/features/sos/data/sos_payload.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FEATURE 1 & FEATURE 3: KHỞI TẠO SOS & ĐỒNG BỘ NGOẠI TUYẾN OUTBOX', () {
    late AppDatabase testDb;

    setUp(() async {
      testDb = AppDatabase.forTesting(NativeDatabase.memory());
      // Warm-up schema
      await testDb.getPendingEvents();
    });

    tearDown(() async {
      await testDb.close();
    });

    test('1. Gói tin P0 SOS: Kích thước < 1KB và Độ trễ ghi SQLite <= 100ms (NFR-M1, M2)', () async {
      final uuid = const Uuid().v4();
      final p0 = SosPayloadP0(
        clientUuid: uuid,
        deviceId: 'device_test_115',
        createdAt: DateTime.now(),
        incidentType: 'CARDIAC_ARREST',
        location: LocationData(lat: 16.0544, lng: 108.2022, accuracyM: 3.2, source: 'GPS'),
        isDemo: true,
      );

      final p0Json = p0.toJsonString();
      final byteSize = utf8.encode(p0Json).length;

      // NFR-M2: Payload P0 phải < 1024 bytes
      expect(byteSize, lessThan(1024), reason: 'Gói tin P0 phải < 1KB (thực tế: $byteSize bytes)');
      expect(p0Json, contains('"client_uuid":"$uuid"'));
      expect(p0Json, contains('"is_demo":true'));

      // NFR-M1: Thời gian ghi Drift SQLite <= 100ms
      final stopwatch = Stopwatch()..start();
      await testDb.insertOutboxEvent(
        OutboxEventsCompanion(
          id: drift.Value(uuid),
          eventType: const drift.Value('SOS_TRIGGERED'),
          priority: const drift.Value(0), // P0
          payloadJson: drift.Value(p0Json),
          status: const drift.Value('PENDING'),
          createdAt: drift.Value(DateTime.now()),
        ),
      );
      stopwatch.stop();

      final latencyMs = stopwatch.elapsedMilliseconds;
      expect(latencyMs, lessThanOrEqualTo(100), reason: 'Độ trễ ghi SQLite phải <= 100ms (thực tế: $latencyMs ms)');

      final pending = await testDb.getPendingEvents();
      expect(pending.length, equals(1));
      expect(pending.first.id, equals(uuid));
      expect(pending.first.priority, equals(0));
    });

    test('2. Phân tầng thứ tự ưu tiên: P0 được đẩy trước P1, P1 trước P2 (NFR-Priority)', () async {
      final dispatchedOrder = <int>[];

      final syncService = OutboxSyncService(
        database: testDb,
        remoteDispatcher: (event) async {
          dispatchedOrder.add(event.priority);
          return true;
        },
      );

      // Thêm lộn xộn: P2 trước, rồi P1, rồi P0
      final now = DateTime.now();
      await testDb.insertOutboxEvent(OutboxEventsCompanion(
        id: drift.Value(const Uuid().v4()),
        eventType: const drift.Value('P2_TELEMETRY'),
        priority: const drift.Value(2),
        payloadJson: const drift.Value('{"type":"P2"}'),
        status: const drift.Value('PENDING'),
        createdAt: drift.Value(now.add(const Duration(seconds: 1))),
      ));

      await testDb.insertOutboxEvent(OutboxEventsCompanion(
        id: drift.Value(const Uuid().v4()),
        eventType: const drift.Value('P1_MILESTONE'),
        priority: const drift.Value(1),
        payloadJson: const drift.Value('{"type":"P1"}'),
        status: const drift.Value('PENDING'),
        createdAt: drift.Value(now.add(const Duration(seconds: 2))),
      ));

      await testDb.insertOutboxEvent(OutboxEventsCompanion(
        id: drift.Value(const Uuid().v4()),
        eventType: const drift.Value('P0_SOS'),
        priority: const drift.Value(0),
        payloadJson: const drift.Value('{"type":"P0"}'),
        status: const drift.Value('PENDING'),
        createdAt: drift.Value(now.add(const Duration(seconds: 3))),
      ));

      final pending = await testDb.getPendingEvents();
      expect(pending.length, equals(3));

      // Thực hiện đồng bộ
      await syncService.syncPendingEvents();

      // Kiểm tra thứ tự: Bắt buộc phải là [0, 1, 2] (P0 -> P1 -> P2)
      expect(dispatchedOrder, equals([0, 1, 2]), reason: 'Thứ tự gửi phải là P0 -> P1 -> P2');

      // Sau khi gửi xong, hàng đợi phải rỗng
      final remaining = await testDb.getPendingEvents();
      expect(remaining.isEmpty, isTrue);

      syncService.dispose();
    });

    test('3. Kịch bản Đèo Hải Vân: Mất sóng dồn ứ Outbox -> Có mạng Re-sync hoàn toàn không mất gói (NFR-M5)', () async {
      final cloudRecords = <String, String>{};

      final syncService = OutboxSyncService(
        database: testDb,
        remoteDispatcher: (event) async {
          // Idempotent Upsert: Ghi nhận bản ghi trên mây theo Client UUID
          cloudRecords[event.id] = event.payloadJson;
          return true;
        },
      );

      // Giai đoạn 1: Mất mạng qua Đèo Hải Vân, thiết bị tích lũy 4 sự kiện
      final eventIds = <String>[];
      for (int i = 0; i < 4; i++) {
        final id = 'haivan_event_$i';
        eventIds.add(id);
        await testDb.insertOutboxEvent(OutboxEventsCompanion(
          id: drift.Value(id),
          eventType: drift.Value(i == 0 ? 'SOS' : 'CPR'),
          priority: drift.Value(i == 0 ? 0 : 2),
          payloadJson: drift.Value('{"step":$i}'),
          status: const drift.Value('PENDING'),
          createdAt: drift.Value(DateTime.now()),
        ));
      }

      var pending = await testDb.getPendingEvents();
      expect(pending.length, equals(4), reason: '4 gói tin phải được bảo toàn trong SQLite');
      expect(cloudRecords.isEmpty, isTrue, reason: 'Chưa có mạng nên đám mây chưa nhận gì');

      // Giai đoạn 2: Xe cấp cứu ra khỏi vùng mù sóng -> Kích hoạt Re-sync
      final status = await syncService.syncPendingEvents();

      // NFR-M5: Thời gian Re-sync <= 2.0s
      expect(status.lastSyncLatencyMs, lessThanOrEqualTo(2000), reason: 'Thời gian phục hồi Re-sync phải <= 2s');
      expect(status.pendingCount, equals(0));
      expect(status.syncedCount, equals(4));

      // Đảm bảo đám mây nhận đủ 4 bản ghi không sót bản nào
      expect(cloudRecords.length, equals(4));
      for (final id in eventIds) {
        expect(cloudRecords.containsKey(id), isTrue);
      }

      // Giai đoạn 3: Idempotent - Gửi lại lần nữa không tạo thêm bản ghi trùng lặp
      await syncService.syncPendingEvents();
      expect(cloudRecords.length, equals(4), reason: 'Idempotent: Số bản ghi trên mây không đổi');

      syncService.dispose();
    });
  });
}
