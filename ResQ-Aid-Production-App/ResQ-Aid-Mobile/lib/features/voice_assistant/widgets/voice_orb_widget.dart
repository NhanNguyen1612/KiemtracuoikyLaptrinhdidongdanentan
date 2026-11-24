import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Quả cầu sóng âm chuyển động phát sáng (Voice Orb)
/// Lấy cảm hứng từ giao diện Voice Mode của ChatGPT và Gemini Live
class VoiceOrbWidget extends StatefulWidget {
  final bool isListening;
  final bool isAiSpeaking;
  final double size;
  final VoidCallback? onTap;
  final bool isPillShape;

  const VoiceOrbWidget({
    super.key,
    required this.isListening,
    required this.isAiSpeaking,
    this.size = 120.0,
    this.onTap,
    this.isPillShape = false,
  });

  @override
  State<VoiceOrbWidget> createState() => _VoiceOrbWidgetState();
}

class _VoiceOrbWidgetState extends State<VoiceOrbWidget>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulseController, _waveController]),
        builder: (context, child) {
          final pulseVal = _pulseController.value;
          final waveVal = _waveController.value;

          // Màu sắc chuyển động theo trạng thái
          final List<Color> colors;
          final double scale;

          if (widget.isAiSpeaking) {
            // Khi AI đang nói: Sóng ngọc bích & xanh lam rực rỡ
            colors = [
              const Color(0xFF10B981).withOpacity(0.9),
              const Color(0xFF06B6D4).withOpacity(0.85),
              const Color(0xFF3B82F6).withOpacity(0.7),
              Colors.white.withOpacity(0.95),
            ];
            scale = 1.0 + (pulseVal * 0.18);
          } else if (widget.isListening) {
            // Khi đang nghe người dùng: Sóng xanh điện Cyan chuyển động nhanh
            colors = [
              const Color(0xFF38BDF8).withOpacity(0.95),
              const Color(0xFF0284C7).withOpacity(0.85),
              const Color(0xFF6366F1).withOpacity(0.75),
              Colors.white,
            ];
            scale = 1.0 + (pulseVal * 0.12);
          } else {
            // Trạng thái nghỉ/chờ: Vầng sáng êm dịu, mờ ảo
            colors = [
              const Color(0xFF0284C7).withOpacity(0.55),
              const Color(0xFF1E293B).withOpacity(0.8),
              const Color(0xFF38BDF8).withOpacity(0.4),
              Colors.white70,
            ];
            scale = 1.0 + (pulseVal * 0.05);
          }

          final width = widget.isPillShape ? widget.size * 1.8 : widget.size;
          final height = widget.size;

          return SizedBox(
            width: width * 1.3,
            height: height * 1.3,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Vầng hào quang tỏa sáng bên ngoài (Outer Bloom Halo)
                Transform.scale(
                  scale: scale * 1.15,
                  child: Container(
                    width: width,
                    height: height,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(widget.isPillShape ? height / 2 : height / 2),
                      boxShadow: [
                        BoxShadow(
                          color: colors[0].withOpacity(widget.isListening || widget.isAiSpeaking ? 0.45 : 0.2),
                          blurRadius: widget.isAiSpeaking ? 38 : (widget.isListening ? 30 : 16),
                          spreadRadius: widget.isAiSpeaking ? 8 : (widget.isListening ? 4 : 1),
                        ),
                      ],
                    ),
                  ),
                ),

                // Lớp chất lỏng phát sáng chính giữa (Core Fluid Gradient)
                Transform.scale(
                  scale: scale,
                  child: Container(
                    width: width,
                    height: height,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(height / 2),
                      gradient: LinearGradient(
                        colors: colors,
                        begin: Alignment(
                          math.cos(waveVal * 2 * math.pi),
                          math.sin(waveVal * 2 * math.pi),
                        ),
                        end: Alignment(
                          -math.cos(waveVal * 2 * math.pi),
                          -math.sin(waveVal * 2 * math.pi),
                        ),
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Điểm sáng trắng trung tâm (White Core Reflection)
                        Container(
                          width: width * 0.55,
                          height: height * 0.45,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(height / 2),
                            gradient: RadialGradient(
                              colors: [
                                Colors.white.withOpacity(0.9),
                                Colors.white.withOpacity(0.0),
                              ],
                            ),
                          ),
                        ),

                        // Icon trạng thái nếu ở dạng nút tròn nhỏ (không áp dụng khi dạng viên thuốc Pill)
                        if (!widget.isPillShape && widget.size <= 70)
                          Icon(
                            widget.isAiSpeaking
                                ? Icons.graphic_eq_rounded
                                : (widget.isListening
                                    ? Icons.mic_rounded
                                    : Icons.headset_mic_rounded),
                            color: Colors.white,
                            size: widget.size * 0.42,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
