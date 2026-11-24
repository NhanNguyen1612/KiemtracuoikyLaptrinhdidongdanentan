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
import 'package:resq_aid/features/consent/presentation/consent_screen.dart';
import 'package:resq_aid/features/handbook/presentation/handbook_list_screen.dart';
import 'package:resq_aid/features/settings/presentation/settings_screen.dart';

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

  group('FEATURE 5 & 6: CHỤP ẢNH MINH CHỨNG THỰC THI (GOLDEN SCREENSHOTS)', () {
    testWidgets('1. Chụp ảnh: Cẩm nang Sơ cứu Offline 10 Phác đồ', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget(const HandbookListScreen()));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(HandbookListScreen),
        matchesGoldenFile('goldens/f5_handbook_offline_list.png'),
      );
    });

    testWidgets('2. Chụp ảnh: Minh bạch Dữ liệu theo Nghị định 13/2023/NĐ-CP', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget(const ConsentScreen()));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(ConsentScreen),
        matchesGoldenFile('goldens/f6_consent_decree13.png'),
      );
    });

    testWidgets('3. Chụp ảnh: Cài đặt & Xóa sạch Dữ liệu (Quyền được lãng quên)', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget(const SettingsScreen()));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(SettingsScreen),
        matchesGoldenFile('goldens/f6_settings_data_purge.png'),
      );
    });
  });
}
