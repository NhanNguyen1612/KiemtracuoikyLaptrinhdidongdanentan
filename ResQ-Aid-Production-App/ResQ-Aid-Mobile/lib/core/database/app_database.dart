import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'tables/outbox_events_table.dart';
import 'tables/protocols_table.dart';
import 'seed_data.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [OutboxEvents, Protocols])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 2;

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'resq_aid_local');
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      // Khi nâng cấp từ v1 lên v2: đồng bộ toàn bộ 20 phác đồ sơ cứu chuẩn y khoa vào SQLite
      if (from < 2) {
        for (final item in SeedProtocols.items) {
          await into(protocols).insert(
            ProtocolsCompanion(
              protocolCode: Value(item['protocol_code'] as String),
              title: Value(item['title'] as String),
              version: Value(item['version'] as int),
              contentJson: Value(SeedProtocols.getJsonString(item['content'] as Map<String, dynamic>)),
              status: const Value('PUBLISHED'),
              updatedAt: Value(DateTime.now()),
            ),
            mode: InsertMode.insertOrReplace,
          );
        }
      }
    },
    beforeOpen: (details) async {
      // Tự động đồng bộ toàn bộ 20 phác đồ sơ cứu chuẩn y khoa vào SQLite nội bộ
      for (final item in SeedProtocols.items) {
        await into(protocols).insert(
          ProtocolsCompanion(
            protocolCode: Value(item['protocol_code'] as String),
            title: Value(item['title'] as String),
            version: Value(item['version'] as int),
            contentJson: Value(SeedProtocols.getJsonString(item['content'] as Map<String, dynamic>)),
            status: const Value('PUBLISHED'),
            updatedAt: Value(DateTime.now()),
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    },
  );

  // --- OUTBOX QUERIES ---
  Future<int> insertOutboxEvent(OutboxEventsCompanion event) {
    return into(outboxEvents).insert(event, mode: InsertMode.insertOrReplace);
  }

  Future<List<OutboxEventEntry>> getPendingEvents() {
    return (select(outboxEvents)
          ..where((tbl) => tbl.status.isIn(['PENDING', 'FAILED']))
          ..orderBy([
            (tbl) => OrderingTerm(expression: tbl.priority, mode: OrderingMode.asc),
            (tbl) => OrderingTerm(expression: tbl.createdAt, mode: OrderingMode.asc),
          ]))
        .get();
  }

  Future<void> markEventSynced(String id) {
    return (update(outboxEvents)..where((tbl) => tbl.id.equals(id))).write(
      OutboxEventsCompanion(
        status: const Value('SYNCED'),
        syncedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> markEventFailed(String id, String error, int currentRetry) {
    final nextRetry = DateTime.now().add(Duration(seconds: (1 << currentRetry) * 2));
    final newStatus = currentRetry >= 10 ? 'DEFERRED' : 'FAILED';
    return (update(outboxEvents)..where((tbl) => tbl.id.equals(id))).write(
      OutboxEventsCompanion(
        status: Value(newStatus),
        retryCount: Value(currentRetry + 1),
        nextRetryAt: Value(nextRetry),
        errorMessage: Value(error),
      ),
    );
  }

  // --- PROTOCOLS QUERIES ---
  Future<List<ProtocolEntry>> getAllProtocols() {
    return select(protocols).get();
  }

  Future<ProtocolEntry?> getProtocolByCode(String code) {
    return (select(protocols)..where((tbl) => tbl.protocolCode.equals(code))).getSingleOrNull();
  }

  // --- NGHỊ ĐỊNH 13 PURGE DATA ---
  Future<void> purgeAllLocalData() async {
    await delete(outboxEvents).go();
  }
}
