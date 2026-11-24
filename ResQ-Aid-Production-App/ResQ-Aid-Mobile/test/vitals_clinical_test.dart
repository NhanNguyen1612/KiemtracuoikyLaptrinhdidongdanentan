import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resq_aid/features/cpr/presentation/cpr_coach_screen.dart';
import 'package:resq_aid/features/home/presentation/home_screen.dart';
import 'package:resq_aid/features/vitals/presentation/heart_rate_monitor_screen.dart';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resq_aid/core/database/app_database.dart';
import 'package:resq_aid/core/providers/database_provider.dart';
import 'package:resq_aid/features/cpr/presentation/cpr_coach_screen.dart';
import 'package:resq_aid/features/home/presentation/home_screen.dart';
import 'package:resq_aid/features/vitals/presentation/heart_rate_monitor_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase testDb;
  final originalOnError = FlutterError.onError;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    testDb = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    FlutterError.onError = originalOnError;
    await testDb.close();
  });

  group('AHA/ILCOR 2025 BLS Clinical Safety & Vitals Verification', () {
    testWidgets('1. CPRCoachScreen TUYỆT ĐỐI KHÔNG chứa nút đo nhịp tim camera để tránh gián đoạn ép tim', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      FlutterError.onError = (details) {
        if (!details.toString().contains('overflowed')) {
          FlutterError.presentError(details);
        }
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(testDb)],
          child: const MaterialApp(
            home: CPRCoachScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // Không được phép có text đo nhịp tim camera trên màn hình CPR
      expect(find.text('KIỂM TRA MẠCH & ĐO NHỊP TIM CAMERA (PPG)'), findsNothing);
      expect(find.textContaining('Bấm để đo nhịp tim quang học'), findsNothing);

      // Thay vào đó phải có hướng dẫn máy khử rung tim tự động AED
      expect(find.text('CHUẨN BỊ MÁY KHỬ RUNG TIM (AED)'), findsOneWidget);
    });

    testWidgets('2. HeartRateMonitorScreen có Banner cảnh báo khẩn cấp AHA/BLS & nút chuyển sang CPR ngay', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      FlutterError.onError = (details) {
        if (!details.toString().contains('overflowed')) {
          FlutterError.presentError(details);
        }
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(testDb)],
          child: const MaterialApp(
            home: HeartRateMonitorScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // Kiểm tra tiêu đề an toàn y khoa
      expect(find.text('THEO DÕI NHỊP MẠCH THAM KHẢO'), findsOneWidget);

      // Kiểm tra banner cảnh báo đỏ đường A (Không đáp ứng / không thở -> CPR ngay)
      expect(find.text('CẢNH BÁO Y TẾ KHẨN CẤP (AHA / BLS)'), findsOneWidget);
      expect(find.textContaining('Nếu nạn nhân BẤT TỈNH, KHÔNG THỞ hoặc THỞ NGÁP: KHÔNG ĐO NHỊP TIM!'), findsOneWidget);
      expect(find.text('CHUYỂN SANG ÉP TIM CPR NGAY'), findsOneWidget);
    });

    testWidgets('3. HomeScreen định vị lại tính năng thành "Theo Dõi Nhịp Mạch (Tham Khảo)"', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      FlutterError.onError = (details) {
        if (!details.toString().contains('overflowed')) {
          FlutterError.presentError(details);
        }
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(testDb)],
          child: const MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Theo Dõi Nhịp Mạch (Tham Khảo)'), findsOneWidget);
      expect(find.text('Đo Nhịp Tim Thực Tế'), findsNothing);
    });
  });
}
