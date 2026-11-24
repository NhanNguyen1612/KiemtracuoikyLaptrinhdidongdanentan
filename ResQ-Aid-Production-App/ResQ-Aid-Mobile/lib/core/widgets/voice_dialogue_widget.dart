import 'package:flutter/material.dart';
import '../services/voice_dialogue_service.dart';
import '../services/tts_service.dart';

/// Widget đối thoại 2 chiều thông minh bằng giọng nói (Hands-Free Voice Dialogue)
/// Cho phép sơ cứu viên giao tiếp hoàn toàn bằng giọng nói rảnh tay khi hai tay đang bận
/// (Ví dụ: Đang ép tim CPR 110 BPM, đang giữ camera quét vết thương, hoặc chỉnh tư thế).
class VoiceDialogueWidget extends StatefulWidget {
  final String contextHint;
  final List<String> suggestedPrompts;
  final bool compactMode;
  final String? initialAiMessage;

  const VoiceDialogueWidget({
    super.key,
    required this.contextHint,
    this.initialAiMessage,
    this.suggestedPrompts = const [
      'Nạn nhân tỉnh rồi làm gì?',
      'Mỏi tay quá xử lý sao?',
      'Tư thế tay đã đúng chưa?',
      'Độ sâu ép tim bao nhiêu?',
      'Có được chườm đá lạnh không?',
      'Bọng nước có được chọc vỡ không?',
    ],
    this.compactMode = false,
  });

  @override
  State<VoiceDialogueWidget> createState() => _VoiceDialogueWidgetState();
}

class _VoiceDialogueWidgetState extends State<VoiceDialogueWidget>
    with SingleTickerProviderStateMixin {
  final VoiceDialogueService _service = VoiceDialogueService();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _service.addListener(_onServiceUpdate);
    _service.initialize();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.initialAiMessage != null) {
        _service.resetWithInitialAiMessage(widget.initialAiMessage!);
      }
    });
  }

  @override
  void didUpdateWidget(covariant VoiceDialogueWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialAiMessage != null && widget.initialAiMessage != oldWidget.initialAiMessage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _service.resetWithInitialAiMessage(widget.initialAiMessage!);
        }
      });
    }
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceUpdate);
    _pulseController.dispose();
    super.dispose();
  }

  void _toggleListening() {
    if (_service.isListening) {
      _service.stopListening();
    } else {
      _service.startListening(contextHint: widget.contextHint);
    }
  }

  void _triggerPrompt(String prompt) {
    _service.simulateSpokenInput(prompt, contextHint: widget.contextHint);
  }

  @override
  Widget build(BuildContext context) {
    final isListening = _service.isListening;
    final isSpeaking = _service.isAiSpeaking;
    final history = _service.conversationHistory;

    return Container(
      padding: EdgeInsets.all(widget.compactMode ? 10 : 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isListening
              ? const Color(0xFF38BDF8)
              : (isSpeaking ? const Color(0xFF22C55E) : const Color(0xFF334155)),
          width: isListening || isSpeaking ? 2 : 1,
        ),
        boxShadow: [
          if (isListening)
            BoxShadow(
              color: const Color(0xFF38BDF8).withOpacity(0.3),
              blurRadius: 16,
              spreadRadius: 2,
            ),
          if (isSpeaking)
            BoxShadow(
              color: const Color(0xFF22C55E).withOpacity(0.25),
              blurRadius: 16,
              spreadRadius: 2,
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header: Status Indicator & Mic Mode
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isListening
                      ? const Color(0xFF38BDF8)
                      : (isSpeaking ? const Color(0xFF22C55E) : const Color(0xFF94A3B8)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isListening
                      ? 'AI ĐANG LẮNG NGHE GIỌNG NÓI...'
                      : (isSpeaking ? 'AI ĐANG TRẢ LỜI BẰNG ÂM THANH...' : 'ĐỐI THOẠI 2 CHIỀU RẢNH TAY (VOICE AI)'),
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    color: isListening
                        ? const Color(0xFF38BDF8)
                        : (isSpeaking ? const Color(0xFF4ADE80) : Colors.white),
                    fontWeight: FontWeight.w800,
                    fontSize: widget.compactMode ? 11 : 12,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              if (_service.conversationHistory.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    if (widget.initialAiMessage != null) {
                      _service.resetWithInitialAiMessage(widget.initialAiMessage!);
                    } else {
                      _service.clearHistory();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Xóa lịch sử',
                      style: TextStyle(color: Colors.white54, fontSize: 10),
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),

          // Central Mic Action Bar with Animated Pulsing Orb
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: _toggleListening,
                  child: AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      final scale = (isListening || isSpeaking) ? _pulseAnimation.value : 1.0;
                      return Transform.scale(
                        scale: scale,
                        child: Container(
                          width: widget.compactMode ? 54 : 64,
                          height: widget.compactMode ? 54 : 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: isListening
                                  ? [const Color(0xFF0284C7), const Color(0xFF38BDF8)]
                                  : (isSpeaking
                                      ? [const Color(0xFF15803D), const Color(0xFF22C55E)]
                                      : [const Color(0xFF334155), const Color(0xFF475569)]),
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (isListening
                                        ? const Color(0xFF38BDF8)
                                        : (isSpeaking ? const Color(0xFF22C55E) : Colors.black))
                                    .withOpacity(0.5),
                                blurRadius: 12,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Icon(
                            isListening
                                ? Icons.mic_rounded
                                : (isSpeaking ? Icons.volume_up_rounded : Icons.mic_none_rounded),
                            color: Colors.white,
                            size: widget.compactMode ? 28 : 32,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isListening
                            ? 'Hãy nói câu hỏi của bạn...'
                            : (isSpeaking ? 'Đang phát âm thanh hướng dẫn' : 'Chạm để nói rảnh tay (Không cần gõ)'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isListening
                            ? 'Hệ thống đang thu âm tiếng Việt chuẩn...'
                            : 'Hỗ trợ: Ép tim, mỏi tay, nạn nhân tỉnh, quét vết thương...',
                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Conversation Stream Area
          if (history.isNotEmpty || _service.currentTranscript.isNotEmpty || widget.initialAiMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              constraints: BoxConstraints(maxHeight: widget.compactMode ? 140 : 190),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: ListView(
                shrinkWrap: true,
                reverse: true, // Cuộn đến tin nhắn mới nhất
                children: [
                  // Lời nói đang nhận dạng dở dang
                  if (_service.currentTranscript.isNotEmpty && isListening)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.record_voice_over_rounded, color: Color(0xFF38BDF8), size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Đang nghe: "${_service.currentTranscript}"',
                              style: const TextStyle(
                                color: Color(0xFF38BDF8),
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Lịch sử đối thoại
                  ...history.reversed.map((turn) {
                    if (turn.isUser) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0284C7).withOpacity(0.3),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(Icons.person_rounded, color: Color(0xFF38BDF8), size: 14),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Bạn: ${turn.text}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    } else {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF22C55E).withOpacity(0.4)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF22C55E).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(Icons.medical_services_rounded, color: Color(0xFF4ADE80), size: 14),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Bác sĩ AI ResQ-Aid:',
                                      style: TextStyle(
                                        color: Color(0xFF4ADE80),
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      turn.text,
                                      style: const TextStyle(
                                        color: Color(0xFFE2E8F0),
                                        fontSize: 11.5,
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.volume_up_rounded, color: Color(0xFF38BDF8), size: 18),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => TtsService.speak(turn.text),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                  }),

                  // Thông điệp ban đầu theo từng ca chấn thương nếu chưa có câu hỏi nào
                  if (history.isEmpty && widget.initialAiMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF22C55E).withOpacity(0.4)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF22C55E).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(Icons.medical_services_rounded, color: Color(0xFF4ADE80), size: 14),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Text(
                                        'Bác sĩ AI ResQ-Aid:',
                                        style: TextStyle(
                                          color: Color(0xFF4ADE80),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const Spacer(),
                                      IconButton(
                                        icon: const Icon(Icons.volume_up_rounded, color: Color(0xFF4ADE80), size: 16),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () => TtsService.speak(widget.initialAiMessage!),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.initialAiMessage!,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11.5,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 10),

          // Suggested Voice Chips (Khẩu lệnh giọng nói mẫu cho sơ cứu viên)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.bolt_rounded, color: Color(0xFFFBBF24), size: 14),
                  SizedBox(width: 4),
                  Text(
                    'CÂU HỎI MẪU (NÓI TO HOẶC CHẠM NHANH):',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: widget.suggestedPrompts.map((prompt) {
                  return InkWell(
                    onTap: () => _triggerPrompt(prompt),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.35)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.chat_bubble_outline_rounded, size: 11, color: Color(0xFF38BDF8)),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              prompt,
                              style: const TextStyle(
                                color: Color(0xFFE2E8F0),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
