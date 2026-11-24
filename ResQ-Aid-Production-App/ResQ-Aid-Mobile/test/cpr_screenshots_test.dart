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
import 'package:resq_aid/features/cpr/domain/cpr_session_state.dart';
import 'package:resq_aid/features/cpr/presentation/cpr_coach_screen.dart';
import 'package:resq_aid/features/cpr/presentation/cpr_handover_screen.dart';

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

  group('FEATURE 2: CHỤP ẢNH MINH CHỨNG THỰC THI (GOLDEN SCREENSHOTS)', () {
    testWidgets('1. Chụp ảnh: CPR Buồng lái Trạng thái Chuẩn (110 BPM, CCF đạt, 30fps)', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const normalState = CprSessionState(
        totalCompressions: 124,
        currentCompressionInCycle: 124,
        elapsedSeconds: 195,
        activeCompressionSeconds: 159,
        estimatedDepthCm: 5.4,
        elbowAngleDeg: 176.0,
        postureQuality: PostureQuality.optimal,
        temperatureC: 37.5,
        currentFps: 30,
        thermalState: ThermalState.nominal,
        isCameraPreviewActive: true,
        lastJitterMs: 1.4,
      );

      await tester.pumpWidget(createTestWidget(const CPRCoachScreen(
        initialState: normalState,
      )));
      await tester.pump(const Duration(milliseconds: 200));

      await expectLater(
        find.byType(CPRCoachScreen),
        matchesGoldenFile('goldens/f2_cpr_normal_state.png'),
      );
    });

    testWidgets('2. Chụp ảnh: CPR Cảnh báo Tư thế Sai (Viền đỏ, Khóa khuỷu tay 140°)', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const warningState = CprSessionState(
        totalCompressions: 145,
        currentCompressionInCycle: 145,
        elapsedSeconds: 210,
        activeCompressionSeconds: 170,
        estimatedDepthCm: 4.8,
        elbowAngleDeg: 138.0,
        postureQuality: PostureQuality.elbowBent,
        temperatureC: 38.5,
        currentFps: 30,
        thermalState: ThermalState.nominal,
        isCameraPreviewActive: true,
        lastJitterMs: 1.8,
      );

      await tester.pumpWidget(createTestWidget(const CPRCoachScreen(
        initialState: warningState,
      )));
      await tester.pump(const Duration(milliseconds: 200));

      await expectLater(
        find.byType(CPRCoachScreen),
        matchesGoldenFile('goldens/f2_cpr_posture_warning_state.png'),
      );
    });

    testWidgets('3. Chụp ảnh: CPR Quá nhiệt Ngắt Camera (≥45°C, Chế độ Tiết kiệm AMOLED)', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const criticalState = CprSessionState(
        totalCompressions: 210,
        currentCompressionInCycle: 210,
        elapsedSeconds: 280,
        activeCompressionSeconds: 230,
        estimatedDepthCm: 5.2,
        elbowAngleDeg: 170.0,
        postureQuality: PostureQuality.optimal,
        temperatureC: 45.8,
        currentFps: 0,
        thermalState: ThermalState.critical,
        isCameraPreviewActive: false,
        lastJitterMs: 2.1,
      );

      await tester.pumpWidget(createTestWidget(const CPRCoachScreen(
        initialState: criticalState,
      )));
      await tester.pump(const Duration(milliseconds: 200));

      await expectLater(
        find.byType(CPRCoachScreen),
        matchesGoldenFile('goldens/f2_cpr_thermal_critical_state.png'),
      );
    });

    testWidgets('4. Chụp ảnh: Bàn giao Kíp 115 (Bảng Báo cáo Telemetry Hồi sức)', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget(const CPRHandoverScreen(
        totalCompressions: 342,
        elapsedSeconds: 195,
        ccfPercentage: 81.5,
        pauseCount: 2,
      )));
      await tester.pump(const Duration(milliseconds: 200));

      await expectLater(
        find.byType(CPRHandoverScreen),
        matchesGoldenFile('goldens/f2_cpr_handover_report.png'),
      );
    });
  });
}
