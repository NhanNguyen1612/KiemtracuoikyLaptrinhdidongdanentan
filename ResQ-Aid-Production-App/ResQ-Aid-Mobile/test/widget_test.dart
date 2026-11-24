import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resq_aid/core/database/app_database.dart';
import 'package:resq_aid/core/providers/database_provider.dart';
import 'package:resq_aid/main.dart';

void main() {
  testWidgets('ResQ-Aid App smoke test', (WidgetTester tester) async {
    final testDb = AppDatabase.forTesting(NativeDatabase.memory());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(testDb),
        ],
        child: const ResQAidApp(),
      ),
    );

    await tester.pumpAndSettle();

    // Kiểm tra các thành phần cốt lõi xuất hiện trên màn hình
    expect(find.text('ResQ-Aid v2.0'), findsOneWidget);
    expect(find.textContaining('GỌI CẤP CỨU'), findsWidgets);
    expect(find.text('TÔI CẦN HƯỚNG DẪN SƠ CỨU'), findsOneWidget);

    await testDb.close();
  });
}
