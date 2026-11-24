import 'package:flutter/material.dart';
import '../../../main.dart';
import '../../../core/services/voice_bubble_controller.dart';
import '../widgets/voice_orb_widget.dart';
import 'voice_live_screen.dart';

/// Bong bóng giọng nói nổi (Floating PiP Bubble) ghim trên màn hình khi thu nhỏ
/// Lấy cảm hứng từ chế độ PiP của Gemini Live / ChatGPT Voice khi thoát ra ngoài
class GlobalFloatingVoiceBubble extends StatefulWidget {
  const GlobalFloatingVoiceBubble({super.key});

  @override
  State<GlobalFloatingVoiceBubble> createState() => _GlobalFloatingVoiceBubbleState();
}

class _GlobalFloatingVoiceBubbleState extends State<GlobalFloatingVoiceBubble> {
  final VoiceBubbleController _controller = VoiceBubbleController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChanged);
    _controller.dialogueService.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dialogueService.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  void _expandToFullscreen() {
    _controller.expandToFullscreen();
    final nav = rootNavigatorKey.currentState ?? Navigator.maybeOf(context);
    if (nav != null) {
      nav.push(
        PageRouteBuilder(
          opaque: false,
          pageBuilder: (_, __, ___) => const VoiceLiveScreen(),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.isLiveActive || !_controller.isMinimized) {
      return const SizedBox.shrink();
    }

    final screenSize = MediaQuery.of(context).size;
    final isListening = _controller.dialogueService.isListening;
    final isAiSpeaking = _controller.dialogueService.isAiSpeaking;
    final lastAiResponse = _controller.dialogueService.lastAiResponse;

    // Giới hạn bong bóng trong màn hình
    final pos = _controller.bubblePosition;
    final clampedX = pos.dx.clamp(12.0, screenSize.width - 80.0);
    final clampedY = pos.dy.clamp(60.0, screenSize.height - 140.0);

    return Positioned(
      left: clampedX,
      top: clampedY,
      child: Material(
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: clampedX > screenSize.width / 2
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            // Lời thoại nổi ngắn khi AI đang nói
            if (isAiSpeaking && lastAiResponse.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                constraints: BoxConstraints(maxWidth: screenSize.width * 0.65),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A).withOpacity(0.92),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.4)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Text(
                  lastAiResponse,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

            // Quả cầu nổi có thể kéo thả (Draggable Orb)
            GestureDetector(
              onPanUpdate: (details) {
                _controller.updatePosition(
                  Offset(clampedX + details.delta.dx, clampedY + details.delta.dy),
                );
              },
              onTap: _expandToFullscreen,
              child: Stack(
                alignment: Alignment.topRight,
                children: [
                  VoiceOrbWidget(
                    size: 64,
                    isListening: isListening,
                    isAiSpeaking: isAiSpeaking,
                  ),
                  // Nút tắt phiên nhanh
                  GestureDetector(
                    onTap: () => _controller.closeLiveSession(),
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Color(0xFFDC2626),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
