import 'package:drift/drift.dart';

@DataClassName('ProtocolEntry')
class Protocols extends Table {
  TextColumn get protocolCode => text()(); // e.g. PROTO_CHOKING, PROTO_DROWNING
  TextColumn get title => text()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get contentJson => text()();
  TextColumn get status => text().withDefault(const Constant('PUBLISHED'))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {protocolCode};
}
