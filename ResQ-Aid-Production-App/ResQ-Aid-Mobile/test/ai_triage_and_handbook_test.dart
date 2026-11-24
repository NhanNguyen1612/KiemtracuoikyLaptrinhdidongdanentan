import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';
import 'package:resq_aid/core/database/app_database.dart';
import 'package:resq_aid/core/services/ai_triage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FEATURE 5 & FEATURE 6: AI TRIAGE, CẨM NANG OFFLINE & NGHỊ ĐỊNH 13', () {
    late AppDatabase testDb;

    setUp(() async {
      testDb = AppDatabase.forTesting(NativeDatabase.memory());
      // Warm-up and seed protocols
      await testDb.getAllProtocols();
    });

    tearDown(() async {
      await testDb.close();
    });

    test('1. Tra cứu Cẩm nang Sơ cứu Offline: Mở phác đồ trong <= 300ms (US-07 NFR)', () async {
      final stopwatch = Stopwatch()..start();
      final protocols = await testDb.getAllProtocols();
      stopwatch.stop();

      // NFR-US-07: Thời gian truy vấn SQLite <= 300ms
      expect(stopwatch.elapsedMilliseconds, lessThanOrEqualTo(300), reason: 'Mở phác đồ phải <= 300ms');
      expect(protocols.length, equals(20), reason: 'Phải nạp đủ 20 phác đồ y khoa chuẩn hóa (bao gồm đứt tay, khủng hoảng tâm thần, nhồi máu cơ tim, rắn cắn...)');

      final cardiac = protocols.firstWhere((p) => p.protocolCode == 'PROTO_CARDIAC_ARREST');
      expect(cardiac.title, contains('CPR 110 BPM'));
      expect(cardiac.contentJson, contains('Hands-only CPR'));

      // Kiểm tra phác đồ đứt tay (PROTO_CUT_BLEEDING)
      final cut = protocols.firstWhere((p) => p.protocolCode == 'PROTO_CUT_BLEEDING');
      expect(cut.title, contains('Đứt Tay'));
      expect(cut.contentJson, contains('ấn chặt'));

      // Kiểm tra phác đồ khủng hoảng tâm thần (PROTO_MENTAL_CRISIS)
      final mental = protocols.firstWhere((p) => p.protocolCode == 'PROTO_MENTAL_CRISIS');
      expect(mental.title, contains('Tâm thần'));
      expect(mental.contentJson, contains('Box Breathing'));
    });

    test('2. AI Triage Gemini & 4 Rào chắn Y khoa (Medical Safeguards)', () async {
      final triageService = AiTriageService();

      final result = await triageService.triageEmergency(
        description: 'Phát hiện nạn nhân ngã gục, lay vai không phản ứng, lồng ngực không thở',
        isUnconscious: true,
        isNotBreathing: true,
      );

      // Phân loại đúng P0
      expect(result.urgency, equals(TriageUrgency.p0Critical));
      expect(result.confidence, greaterThanOrEqualTo(0.85));
      expect(result.isFallback, isTrue);

      // Rào chắn 2: Bắt buộc đính kèm Disclaimer pháp lý
      expect(result.medicalDisclaimer, contains('LƯU Ý PHÁP LÝ & AN TOÀN Y KHOA'));

      // Rào chắn 3: Trang bị y tế chuẩn tiền viện
      expect(result.recommendedEquipment, contains('Máy AED'));
    });

    test('3. Fallback Heuristic 3 Cấp độ khi mất mạng: Phản hồi <= 20ms (INFRA-04)', () async {
      final triageService = AiTriageService();

      final result = await triageService.triageEmergency(
        description: 'Người bị co giật, sùi bọt mép ngoài bãi biển',
        isUnconscious: false,
        isNotBreathing: false,
      );

      // Nhận diện Fallback thành công
      expect(result.isFallback, isTrue);
      expect(result.urgency, equals(TriageUrgency.p1Urgent));
      expect(result.justification, contains('[HEURISTIC RULE-02]'));

      // Phản hồi siêu tốc <= 20ms
      expect(result.latencyMs, lessThanOrEqualTo(20), reason: 'Fallback Heuristic phải <= 20ms (thực tế: ${result.latencyMs}ms)');
    });

    test('4. Quyền được lãng quên theo Nghị định 13: Xóa sạch dữ liệu trong <= 2.0s (US-06)', () async {
      // Thêm 2 sự kiện vào Outbox
      await testDb.insertOutboxEvent(OutboxEventsCompanion(
        id: drift.Value(const Uuid().v4()),
        eventType: const drift.Value('TEST_EVENT'),
        priority: const drift.Value(0),
        payloadJson: const drift.Value('{"test": true}'),
      ));

      var pending = await testDb.getPendingEvents();
      expect(pending.isNotEmpty, isTrue);

      final stopwatch = Stopwatch()..start();
      // Thực hiện xóa sạch dữ liệu cá nhân
      await testDb.purgeAllLocalData();
      stopwatch.stop();

      // NFR-US-06: Hoàn tất xóa <= 2.0s
      expect(stopwatch.elapsedMilliseconds, lessThanOrEqualTo(2000));

      final pendingAfter = await testDb.getPendingEvents();
      expect(pendingAfter.isEmpty, isTrue, reason: 'Toàn bộ dữ liệu Outbox phải bị xóa sạch');
    });

    test('5. Tìm kiếm Cẩm nang Sơ cứu Offline: Tìm chính xác từ khóa "đứt tay", "thần kinh", "sốc nhiệt"', () async {
      final protocols = await testDb.getAllProtocols();
      expect(protocols.length, equals(20));

      // Hàm lọc tương tự như HandbookListScreen
      List<ProtocolEntry> search(String query) {
        final q = query.trim().toLowerCase();
        return protocols.where((p) {
          return p.title.toLowerCase().contains(q) ||
              p.protocolCode.toLowerCase().contains(q) ||
              p.contentJson.toLowerCase().contains(q);
        }).toList();
      }

      // Test tìm "đứt tay"
      final cutResults = search('đứt tay');
      expect(cutResults.isNotEmpty, isTrue, reason: 'Phải tìm thấy phác đồ khi search "đứt tay"');
      expect(cutResults.any((p) => p.protocolCode == 'PROTO_CUT_BLEEDING'), isTrue);

      // Test tìm "thần kinh"
      final mentalResults = search('thần kinh');
      expect(mentalResults.isNotEmpty, isTrue, reason: 'Phải tìm thấy phác đồ khi search "thần kinh"');
      expect(mentalResults.any((p) => p.protocolCode == 'PROTO_MENTAL_CRISIS'), isTrue);

      // Test tìm "sốc nhiệt"
      final heatResults = search('sốc nhiệt');
      expect(heatResults.isNotEmpty, isTrue, reason: 'Phải tìm thấy phác đồ khi search "sốc nhiệt"');
      expect(heatResults.any((p) => p.protocolCode == 'PROTO_HEAT_STROKE'), isTrue);

      // Test tìm "rắn cắn"
      final snakeResults = search('rắn cắn');
      expect(snakeResults.isNotEmpty, isTrue, reason: 'Phải tìm thấy phác đồ khi search "rắn cắn"');
      expect(snakeResults.any((p) => p.protocolCode == 'PROTO_SNAKE_BITE'), isTrue);
    });
  });
}
