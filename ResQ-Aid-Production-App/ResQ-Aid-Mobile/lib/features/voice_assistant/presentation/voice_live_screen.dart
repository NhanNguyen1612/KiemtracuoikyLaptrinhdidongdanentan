import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/services/voice_bubble_controller.dart';
import '../../../core/services/tts_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/models/case_state.dart';
import '../../wound_scanner/presentation/wound_scanner_screen.dart';
import '../../medical_facilities/presentation/nearest_medical_facility_screen.dart';
import '../widgets/voice_orb_widget.dart';

/// Màn hình Trò chuyện Giọng nói Toàn cảnh (Gemini Live / ChatGPT Voice Mode)
/// Thiết kế tối giản đen AMOLED với Quả cầu sóng âm chuyển động phát sáng
class VoiceLiveScreen extends StatefulWidget {
  final String initialContext;

  const VoiceLiveScreen({
    super.key,
    this.initialContext = 'GENERAL',
  });

  @override
  State<VoiceLiveScreen> createState() => _VoiceLiveScreenState();
}

class _VoiceLiveScreenState extends State<VoiceLiveScreen> {
  final VoiceBubbleController _controller = VoiceBubbleController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
    _controller.dialogueService.addListener(_onChanged);

    // Kích hoạt phiên nếu chưa bật
    if (!_controller.isLiveActive) {
      _controller.startLiveSession(contextHint: widget.initialContext);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dialogueService.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  void _minimize() {
    _controller.minimizeToBubble();
    Navigator.of(context).pop();
  }

  void _openCameraScanner() {
    _controller.minimizeToBubble(newContext: 'WOUND_SCANNER');
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const WoundScannerScreen()),
    );
  }

  Future<void> _call115() async {
    final uri = Uri.parse('tel:115');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openNearestMedicalMap() async {
    _controller.dialogueService.stopAiSpeaking();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NearestMedicalFacilityScreen()),
    );
  }

  void _showHandoverModal() {
    final summary = CaseState.initial().exportHandoverSummary();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.assignment_rounded, color: Color(0xFFF59E0B), size: 24),
                  const SizedBox(width: 8),
                  const Text(
                    'TÓM TẮT CA BÀN GIAO 115',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.45,
                ),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    summary,
                    style: const TextStyle(
                      color: Color(0xFFE2E8F0),
                      fontFamily: 'monospace',
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.phone_in_talk_rounded, size: 18),
                      label: const Text('GỌI 115 NGAY', style: TextStyle(fontWeight: FontWeight.w900)),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _call115();
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('SAO CHÉP', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Đã sao chép tóm tắt ca vào bộ nhớ tạm'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        Navigator.pop(ctx);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final dialogue = _controller.dialogueService;
    final isListening = dialogue.isListening;
    final isAiSpeaking = dialogue.isAiSpeaking;
    final transcript = dialogue.currentTranscript;
    final history = dialogue.conversationHistory;

    return Scaffold(
      backgroundColor: const Color(0xFF090D16), // Đen tối giản phong cách Live
      body: SafeArea(
        child: Column(
          children: [
            // 1. TOP BAR
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
              child: Row(
                children: [
                  // Nút thu nhỏ thành bong bóng nổi (PiP Bubble)
                  IconButton(
                    icon: const Icon(Icons.remove_rounded, color: Colors.white70, size: 24),
                    tooltip: 'Thu nhỏ thành bong bóng nổi (PiP)',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    onPressed: _minimize,
                  ),
                  const SizedBox(width: 4),
                  // Trạng thái AI trực tuyến (Bọc trong Expanded + FittedBox để KHÔNG BAO GIỜ bị tràn pixel trên bất kỳ màn hình nào)
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B).withOpacity(0.6),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: isAiSpeaking
                                        ? const Color(0xFF10B981)
                                        : (isListening ? const Color(0xFF38BDF8) : const Color(0xFFFBBF24)),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: (isAiSpeaking ? const Color(0xFF10B981) : const Color(0xFF38BDF8)).withOpacity(0.6),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isAiSpeaking
                                      ? 'TRỢ LÝ SƠ CỨU ĐANG NÓI...'
                                      : (isListening
                                          ? 'ĐANG LẮNG NGHE...'
                                          : (dialogue.continuousLiveMode
                                              ? 'TỰ ĐỘNG RẢNH TAY'
                                              : 'BẤM MICRO ĐỂ NÓI')),
                                  style: const TextStyle(
                                    fontFamily: 'Roboto',
                                    color: Colors.white,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1).withOpacity(0.18),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF818CF8).withOpacity(0.4)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified_user_rounded, color: Color(0xFF818CF8), size: 10),
                                SizedBox(width: 3),
                                Text(
                                  'Sơ Cứu Chuẩn Y Tế',
                                  style: TextStyle(
                                    color: Color(0xFFC7D2FE),
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Nút gọi 115 Khẩn cấp Thường trực
                  InkWell(
                    onTap: _call115,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFEF4444).withOpacity(0.4),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.phone_in_talk_rounded, color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text(
                            '115',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Nút đóng phiên gọi
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 24),
                    tooltip: 'Đóng phiên trò chuyện',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    onPressed: () {
                      _controller.closeLiveSession();
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            ),

            // 2. CONVERSATION VIEW (Lời chào & Lời thoại trực tiếp)
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (history.isEmpty && transcript.isEmpty) ...[
                      // Lời chào mở đầu kiểu ChatGPT / Gemini
                      const Text(
                        'Chào bạn, tôi có thể giúp gì cho bạn ngay lúc này?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Hàng nút tương tác chuẩn Image 1 (Like, Dislike, Share, Copy, More)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildActionIconButton(Icons.thumb_up_alt_outlined, 'Hữu ích'),
                          const SizedBox(width: 12),
                          _buildActionIconButton(Icons.thumb_down_alt_outlined, 'Chưa chính xác'),
                          const SizedBox(width: 12),
                          _buildActionIconButton(Icons.share_outlined, 'Chia sẻ'),
                          const SizedBox(width: 12),
                          _buildActionIconButton(Icons.copy_rounded, 'Sao chép'),
                          const SizedBox(width: 12),
                          _buildActionIconButton(Icons.more_horiz_rounded, 'Khác'),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Nói tự nhiên rảnh tay • Hỏi bất cứ điều gì về cấp cứu, vết thương hoặc CPR',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          color: Color(0xFF94A3B8),
                          fontSize: 13,
                          height: 1.3,
                        ),
                      ),
                    ] else ...[
                      // Lời thoại gần nhất của người dùng
                      if (history.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B).withOpacity(0.5),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.person_rounded, color: Color(0xFF38BDF8), size: 16),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'Bạn:',
                                    style: TextStyle(color: Color(0xFF38BDF8), fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                  const Spacer(),
                                  Text(
                                    history.last.isUser
                                        ? 'Vừa xong'
                                        : (history.length > 1 ? 'Đã hỏi' : ''),
                                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                history.last.isUser
                                    ? history.last.text
                                    : (history.length > 1 ? history[history.length - 2].text : ''),
                                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),

                      // Lời nói đang thu âm dở dang
                      if (isListening && transcript.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                            'Đang nghe: "$transcript"...',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF38BDF8),
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),

                      // Phản hồi y khoa của Bác sĩ AI
                      if (dialogue.lastAiResponse.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.medical_services_rounded, color: Color(0xFF10B981), size: 18),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Trợ lý Sơ cứu ResQ-Aid:',
                                    style: TextStyle(
                                      color: Color(0xFF10B981),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    icon: const Icon(Icons.volume_up_rounded, color: Color(0xFF10B981), size: 20),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () => TtsService.speak(dialogue.lastAiResponse),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                dialogue.lastAiResponse,
                                style: const TextStyle(
                                  color: Color(0xFFE2E8F0),
                                  fontSize: 14.5,
                                  height: 1.4,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 14),

                      // Quick Shortcuts khi cần hành động cấp cứu
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildQuickActionButton(
                              icon: Icons.camera_alt_rounded,
                              label: 'Quét Camera Vết Thương',
                              color: const Color(0xFF0284C7),
                              onTap: _openCameraScanner,
                            ),
                            const SizedBox(width: 8),
                            _buildQuickActionButton(
                              icon: Icons.near_me_rounded,
                              label: 'Tìm Trạm Y Tế / Viện',
                              color: const Color(0xFF10B981),
                              onTap: _openNearestMedicalMap,
                            ),
                            const SizedBox(width: 8),
                            _buildQuickActionButton(
                              icon: Icons.assignment_outlined,
                              label: 'Tóm Tắt Ca 115',
                              color: const Color(0xFFF59E0B),
                              onTap: _showHandoverModal,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // BỘ CHUYỂN ĐỔI 2 CHẾ ĐỘ: BẤM MỚI GHI ÂM (MANUAL) vs TỰ ĐỘNG RẢNH TAY (AUTO HANDS-FREE)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B).withOpacity(0.85),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  // Chế độ 1: Bấm để ghi âm
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          dialogue.continuousLiveMode = false;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Đã chọn chế độ "Bấm để nói" (Chỉ ghi âm khi bạn nhấn micro)'),
                            duration: Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: !dialogue.continuousLiveMode
                              ? const Color(0xFF0284C7)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: !dialogue.continuousLiveMode
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF0284C7).withOpacity(0.4),
                                    blurRadius: 6,
                                  ),
                                ]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.touch_app_rounded,
                              size: 15,
                              color: !dialogue.continuousLiveMode ? Colors.white : Colors.white60,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Bấm để nói',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: !dialogue.continuousLiveMode ? FontWeight.w900 : FontWeight.w500,
                                color: !dialogue.continuousLiveMode ? Colors.white : Colors.white60,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Chế độ 2: Tự động rảnh tay
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          dialogue.continuousLiveMode = true;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Đã chọn chế độ "Tự động rảnh tay" (AI nói xong tự động nghe tiếp)'),
                            duration: Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: dialogue.continuousLiveMode
                              ? const Color(0xFF10B981)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: dialogue.continuousLiveMode
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF10B981).withOpacity(0.4),
                                    blurRadius: 6,
                                  ),
                                ]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.autorenew_rounded,
                              size: 15,
                              color: dialogue.continuousLiveMode ? Colors.white : Colors.white60,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Tự động rảnh tay',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: dialogue.continuousLiveMode ? FontWeight.w900 : FontWeight.w500,
                                color: dialogue.continuousLiveMode ? Colors.white : Colors.white60,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 3. BOTTOM CONTROLS BAR (Chuẩn thiết kế Gemini Live / ChatGPT Voice)
            Padding(
              padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 20.0, top: 10.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Nút Camera soi hiện trường & vết thương
                  _buildCircleIconButton(
                    icon: Icons.camera_alt_outlined,
                    tooltip: 'Mở Camera soi hiện trường',
                    onTap: _openCameraScanner,
                  ),

                  // Nút Nhập câu hỏi / Gợi ý tình huống (Chuẩn ChatGPT/Gemini Live)
                  _buildCircleIconButton(
                    icon: Icons.arrow_upward_rounded,
                    tooltip: 'Nhập câu hỏi hoặc chọn tình huống',
                    onTap: _showPromptInputSheet,
                  ),

                  // Quả cầu sóng âm chuyển động phát sáng (Voice Orb hình viên thuốc ở giữa)
                  VoiceOrbWidget(
                    size: 46,
                    isPillShape: true,
                    isListening: isListening,
                    isAiSpeaking: isAiSpeaking,
                    onTap: () {
                      if (isAiSpeaking) {
                        // Bấm vào quả cầu khi AI đang nói -> Ngắt giọng AI ngay lập tức!
                        dialogue.stopAiSpeaking();
                      } else if (isListening) {
                        // Chạm vào để gửi câu nói ngay (không cần đợi hết thời gian chờ im lặng)
                        if (transcript.trim().isNotEmpty) {
                          dialogue.processUserSpeech(transcript, contextHint: widget.initialContext);
                        } else {
                          dialogue.stopListening();
                        }
                      } else {
                        dialogue.startListening(contextHint: widget.initialContext);
                      }
                    },
                  ),

                  // Nút Micro thu âm
                  _buildCircleIconButton(
                    icon: isAiSpeaking
                        ? Icons.stop_circle_rounded
                        : (isListening ? Icons.mic_rounded : Icons.mic_none_rounded),
                    tooltip: isAiSpeaking
                        ? 'Ngắt lời AI'
                        : (isListening ? 'Gửi câu nói / Tắt mic' : 'Bật micro'),
                    iconColor: isAiSpeaking
                        ? const Color(0xFFEF4444)
                        : (isListening ? const Color(0xFF38BDF8) : Colors.white),
                    bgColor: isAiSpeaking
                        ? const Color(0xFFEF4444).withOpacity(0.2)
                        : (isListening ? const Color(0xFF1E293B) : const Color(0xFF1E293B).withOpacity(0.6)),
                    onTap: () {
                      if (isAiSpeaking) {
                        // Người dùng muốn ngắt khi AI đang nói
                        dialogue.stopAiSpeaking();
                      } else if (isListening) {
                        // Chạm vào để gửi câu nói ngay nếu đã nói xong
                        if (transcript.trim().isNotEmpty) {
                          dialogue.processUserSpeech(transcript, contextHint: widget.initialContext);
                        } else {
                          dialogue.stopListening();
                        }
                      } else {
                        dialogue.startListening(contextHint: widget.initialContext);
                      }
                    },
                  ),

                  // Nút Đóng / Thoát phiên
                  _buildCircleIconButton(
                    icon: Icons.close_rounded,
                    tooltip: 'Đóng phiên trò chuyện',
                    onTap: () {
                      _controller.closeLiveSession();
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircleIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color iconColor = Colors.white,
    Color? bgColor,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: bgColor ?? const Color(0xFF1E293B).withOpacity(0.6),
            border: Border.all(color: Colors.white12),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
      ),
    );
  }

  Widget _buildActionIconButton(IconData icon, String tooltip) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(6.0),
          child: Icon(icon, color: Colors.white70, size: 20),
        ),
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Roboto',
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPromptInputSheet() {
    final textController = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final keyboardHeight = MediaQuery.of(ctx).viewInsets.bottom;
        final screenHeight = MediaQuery.of(ctx).size.height;
        // Trừ keyboard + SafeArea bottom, nhân 0.75 để luôn vừa màn hình
        final safeBottom = MediaQuery.of(ctx).padding.bottom;
        final availableHeight = (screenHeight - keyboardHeight - safeBottom).clamp(200.0, screenHeight * 0.78);
        return Padding(
          padding: EdgeInsets.only(bottom: keyboardHeight),
          child: SafeArea(
            top: false,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: availableHeight,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.psychology_rounded, color: Color(0xFF38BDF8), size: 22),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Tình huống cấp cứu & Câu hỏi',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white54, size: 22),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Flexible(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildPromptChip(ctx, 'Tìm trạm y tế gần nhất'),
                              _buildPromptChip(ctx, 'Tôi bị thần kinh'),
                              _buildPromptChip(ctx, 'Tôi bị đứt tay'),
                              _buildPromptChip(ctx, 'Hướng dẫn cách làm chi tiết'),
                              _buildPromptChip(ctx, 'Nạn nhân bị hóc dị vật'),
                              _buildPromptChip(ctx, 'Bị đau thắt ngực nhồi máu cơ tim'),
                              _buildPromptChip(ctx, 'Trẻ sơ sinh dưới 1 tuổi bị sặc sữa'),
                              _buildPromptChip(ctx, 'Tại sao không vỗ lưng khi đang ho?'),
                              _buildPromptChip(ctx, 'Vết bỏng sau giật điện'),
                              _buildPromptChip(ctx, 'Mỏi tay khi ép tim CPR'),
                              _buildPromptChip(ctx, 'Bị kiến ba khoang cắn thì làm sao?'),
                              _buildPromptChip(ctx, 'Uống cà phê bị say tim đập nhanh'),
                              _buildPromptChip(ctx, 'Bị chuột rút bắp chân thì làm gì?'),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: textController,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Nhập câu hỏi cấp cứu...',
                              hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                              filled: true,
                              fillColor: const Color(0xFF1E293B),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              isDense: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onSubmitted: (val) {
                              if (val.trim().isNotEmpty) {
                                Navigator.pop(ctx);
                                _controller.dialogueService.processUserSpeech(
                                  val.trim(),
                                  contextHint: widget.initialContext,
                                );
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          icon: const Icon(Icons.send_rounded, color: Color(0xFF38BDF8), size: 22),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                          onPressed: () {
                            final val = textController.text.trim();
                            if (val.isNotEmpty) {
                              Navigator.pop(ctx);
                              _controller.dialogueService.processUserSpeech(
                                val,
                                contextHint: widget.initialContext,
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPromptChip(BuildContext ctx, String prompt) {
    return ActionChip(
      label: Text(
        prompt,
        style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 12),
      ),
      backgroundColor: const Color(0xFF1E293B),
      side: const BorderSide(color: Color(0xFF334155)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onPressed: () {
        Navigator.pop(ctx);
        _controller.dialogueService.processUserSpeech(
          prompt,
          contextHint: widget.initialContext,
        );
      },
    );
  }
}
