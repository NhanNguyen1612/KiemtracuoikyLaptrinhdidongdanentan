import 'dart:async';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' as drift;
import '../../../../core/database/app_database.dart';
import '../domain/cpr_session_state.dart';

typedef StateProvider = CprSessionState Function();

/// Service gom nhóm (batch) gói tin Telemetry P2 mỗi 5 giây lưu vào Drift SQLite
class CprTelemetryBatcher {
  final AppDatabase database;
  final String clientUuid;
  Timer? _batchTimer;
  int _batchCount = 0;
  int _lastWriteLatencyMs = 0;
  bool _isBatching = false;

  CprTelemetryBatcher({required this.database, required this.clientUuid});

  int get batchCount => _batchCount;
  int get lastWriteLatencyMs => _lastWriteLatencyMs;
  bool get isBatching => _isBatching;

  void startBatching(StateProvider stateProvider) {
    if (_isBatching) return;
    _isBatching = true;

    // Định kỳ 5 giây gom 1 gói P2 Telemetry
    _batchTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      final state = stateProvider();
      if (!state.isRunning) return;
      await recordTelemetryBatch(state);
    });
  }

  Future<int> recordTelemetryBatch(CprSessionState state) async {
    final batchUuid = const Uuid().v4();
    final p2Json = state.toTelemetryP2Json(clientUuid: clientUuid);

    final stopwatch = Stopwatch()..start();
    await database.insertOutboxEvent(
      OutboxEventsCompanion(
        id: drift.Value(batchUuid),
        eventType: const drift.Value('CPR_TELEMETRY'),
        priority: const drift.Value(2), // P2: Telemetry batch
        payloadJson: drift.Value(p2Json),
        status: const drift.Value('PENDING'),
        createdAt: drift.Value(DateTime.now()),
      ),
    );
    stopwatch.stop();

    _lastWriteLatencyMs = stopwatch.elapsedMilliseconds;
    _batchCount++;
    return _lastWriteLatencyMs;
  }

  void stop() {
    _batchTimer?.cancel();
    _batchTimer = null;
    _isBatching = false;
  }
}
