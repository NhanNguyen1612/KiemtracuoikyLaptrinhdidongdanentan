import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../database/app_database.dart';

typedef RemoteSyncDispatcher = Future<bool> Function(OutboxEventEntry event);

class OutboxSyncStatus {
  final int pendingCount;
  final int syncedCount;
  final bool isSyncing;
  final DateTime? lastSyncTime;
  final int lastSyncLatencyMs;
  final String? lastError;

  const OutboxSyncStatus({
    this.pendingCount = 0,
    this.syncedCount = 0,
    this.isSyncing = false,
    this.lastSyncTime,
    this.lastSyncLatencyMs = 0,
    this.lastError,
  });

  OutboxSyncStatus copyWith({
    int? pendingCount,
    int? syncedCount,
    bool? isSyncing,
    DateTime? lastSyncTime,
    int? lastSyncLatencyMs,
    String? lastError,
  }) {
    return OutboxSyncStatus(
      pendingCount: pendingCount ?? this.pendingCount,
      syncedCount: syncedCount ?? this.syncedCount,
      isSyncing: isSyncing ?? this.isSyncing,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      lastSyncLatencyMs: lastSyncLatencyMs ?? this.lastSyncLatencyMs,
      lastError: lastError,
    );
  }
}

/// Dịch vụ Đồng bộ Hàng đợi Ngoại tuyến (Outbox Sync Worker)
/// Hiện thực hóa giải pháp chống mất dữ liệu kịch bản Đèo Hải Vân
class OutboxSyncService {
  final AppDatabase database;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  RemoteSyncDispatcher? _remoteDispatcher;
  bool _isDisposed = false;

  final _statusController = StreamController<OutboxSyncStatus>.broadcast();
  OutboxSyncStatus _status = const OutboxSyncStatus();

  Stream<OutboxSyncStatus> get statusStream => _statusController.stream;
  OutboxSyncStatus get currentStatus => _status;

  OutboxSyncService({required this.database, RemoteSyncDispatcher? remoteDispatcher}) {
    // This app has no cloud transport. Keep events in the local outbox until
    // a real sync endpoint is deliberately configured.
    _remoteDispatcher = remoteDispatcher;
    _initConnectivityListener();
    refreshCounts();
  }

  void setRemoteDispatcherForTest(RemoteSyncDispatcher dispatcher) {
    _remoteDispatcher = dispatcher;
  }

  void _initConnectivityListener() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      final hasConnection = results.any((r) => r != ConnectivityResult.none);
      if (hasConnection && !_status.isSyncing) {
        // Có mạng trở lại -> Tự động kích hoạt đồng bộ toàn bộ hàng đợi dồn ứ
        syncPendingEvents();
      }
    });
  }

  Future<void> refreshCounts() async {
    final pending = await database.getPendingEvents();
    final allEvents = await database.select(database.outboxEvents).get();
    final synced = allEvents.where((e) => e.status == 'SYNCED').length;

    _status = _status.copyWith(
      pendingCount: pending.length,
      syncedCount: synced,
    );
    if (!_statusController.isClosed) {
      _statusController.add(_status);
    }
  }

  /// Đồng bộ tuần tự theo thứ tự ưu tiên P0 -> P1 -> P2 -> P3
  /// Áp dụng cơ chế Idempotent Upsert và đo đạc Re-sync Latency
  Future<OutboxSyncStatus> syncPendingEvents() async {
    if (_status.isSyncing) return _status;

    final pendingList = await database.getPendingEvents();
    if (pendingList.isEmpty) {
      await refreshCounts();
      return _status;
    }

    if (_remoteDispatcher == null) {
      _status = _status.copyWith(lastError: 'Ứng dụng đang chạy ngoại tuyến; dữ liệu vẫn được giữ trên thiết bị.');
      if (!_statusController.isClosed) _statusController.add(_status);
      return _status;
    }

    _status = _status.copyWith(isSyncing: true, lastError: null);
    if (!_statusController.isClosed) _statusController.add(_status);

    final totalStopwatch = Stopwatch()..start();

    // Sắp xếp ưu tiên: P0 trước, sau đó P1, P2, P3
    final sortedList = List<OutboxEventEntry>.from(pendingList)
      ..sort((a, b) {
        final prioCompare = a.priority.compareTo(b.priority);
        if (prioCompare != 0) return prioCompare;
        return a.createdAt.compareTo(b.createdAt);
      });

    for (final event in sortedList) {
      bool success = false;
      int retry = 0;
      const maxRetries = 3;

      while (!success && retry < maxRetries) {
        try {
          success = await _remoteDispatcher!(event);
          if (success) {
            await database.markEventSynced(event.id);
          } else {
            retry++;
            await Future.delayed(Duration(milliseconds: 50 * (1 << retry))); // Exponential backoff
          }
        } catch (e) {
          retry++;
          await Future.delayed(Duration(milliseconds: 50 * (1 << retry)));
        }
      }
    }

    totalStopwatch.stop();
    await refreshCounts();

    _status = _status.copyWith(
      isSyncing: false,
      lastSyncTime: DateTime.now(),
      lastSyncLatencyMs: totalStopwatch.elapsedMilliseconds,
    );

    if (!_statusController.isClosed) _statusController.add(_status);
    return _status;
  }

  void dispose() {
    _isDisposed = true;
    _connectivitySubscription?.cancel();
    _statusController.close();
  }
}
