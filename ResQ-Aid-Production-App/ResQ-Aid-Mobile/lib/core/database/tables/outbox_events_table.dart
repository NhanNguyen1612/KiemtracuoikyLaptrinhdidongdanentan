import 'package:drift/drift.dart';

@DataClassName('OutboxEventEntry')
class OutboxEvents extends Table {
  TextColumn get id => text()(); // Client UUIDv4
  TextColumn get eventType => text()(); // e.g. SOS_TRIGGERED, CPR_STARTED
  IntColumn get priority => integer()(); // 0=P0, 1=P1, 2=P2, 3=P3
  TextColumn get payloadJson => text()(); // JSON string
  TextColumn get status => text().withDefault(const Constant('PENDING'))(); // PENDING, SYNCED, FAILED, DEFERRED
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get nextRetryAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get syncedAt => dateTime().nullable()();
  TextColumn get errorMessage => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
