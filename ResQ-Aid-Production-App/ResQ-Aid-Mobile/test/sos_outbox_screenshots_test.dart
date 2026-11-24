import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:resq_aid/core/database/app_database.dart';
import 'package:resq_aid/core/providers/database_provider.dart';
import 'package:resq_aid/core/theme/app_theme.dart';
import 'package:resq_aid/features/home/presentation/home_screen.dart';
import 'package:resq_aid/features/sos/presentation/emergency_sos_screen.dart';

Future<void> _loadTestFonts() async {
  final fontFile = File(r'C:\Windows\Fonts\segoeui.ttf');
  if (await fontFile.exists()) {
    final bytes = await fontFile.readAsBytes();
    for (final name in ['Roboto', 'Segoe UI', '.SF Pro Text', '.SF UI Text']) {
      final fontLoader = FontLoader(name);
      fontLoader.addFont(Future.value(ByteData.view(bytes.buffer)));
      await fontLoader.load();
    }
  }

  final iconFile = File(r'D:\Flutter SDK\flutter_windows_3.47.6-stable\flutter\bin\cache\artifacts\material_fonts\materialicons-regular.otf');
  if (await iconFile.exists()) {
    final iconBytes = await iconFile.readAsBytes();
    final iconLoader = FontLoader('MaterialIcons');
    iconLoader.addFont(Future.value(ByteData.view(iconBytes.buffer)));
    await iconLoader.load();
  }
}

void main() {
  late AppDatabase testDb;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadTestFonts();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    testDb = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await testDb.close();
  });

  Widget createTestWidget(Widget child) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(testDb),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        home: child,
      ),
    );
  }

  group('FEATURE 1 & 3: CHỤP ẢNH MINH CHỨNG THỰC THI (GOLDEN SCREENSHOTS)', () {
    testWidgets('1. Chụp ảnh: SOS Triage Bước 1 An toàn hiện trường', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget(const EmergencySosScreen()));
      await tester.pump(const Duration(milliseconds: 200));

      await expectLater(
        find.byType(EmergencySosScreen),
        matchesGoldenFile('goldens/f1_sos_step1_safety.png'),
      );
    });

    testWidgets('2. Chụp ảnh: Trang chủ với Hàng đợi Outbox SQLite & Demo Mode', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget(const HomeScreen()));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(HomeScreen),
        matchesGoldenFile('goldens/f3_home_outbox_synced.png'),
      );
    });
  });
}
