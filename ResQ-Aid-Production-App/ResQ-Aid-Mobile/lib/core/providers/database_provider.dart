import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../services/demo_mode_service.dart';
import '../services/outbox_sync_service.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

final outboxSyncServiceProvider = Provider<OutboxSyncService>((ref) {
  final db = ref.watch(databaseProvider);
  final service = OutboxSyncService(database: db);
  ref.onDispose(() => service.dispose());
  return service;
});

final outboxStatusStreamProvider = StreamProvider<OutboxSyncStatus>((ref) {
  final service = ref.watch(outboxSyncServiceProvider);
  return service.statusStream;
});

final demoModeProvider = NotifierProvider<DemoModeNotifier, bool>(DemoModeNotifier.new);

class DemoModeNotifier extends Notifier<bool> {
  @override
  bool build() {
    _loadState();
    return true;
  }

  Future<void> _loadState() async {
    state = await DemoModeService.isDemoMode();
  }

  Future<void> toggle() async {
    final newState = !state;
    await DemoModeService.setDemoMode(newState);
    state = newState;
  }
}
