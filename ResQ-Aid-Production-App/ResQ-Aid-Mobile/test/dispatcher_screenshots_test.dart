import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resq_aid/features/dispatcher/presentation/dispatcher_console_screen.dart';

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
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadTestFonts();
  });

  group('FEATURE 4: CHỤP ẢNH MINH CHỨNG WEB DISPATCHER CONSOLE', () {
    testWidgets('1. Chụp ảnh: Web Dispatcher Console 115 (1600x960 Desktop/Web Resolution)', (tester) async {
      tester.view.physicalSize = const Size(1600, 960);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          debugShowCheckedModeBanner: false,
          home: DispatcherConsoleScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(DispatcherConsoleScreen),
        matchesGoldenFile('goldens/f4_web_dispatcher_console.png'),
      );
    });
  });
}
