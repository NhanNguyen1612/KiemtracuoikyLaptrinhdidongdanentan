import 'dart:convert';
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
import 'package:resq_aid/features/cpr/presentation/cpr_coach_screen.dart';
import 'package:resq_aid/features/handbook/presentation/handbook_list_screen.dart';
import 'package:resq_aid/features/handbook/presentation/protocol_detail_screen.dart';
import 'package:resq_aid/features/consent/presentation/consent_screen.dart';
import 'package:resq_aid/features/cpr/presentation/cpr_handover_screen.dart';
import 'package:resq_aid/features/settings/presentation/settings_screen.dart';

Future<void> _loadTestFonts() async {
  // Load Text Font
  final fontFile = File(r'C:\Windows\Fonts\segoeui.ttf');
  if (await fontFile.exists()) {
    final bytes = await fontFile.readAsBytes();
    for (final name in ['Roboto', 'Segoe UI', '.SF Pro Text', '.SF UI Text']) {
      final fontLoader = FontLoader(name);
      fontLoader.addFont(Future.value(ByteData.view(bytes.buffer)));
      await fontLoader.load();
    }
  }

  // Load Material Icons Font
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

  Widget createTestWidget(Widget child, {ThemeData? theme}) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(testDb),
      ],
      child: MaterialApp(
        theme: theme ?? AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        home: child,
      ),
    );
  }

  testWidgets('Chụp ảnh màn hình: Trang chủ (HomeScreen)', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createTestWidget(const HomeScreen()));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(HomeScreen),
      matchesGoldenFile('goldens/01_home_screen.png'),
    );
  });

  testWidgets('Chụp ảnh màn hình: SOS Khẩn cấp (EmergencySosScreen)', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createTestWidget(const EmergencySosScreen()));
    await tester.pump(const Duration(milliseconds: 400));

    await expectLater(
      find.byType(EmergencySosScreen),
      matchesGoldenFile('goldens/02_emergency_sos_screen.png'),
    );
  });

  testWidgets('Chụp ảnh màn hình: Trợ lý Ép tim CPR 110 BPM (CPRCoachScreen)', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createTestWidget(const CPRCoachScreen(), theme: AppTheme.darkTheme));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(CPRCoachScreen), findsOneWidget);
    expect(find.textContaining('110 BPM'), findsOneWidget);
  });

  testWidgets('Chụp ảnh màn hình: Bàn giao Kíp cấp cứu 115 (CPRHandoverScreen)', (WidgetTester tester) async {
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
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(CPRHandoverScreen),
      matchesGoldenFile('goldens/04_cpr_handover_screen.png'),
    );
  });

  testWidgets('Chụp ảnh màn hình: Cẩm nang Sơ cứu Offline (HandbookListScreen)', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createTestWidget(const HandbookListScreen()));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(HandbookListScreen),
      matchesGoldenFile('goldens/05_handbook_list_screen.png'),
    );
  });

  testWidgets('Chụp ảnh màn hình: Chi tiết Phác đồ Đuối nước (ProtocolDetailScreen)', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final protocol = ProtocolEntry(
      protocolCode: 'PROTO_DROWNING',
      title: 'Sơ cứu Nạn nhân Đuối nước',
      version: 2,
      contentJson: jsonEncode({
        'target': 'Mọi lứa tuổi',
        'quick_summary': 'Đưa nạn nhân lên bờ, thông khí khẩn cấp bằng 5 nhịp thổi ngạt trước khi ép tim.',
        'steps': [
          {
            'step': 1,
            'title': 'Đưa lên bờ an toàn',
            'instruction': 'Đảm bảo an toàn cho người cứu hộ. Dùng phao, sào dài. Đưa nạn nhân lên bờ khô ráo, thoáng mát.',
            'warning': 'Không nhảy xuống nước nếu bạn không biết bơi cứu hộ.'
          },
          {
            'step': 2,
            'title': 'Kiểm tra đường thở & làm sạch miệng',
            'instruction': 'Lay vai gọi to, ngửa đầu nâng cằm kiểm tra miệng có bùn đất, rong rêu thì lấy sạch.',
            'warning': 'Tuyệt đối KHÔNG xốc nước kiểu vác nạn nhân chạy quanh (làm trào ngược dịch vào phổi).'
          },
          {
            'step': 3,
            'title': '5 nhịp thổi ngạt đầu tiên',
            'instruction': 'Nếu nạn nhân không thở -> bịt mũi, hít sâu và thổi ngạt 5 lần liên tiếp để nở phổi và cung cấp oxy.',
            'warning': 'Mỗi nhịp thổi khoảng 1 giây, quan sát lồng ngực có phập phồng không.'
          },
          {
            'step': 4,
            'title': 'Ép tim kết hợp thổi ngạt (30:2)',
            'instruction': 'Sau 5 nhịp thổi, nếu vẫn chưa thở -> ép tim 30 nhịp (100-110 BPM) kết hợp 2 nhịp thổi ngạt.',
            'warning': 'Duy trì liên tục đến khi y tế 115 tiếp cận hoặc nạn nhân tự thở lại.'
          }
        ],
        'contraindications': [
          'Không cố xốc nước khỏi bụng hoặc phổi.',
          'Không ngừng ép tim quá 10 giây.'
        ]
      }),
      status: 'PUBLISHED',
      updatedAt: DateTime.now(),
    );

    await tester.pumpWidget(createTestWidget(ProtocolDetailScreen(protocol: protocol)));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(ProtocolDetailScreen),
      matchesGoldenFile('goldens/06_protocol_detail_screen.png'),
    );
  });

  testWidgets('Chụp ảnh màn hình: Minh bạch Dữ liệu (ConsentScreen)', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createTestWidget(const ConsentScreen()));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(ConsentScreen),
      matchesGoldenFile('goldens/07_consent_screen.png'),
    );
  });

  testWidgets('Chụp ảnh màn hình: Cài đặt & Quản lý Dữ liệu (SettingsScreen)', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createTestWidget(const SettingsScreen()));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(SettingsScreen),
      matchesGoldenFile('goldens/08_settings_screen.png'),
    );
  });
}
