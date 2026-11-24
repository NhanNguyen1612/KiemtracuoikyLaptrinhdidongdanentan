import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resq_aid/core/services/voice_bubble_controller.dart';
import 'package:resq_aid/features/voice_assistant/presentation/voice_live_screen.dart';
import 'package:resq_aid/features/voice_assistant/presentation/floating_voice_bubble.dart';
import 'package:resq_aid/features/voice_assistant/widgets/voice_orb_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FEATURE: GEMINI LIVE / CHATGPT VOICE MODE & FLOATING BUBBLE (PiP)', () {
    late VoiceBubbleController controller;

    setUp(() {
      controller = VoiceBubbleController();
    });

    tearDown(() async {
      await controller.closeLiveSession();
    });

    test('1. VoiceBubbleController: Quản lý vòng đời phiên Live và trạng thái thu nhỏ PiP', () async {
      expect(controller.isLiveActive, false);
      expect(controller.isMinimized, false);

      // Bắt đầu phiên Live
      await controller.startLiveSession(contextHint: 'CPR_TEST');
      expect(controller.isLiveActive, true);
      expect(controller.isMinimized, false);
      expect(controller.currentContext, 'CPR_TEST');

      // Thu nhỏ thành bong bóng nổi
      controller.minimizeToBubble(newContext: 'CPR_COCKPIT');
      expect(controller.isMinimized, true);
      expect(controller.currentContext, 'CPR_COCKPIT');

      // Kéo thả vị trí
      controller.updatePosition(const Offset(150, 400));
      expect(controller.bubblePosition, const Offset(150, 400));

      // Phóng to trở lại toàn màn hình
      controller.expandToFullscreen();
      expect(controller.isMinimized, false);

      // Đóng phiên
      await controller.closeLiveSession();
      expect(controller.isLiveActive, false);
      expect(controller.isMinimized, false);
    });

    testWidgets('2. VoiceOrbWidget: Render mượt mà ở cả chế độ tròn và viên thuốc (Pill)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: VoiceOrbWidget(
                size: 80,
                isPillShape: true,
                isListening: true,
                isAiSpeaking: false,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(VoiceOrbWidget), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 300));
    });

    testWidgets('3. GlobalFloatingVoiceBubble: Render bong bóng nổi khi isMinimized = true', (tester) async {
      await controller.startLiveSession(startMinimized: true, contextHint: 'WOUND_TEST');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: const [
                Text('Background Screen'),
                GlobalFloatingVoiceBubble(),
              ],
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(GlobalFloatingVoiceBubble), findsOneWidget);
      expect(find.byType(VoiceOrbWidget), findsOneWidget);
    });

    testWidgets('4. VoiceLiveScreen: Render giao diện toàn cảnh chuẩn phong cách ChatGPT/Gemini Live', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: VoiceLiveScreen(initialContext: 'GENERAL'),
        ),
      );

      await tester.pump(const Duration(milliseconds: 200));

      expect(find.textContaining('MICRO'), findsOneWidget);
      expect(find.text('Chào bạn, tôi có thể giúp gì cho bạn ngay lúc này?'), findsOneWidget);
      expect(find.byType(VoiceOrbWidget), findsOneWidget);
      expect(find.byIcon(Icons.camera_alt_outlined), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
    });

    testWidgets('5. _showPromptInputSheet: Không bao giờ bị overflow khi bàn phím ảo xuất hiện', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: VoiceLiveScreen(initialContext: 'GENERAL'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      // Mở sheet bằng cách bấm vào nút icon arrow_upward
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Tình huống cấp cứu & Câu hỏi'), findsOneWidget);
      expect(find.text('Tôi bị thần kinh'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      // Giả lập bàn phím ảo đẩy lên 350px
      tester.view.viewInsets = const FakeViewPadding(bottom: 350);
      await tester.pump(const Duration(milliseconds: 300));

      // Kiểm tra không có exception hoặc overflow nào
      expect(tester.takeException(), isNull);

      // Đóng sheet
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump(const Duration(milliseconds: 300));
      tester.view.resetViewInsets();
    });
  });
}
