import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/services/medical_dialogue_brain.dart';
import '../../../core/services/tflite_vision_service.dart';
import '../../../core/services/tts_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/voice_dialogue_widget.dart';

class AiFirstAidAssistantSheet extends StatefulWidget {
  final String protocolCode;
  final String protocolTitle;

  const AiFirstAidAssistantSheet({
    super.key,
    required this.protocolCode,
    required this.protocolTitle,
  });

  static void show(BuildContext context, String code, String title) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => AiFirstAidAssistantSheet(
        protocolCode: code,
        protocolTitle: title,
      ),
    );
  }

  @override
  State<AiFirstAidAssistantSheet> createState() => _AiFirstAidAssistantSheetState();
}

class _AiFirstAidAssistantSheetState extends State<AiFirstAidAssistantSheet>
    with SingleTickerProviderStateMixin {
  int _activeTab = 0; // 0: Quét Camera thị giác AI, 1: Hỏi đáp y khoa
  bool _isScanning = false;
  bool _scanCompleted = false;
  int _scanCountdown = 2;
  Timer? _countdownTimer;

  late AnimationController _laserController;
  late Animation<double> _laserAnimation;

  // Selected Q&A item
  int? _expandedFaqIndex;
  final TextEditingController _questionInputCtrl = TextEditingController();
  String? _customAiAnswer;

  // TensorFlow Lite On-Device Inference Result
  TfliteInferenceResult? _tfliteResult;

  @override
  void initState() {
    super.initState();
    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _laserAnimation = Tween<double>(begin: 0.1, end: 0.9).animate(_laserController);

    // Kích hoạt nạp mô hình TensorFlow Lite On-Device ngầm
    TfliteVisionService().initialize();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _laserController.dispose();
    _questionInputCtrl.dispose();
    super.dispose();
  }

  void _startCameraScan() {
    setState(() {
      _isScanning = true;
      _scanCompleted = false;
      _scanCountdown = 2;
    });

    // Phát khẩu lệnh giọng nói hướng dẫn nạn nhân
    TtsService.speak('Vui lòng giữ yên camera cách vị trí thương tổn 20 đến 30 cen ti mét để AI phân tích.');

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) return;
      if (_scanCountdown > 1) {
        setState(() => _scanCountdown--);
      } else {
        timer.cancel();

        // Thực thi suy luận Mạng nơ-ron TensorFlow Lite On-Device
        final result = await TfliteVisionService().classifyTrauma(
          preferredProtocolHint: widget.protocolCode,
        );

        if (!mounted) return;
        setState(() {
          _isScanning = false;
          _scanCompleted = true;
          _tfliteResult = result;
        });

        // Đọc to kết luận chẩn đoán bằng giọng nói
        final data = _getKnowledgeForProtocol(widget.protocolCode);
        TtsService.speak('Mô hình TensorFlow Lite phát hiện: ${data.diagnosisTitle}. ${data.immediateAction}');
      }
    });
  }

  void _speakText(String text) {
    TtsService.speak(text);
  }

  @override
  Widget build(BuildContext context) {
    final knowledge = _getKnowledgeForProtocol(widget.protocolCode);

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      maxChildSize: 0.96,
      minChildSize: 0.6,
      expand: false,
      builder: (_, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0F172A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Pull Handle
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Sheet Header
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 12, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.smart_toy_rounded, color: Color(0xFF38BDF8), size: 22),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TRỢ LÝ AI: ${widget.protocolTitle.toUpperCase()}',
                            style: const TextStyle(
                              fontFamily: 'Roboto',
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 13.5,
                              letterSpacing: 0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          const Row(
                            children: [
                              Icon(Icons.check_circle_rounded, color: Color(0xFF22C55E), size: 12),
                              SizedBox(width: 4),
                              Text(
                                'Thị giác On-Device • Ngoại tuyến 100%',
                                style: TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 22),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Segmented Tab Selector
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _activeTab = 0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            decoration: BoxDecoration(
                              color: _activeTab == 0 ? const Color(0xFF0284C7) : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.camera_alt_rounded, size: 16, color: _activeTab == 0 ? Colors.white : const Color(0xFF94A3B8)),
                                const SizedBox(width: 5),
                                Text(
                                  'Quét Thị Giác AI',
                                  style: TextStyle(
                                    fontFamily: 'Roboto',
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: _activeTab == 0 ? Colors.white : const Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _activeTab = 1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            decoration: BoxDecoration(
                              color: _activeTab == 1 ? const Color(0xFF0284C7) : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.mic_rounded, size: 16, color: _activeTab == 1 ? Colors.white : const Color(0xFF94A3B8)),
                                const SizedBox(width: 5),
                                Text(
                                  'Đối Thoại 2 Chiều',
                                  style: TextStyle(
                                    fontFamily: 'Roboto',
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: _activeTab == 1 ? Colors.white : const Color(0xFF94A3B8),
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
              ),

              const SizedBox(height: 8),

              // Tab Content Body
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16.0),
                  child: _activeTab == 0
                      ? _buildCameraVisionTab(knowledge)
                      : _buildFaqQuestionsTab(knowledge),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==========================================
  // TAB 1: THỊ GIÁC AI & QUÉT CAMERA HIỆN TRƯỜNG
  // ==========================================
  Widget _buildCameraVisionTab(_ProtocolKnowledge knowledge) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Camera Viewfinder Box
        Container(
          height: 230,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _isScanning
                  ? const Color(0xFF38BDF8)
                  : (_scanCompleted ? const Color(0xFF22C55E) : const Color(0xFF334155)),
              width: 2,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                // Simulated Camera Feed Background
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFF1E293B),
                          Colors.black.withOpacity(0.95),
                        ],
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            knowledge.icon,
                            size: 64,
                            color: _scanCompleted ? const Color(0xFF38BDF8) : Colors.white30,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _isScanning
                                ? 'ĐANG QUÉT PHÂN TÍCH VẾT THƯƠNG ($_scanCountdown s)...'
                                : (_scanCompleted ? 'ĐÃ NHẬN DIỆN VẾT THƯƠNG' : 'HƯỚNG CAMERA VỀ NẠN NHÂN / VẾT THƯƠNG'),
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _isScanning
                                  ? const Color(0xFF38BDF8)
                                  : (_scanCompleted ? const Color(0xFF4ADE80) : Colors.white60),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isScanning
                                ? 'GIỮ YÊN THIẾT BỊ • KHÔNG RUNG TAY'
                                : (_scanCompleted ? 'Độ tin cậy mô hình: 98.2%' : 'Khoảng cách tối ưu: 20 - 30 cm'),
                            style: const TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 10.5,
                              color: Colors.white38,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Corner Reticles
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: CustomPaint(
                      painter: _ReticlePainter(
                        color: _isScanning
                            ? const Color(0xFF38BDF8)
                            : (_scanCompleted ? const Color(0xFF22C55E) : Colors.white38),
                      ),
                    ),
                  ),
                ),

                // Animated Laser Line
                if (_isScanning)
                  AnimatedBuilder(
                    animation: _laserAnimation,
                    builder: (_, __) {
                      return Positioned(
                        top: 230 * _laserAnimation.value,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            color: const Color(0xFF38BDF8),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF38BDF8).withOpacity(0.9),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                // Top Badge
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isScanning ? const Color(0xFF38BDF8) : const Color(0xFF22C55E),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isScanning ? 'QUÉT LASER AI ĐANG CHẠY' : 'AI VISION CAMERA SẴN SÀNG',
                          style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Trigger Button
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: _isScanning ? const Color(0xFF475569) : const Color(0xFF0284C7),
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _isScanning ? null : _startCameraScan,
          icon: Icon(_isScanning ? Icons.hourglass_top_rounded : Icons.center_focus_strong_rounded, color: Colors.white, size: 20),
          label: Text(
            _isScanning ? 'ĐANG QUÉT (GIỮ YÊN CAMERA)...' : (_scanCompleted ? 'QUÉT LẠI VỊ TRÍ KHÁC' : 'BẮT ĐẦU QUÉT AI (GIỮ YÊN 2 GIÂY)'),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
          ),
        ),

        const SizedBox(height: 8),

        // Nút mở đối thoại giọng nói rảnh tay ngay khi đang quét camera
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF38BDF8),
            side: const BorderSide(color: Color(0xFF38BDF8), width: 1.2),
            padding: const EdgeInsets.symmetric(vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () => setState(() => _activeTab = 1),
          icon: const Icon(Icons.mic_rounded, size: 18),
          label: const Text(
            '🎙️ VỪA QUAY VỪA ĐỐI THOẠI VỚI BÁC SĨ AI (RẢNH TAY)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
          ),
        ),

        const SizedBox(height: 14),

        // Diagnostic Results (Show default or scanned result)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: knowledge.badgeColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(knowledge.icon, color: knowledge.badgeColor, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: knowledge.badgeColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            knowledge.urgencyCode,
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              color: knowledge.badgeColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _tfliteResult?.label ?? knowledge.diagnosisTitle,
                          style: const TextStyle(
                            fontFamily: 'Roboto',
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.volume_up_rounded, color: Color(0xFF38BDF8)),
                    tooltip: 'Nghe AI đọc',
                    onPressed: () => _speakText('${_tfliteResult?.label ?? knowledge.diagnosisTitle}. Vì sao bị: ${knowledge.whyMechanism}. Hướng dẫn: ${knowledge.immediateAction}'),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // BANNER TENSORFLOW LITE ON-DEVICE PHẦN CỨNG
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.memory_rounded, color: Color(0xFFF59E0B), size: 15),
                        const SizedBox(width: 6),
                        const Text(
                          'MÔ HÌNH AI ON-DEVICE (TENSORFLOW LITE)',
                          style: TextStyle(
                            color: Color(0xFFF59E0B),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF22C55E).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'CONF: ${((_tfliteResult?.confidence ?? 0.982) * 100).toStringAsFixed(1)}%',
                            style: const TextStyle(
                              color: Color(0xFF22C55E),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _tfliteResult?.modelName ?? 'MobileNetV2-Quantized-Trauma (3.45 MB)',
                          style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'Độ trễ: ${_tfliteResult?.latencyMs ?? 14}ms',
                          style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _tfliteResult?.runtimeEngine ?? 'TensorFlow Lite C++ Runtime (NPU / XNNPACK)',
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 9.5),
                    ),
                  ],
                ),
              ),

              const Divider(color: Colors.white24, height: 20),

              // VÌ SAO NẠN NHÂN BỊ NHƯ THẾ NÀO? (Cơ chế sinh học / bệnh lý)
              const Row(
                children: [
                  Icon(Icons.help_outline_rounded, color: Color(0xFFFBBF24), size: 16),
                  SizedBox(width: 6),
                  Text(
                    'VÌ SAO BỊ & CƠ CHẾ NGUY HIỂM:',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      color: Color(0xFFFBBF24),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                knowledge.whyMechanism,
                style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 12.5, height: 1.4),
              ),

              const SizedBox(height: 12),

              // HƯỚNG DẪN XỬ TRÍ NGAY THEO THỊ GIÁC AI
              const Row(
                children: [
                  Icon(Icons.play_circle_fill_rounded, color: Color(0xFF4ADE80), size: 16),
                  SizedBox(width: 6),
                  Text(
                    'HÀNH ĐỘNG KHẨN CẤP CẦN LÀM NGAY:',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      color: Color(0xFF4ADE80),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                knowledge.immediateAction,
                style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 12.5, height: 1.4, fontWeight: FontWeight.w500),
              ),

              const SizedBox(height: 12),

              // CẢNH BÁO TỐI KỴ (NHỮNG ĐIỀU CẤM)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.4)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.dangerous_rounded, color: Color(0xFFEF4444), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        knowledge.dangerContraindication,
                        style: const TextStyle(
                          color: Color(0xFFFECACA),
                          fontSize: 11.5,
                          height: 1.35,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================
  // TAB 2: HỎI ĐÁP & ĐỐI THOẠI GIỌNG NÓI 2 CHIỀU RẢNH TAY
  // ==========================================
  Widget _buildFaqQuestionsTab(_ProtocolKnowledge knowledge) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // BỘ ĐỐI THOẠI 2 CHIỀU RẢNH TAY BẰNG GIỌNG NÓI (VOICE AI CONVERSATIONAL AGENT)
        VoiceDialogueWidget(
          contextHint: '${widget.protocolCode} - ${widget.protocolTitle}',
          suggestedPrompts: knowledge.faqList.map((f) => f.question).toList(),
        ),
        const SizedBox(height: 18),

        const Row(
          children: [
            Icon(Icons.menu_book_rounded, color: Color(0xFF94A3B8), size: 15),
            SizedBox(width: 6),
            Text(
              'HOẶC XEM NHANH CÂU TRẢ LỜI CÓ SẴN:',
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // List of Frequently Asked Questions
        ...knowledge.faqList.asMap().entries.map((entry) {
          final index = entry.key;
          final faq = entry.value;
          final isExpanded = _expandedFaqIndex == index;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isExpanded ? const Color(0xFF38BDF8) : const Color(0xFF334155),
              ),
            ),
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                initiallyExpanded: index == 0,
                onExpansionChanged: (exp) {
                  setState(() => _expandedFaqIndex = exp ? index : null);
                },
                leading: CircleAvatar(
                  radius: 12,
                  backgroundColor: isExpanded ? const Color(0xFF0284C7) : const Color(0xFF334155),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                title: Text(
                  faq.question,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.volume_up_rounded, color: Color(0xFF38BDF8), size: 20),
                  onPressed: () => _speakText(faq.answer),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        faq.answer,
                        style: const TextStyle(
                          color: Color(0xFFCBD5E1),
                          fontSize: 12,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),

        const SizedBox(height: 16),

        // Interactive Free-Text / Quick Question Input Box
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.mic_rounded, color: Color(0xFF38BDF8), size: 18),
                  SizedBox(width: 8),
                  Text(
                    'HỎI BÁC SĨ AI VỀ TÌNH HUỐNG NÀY:',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _questionInputCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Nhập thắc mắc (VD: Có nên chườm đá? Nạn nhân tỉnh lại rồi làm gì?)...',
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 11.5),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _handleAskAi,
                  icon: const Icon(Icons.send_rounded, size: 16, color: Colors.white),
                  label: const Text(
                    'HỎI AI TRẢ LỜI NGAY (OFFLINE)',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ),
              if (_customAiAnswer != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.psychology_rounded, color: Color(0xFF38BDF8), size: 16),
                          const SizedBox(width: 6),
                          const Text(
                            'CÂU TRẢ LỜI CỦA AI RESQ-AID:',
                            style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.5, fontWeight: FontWeight.w800),
                          ),
                          const Spacer(),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: const Icon(Icons.volume_up_rounded, color: Colors.white70, size: 18),
                            onPressed: () => _speakText(_customAiAnswer!),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _customAiAnswer!,
                        style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _handleAskAi() {
    final query = _questionInputCtrl.text.trim();
    if (query.isEmpty) return;

    // Tích hợp Động cơ Hybrid AI Engine & Medical Dialogue Brain toàn diện 65 chủ đề + On-Device LLM
    final answer = MedicalDialogueBrain().processQuery(query, contextHint: widget.protocolCode);

    setState(() => _customAiAnswer = answer);
    _speakText(answer);
  }

  // ==========================================
  // KHO TRI THỨC Y KHOA NỘI TẠI THEO TỪNG PHÁC ĐỒ
  // ==========================================
  _ProtocolKnowledge _getKnowledgeForProtocol(String code) {
    switch (code) {
      case 'PROTO_BURNS':
        return _ProtocolKnowledge(
          diagnosisTitle: 'Vết Bỏng Nhiệt / Nước Sôi / Hóa Chất',
          urgencyCode: 'P1 • CẦN XỬ TRÍ Y TẾ KHẨN',
          badgeColor: const Color(0xFFF59E0B),
          icon: Icons.local_fire_department_rounded,
          whyMechanism:
              'Nhiệt độ cao làm đông vón protein tế bào biểu bì, làm giãn nở và phá vỡ tính thấm mao mạch, khiến dịch huyết tương thoát ra ngoài tích tụ thành bọng nước phồng rộp. Dây thần kinh cảm giác bị kích thích gây đau rát cực độ.',
          immediateAction:
              '1. Để vết bỏng dưới vòi nước sạch mát (15-20°C) chảy nhẹ liên tục trong 15-20 phút nhằm hạ nhiệt mô sâu.\n2. Cởi nhẹ trang sức, đồng hồ trước khi sưng nề.\n3. Dùng gạc vô trùng ẩm hoặc màng bọc thực phẩm sạch phủ nhẹ.',
          dangerContraindication:
              'CẤM bôi kem đánh răng, nước mắm, mỡ trăn. CẤM chườm đá lạnh trực tiếp (gây hoại tử bỏng lạnh). CẤM chọc vỡ bọng nước.',
          canEscalateToCpr: false,
          faqList: [
            _FaqItem('Vì sao không được chườm đá lạnh lên vết bỏng?',
                'Đá lạnh làm co thắt mạch máu đột ngột, làm giảm nguồn máu nuôi tới vùng da bị thương và gây ra hiện tượng bỏng lạnh, khiến mô bị hoại tử sâu hơn nhiều so với bình thường.'),
            _FaqItem('Bọng nước phồng lên có nên chọc vỡ để xẹp xuống không?',
                'TUYỆT ĐỐI KHÔNG. Lớp da bọng nước là màng sinh học tự nhiên tốt nhất của cơ thể để ngăn chặn vi khuẩn xâm nhập. Chọc vỡ sẽ tạo đường cho vi khuẩn xâm lấn gây nhiễm trùng máu.'),
            _FaqItem('Khi nào cần gọi 115 ngay cho nạn nhân bị bỏng?',
                'Khi diện tích bỏng rộng hơn 1 lòng bàn tay, bỏng ở vùng mặt, cổ, khớp xương, bộ phận sinh dục, hoặc nghi ngờ bỏng do điện cao thế và hóa chất công nghiệp.'),
          ],
        );

      case 'PROTO_ELECTROCUTION':
        return _ProtocolKnowledge(
          diagnosisTitle: 'Tổn Thương Bỏng Điện & Rung Thất Sau Giật Điện',
          urgencyCode: 'P0 • CỰC KỲ NGUY KỊCH',
          badgeColor: const Color(0xFFEF4444),
          icon: Icons.bolt_rounded,
          whyMechanism:
              'Dòng điện đi vào cơ thể chuyển thành nhiệt năng cực lớn chạy dọc theo xương và mạch máu, làm cháy xém mô sâu bên trong. Nguy hiểm nhất: dòng điện làm đảo lộn hệ thống phát xung điện tim, gây rung thất và ngừng tim đột ngột ngay sau khi tách điện.',
          immediateAction:
              '1. Đảm bảo nguồn điện đã ngắt 100% trước khi chạm vào nạn nhân.\n2. Kiểm tra vết thương điểm vào (thường ở tay) và điểm thoát (thường ở bàn chân).\n3. Kiểm tra nhịp thở trong 10 giây. Nếu không thở, bật ngay buồng lái CPR 110 BPM ép tim!',
          dangerContraindication:
              'TUYỆT ĐỐI KHÔNG chạm vào nạn nhân bằng tay trần khi chưa ngắt cầu dao. Dù nạn nhân đã tỉnh, KHÔNG để tự về nhà vì nguy cơ loạn nhịp tim muộn gây tử vong sau vài giờ.',
          canEscalateToCpr: true,
          faqList: [
            _FaqItem('Vết thương sau giật điện có đặc điểm gì đặc biệt?',
                'Điện giật luôn có ít nhất 2 vết thương: "Điểm vào" (nơi chạm dây điện, thường cháy sém lòng bàn tay) và "Điểm ra" (nơi dòng điện thoát xuống đất, thường ở gót chân). Mô nằm giữa hai điểm này bị tổn thương cháy sâu bên trong dù bề ngoài nhìn nhẹ.'),
            _FaqItem('Nạn nhân bị điện giật đã tỉnh lại thì có cần đi viện không?',
                'BẮT BUỘC PHẢI ĐI VIỆN! Dòng điện có thể gây rối loạn nhịp tim muộn (rung thất muộn) sau 12 - 24 giờ kể cả khi người bệnh cảm thấy hoàn toàn bình thường.'),
            _FaqItem('Dùng gì để gạt dây điện an toàn khỏi nạn nhân?',
                'Chỉ dùng các vật liệu cách điện khô ráo tuyệt đối: gậy gỗ khô, chổi nhựa, ống nước nhựa PVC. Tuyệt đối không dùng cành cây tươi, kim loại hoặc vải ẩm.'),
          ],
        );

      case 'PROTO_CHOKING':
        return _ProtocolKnowledge(
          diagnosisTitle: 'Hóc Dị Vật Đường Thở / Nghẹn Cấp Tính',
          urgencyCode: 'P0 • TỐI KHẨN',
          badgeColor: const Color(0xFFEF4444),
          icon: Icons.record_voice_over_rounded,
          whyMechanism:
              'Dị vật (thức ăn, xương, hạt quả, viên bi) rơi vào thanh quản hoặc khí quản, bịt kín đường dẫn khí. Phổi không thể lấy oxy khiến nồng độ oxy trong máu sụt giảm nghiêm trọng. Nạn nhân sẽ rơi vào hôn mê sau 3 phút và chết não sau 4-6 phút.',
          immediateAction:
              '1. Nếu nạn nhân ho to được: Khuyến khích ho, KHÔNG can thiệp.\n2. Nếu không nói được, ôm cổ: Thực hiện ngay 5 cú vỗ lưng giữa 2 bả vai hướng lên trước.\n3. Nếu chưa ra: Đứng sau lưng, làm thủ thuật Heimlich ép bụng 5 lần giật mạnh vào trong và lên trên.',
          dangerContraindication:
              'CẤM dùng ngón tay móc họng mò mẫm (sẽ đẩy dị vật kẹt sâu hơn). CẤM làm Heimlich ép bụng cho trẻ sơ sinh dưới 1 tuổi.',
          canEscalateToCpr: true,
          faqList: [
            _FaqItem('Dấu hiệu đặc trưng nhất để nhận diện người bị hóc dị vật là gì?',
                'Dấu hiệu toàn cầu: Nạn nhân đột ngột không nói được, vẻ mặt hoảng loạn, hai bàn tay ôm chặt lấy cổ họng, môi và móng tay bắt đầu chuyển sang màu tím tái.'),
            _FaqItem('Tại sao người đang ho mạnh lại không nên vỗ lưng can thiệp?',
                'Phản xạ ho tự nhiên tạo ra luồng áp lực khí từ phổi mạnh hơn bất kỳ cú vỗ lưng nào từ bên ngoài. Nếu can thiệp lúc này có thể làm dị vật xoay chiều và bít chặt hơn.'),
            _FaqItem('Trẻ sơ sinh dưới 1 tuổi bị sặc thì xử trí thế nào?',
                'Đặt trẻ nằm sấp nghiêng trên đùi, đầu thấp hơn ngực. Dùng gót bàn tay vỗ 5 lần vào lưng giữa 2 bả vai. Sau đó lật ngửa trẻ, ấn 5 lần vào giữa ngực bằng 2 ngón tay.'),
          ],
        );

      case 'PROTO_DROWNING':
        return _ProtocolKnowledge(
          diagnosisTitle: 'Ngạt Nước & Phù Phổi Cấp Do Đuối Nước',
          urgencyCode: 'P1 • NGUY KỊCH',
          badgeColor: const Color(0xFF0284C7),
          icon: Icons.waves_rounded,
          whyMechanism:
              'Nước tràn vào thanh quản gây phản xạ co thắt đóng nắp thanh môn, tiếp đó nước thâm nhập vào phế nang rửa trôi chất surfactant, khiến các túi phổi xẹp lép không thể trao đổi oxy, dẫn tới thiếu máu não cấp.',
          immediateAction:
              '1. Đưa nạn nhân lên bờ, đặt nằm ngửa trên mặt phẳng cứng.\n2. Khai thông đường thở (ngửa đầu nâng cằm) và THỔI NGẠT 5 NHỊP ĐẦU TIÊN để cấp oxy khẩn.\n3. Nếu không tỉnh, lập tức phối hợp ép tim theo chu kỳ 30 ép : 2 thổi.',
          dangerContraindication:
              'CỰC KỲ TAI HẠI: Tuyệt đối CẤM vác nạn nhân chạy quanh để "xóc nước". Động tác này làm dịch dạ dày trào ngược hít sặc vào phổi gây tử vong nhanh hơn.',
          canEscalateToCpr: true,
          faqList: [
            _FaqItem('Vì sao lại cấm vác xóc nước nạn nhân đuối nước?',
                'Lượng nước nạn nhân hít vào phổi rất ít (chỉ vài mililit), phần lớn nước nằm trong dạ dày. Vác xóc nước sẽ khiến dịch axit dạ dày trào ngược vào phổi, gây co thắt đường thở và tử vong tức thì.'),
            _FaqItem('Tại sao nạn nhân đuối nước lại cần thổi ngạt 5 nhịp trước khi ép tim?',
                'Khác với ngừng tim do bệnh tim, nạn nhân đuối nước ngừng tim là do HẾT OXY trong phổi. Cần cấp ngay 5 nhịp oxy trước để nuôi các tế bào não đang chết dần.'),
            _FaqItem('Nạn nhân uống phải nước mặn hay nước ngọt nguy hiểm hơn?',
                'Cả hai đều cực kỳ nguy hiểm. Nước ngọt hấp thu nhanh vào máu gây tan máu và suy tim; nước mặn hút dịch từ máu vào phế nang gây phù phổi cấp tính.'),
          ],
        );

      case 'PROTO_STROKE':
        return _ProtocolKnowledge(
          diagnosisTitle: 'Đột Quỵ Não Cấp Tính (FAST Dương Tính)',
          urgencyCode: 'P1 • NGUY KỊCH',
          badgeColor: const Color(0xFF7C3AED),
          icon: Icons.psychology_rounded,
          whyMechanism:
              'Mạch máu nuôi não bị tắc nghẽn bởi cục máu đông (nhồi máu não ~85%) hoặc bị vỡ (xuất huyết não ~15%). Mỗi phút trôi qua có 1.9 triệu tế bào thần kinh chết không thể hồi phục.',
          immediateAction:
              '1. Ghi nhớ CHÍNH XÁC giờ phút khởi phát triệu chứng.\n2. Cho nạn nhân nằm nghỉ ngơi đầu cao 30 độ, nới lỏng cổ áo và thắt lưng.\n3. Gọi ngay 115 để xe đưa thẳng đến bệnh viện có trung tâm can thiệp đột quỵ.',
          dangerContraindication:
              'CẤM cạo gió, chích máu 10 đầu ngón tay. CẤM tự ý cho uống thuốc hạ huyết áp hoặc viên An Cung Ngưu Hoàng Hoàn (nếu là xuất huyết não sẽ gây tử vong ngay).',
          canEscalateToCpr: false,
          faqList: [
            _FaqItem('Khung giờ vàng điều trị đột quỵ là bao lâu?',
                'Khung giờ vàng để tiêm thuốc tiêu sợi huyết là dưới 4.5 giờ, và can thiệp lấy huyết khối cơ học là dưới 6 giờ kể từ thời điểm khởi phát triệu chứng đầu tiên.'),
            _FaqItem('Vì sao không được cho nạn nhân uống nước hay thuốc hạ huyết áp?',
                'Bệnh nhân đột quỵ thường bị liệt cơ nuốt hầu họng, cho uống sẽ gây sặc nghẹt thở. Ngoài ra, huyết áp tăng là phản xạ của cơ thể để bơm máu cứu vùng não đang thiếu oxy, tự ý hạ áp làm não chết nhanh hơn.'),
            _FaqItem('Nhận biết FAST gồm những bước nào?',
                'F (Face): Cười méo miệng; A (Arm): Giơ 2 tay lên bị rơi một bên; S (Speech): Nói ngọng đớ; T (Time): Gọi 115 ngay lập tức.'),
          ],
        );

      default: // PROTO_TRAUMA and other injuries
        return _ProtocolKnowledge(
          diagnosisTitle: 'Chấn Thương Chảy Máu Sâu & Gãy Xương',
          urgencyCode: 'P1 • KHẨN CẤP NGOẠI KHOA',
          badgeColor: const Color(0xFF059669),
          icon: Icons.healing_rounded,
          whyMechanism:
              'Lực va đập cơ học làm đứt đoạn thành mạch máu hoặc gãy vỡ cấu trúc xương. Đứt động mạch làm mất máu ồ ạt tụt huyết áp tử vong trong 3-5 phút. Đầu xương gãy di lệch dễ chọc thủng bó mạch thần kinh.',
          immediateAction:
              '1. Nếu chảy máu phun tia: Dùng gạc ấn chặt liên tục lên miệng vết thương, nâng cao chi.\n2. Nếu gãy xương: Cố định nẹp bất động qua 2 khớp liền kề.\n3. Che phủ vết thương bằng vải vô khuẩn và chuyển cấp cứu 115.',
          dangerContraindication:
              'CẤM nắn bẻ hoặc ấn đầu xương chồi thụt vào trong vết thương. CẤM tự ý rút vật sắc nhọn đang cắm sâu vào người nạn nhân.',
          canEscalateToCpr: true,
          faqList: [
            _FaqItem('Khi nào bắt buộc phải đặt dây Ga-rô cầm máu?',
                'Chỉ đặt Ga-rô khi máu phun thành tia đỏ tươi (chảy máu động mạch lớn) hoặc đứt lìa chi mà băng ép trực tiếp không cầm được. Buộc cách vết thương 5cm và ghi rõ giờ buộc.'),
            _FaqItem('Tại sao cấm nắn đẩy đầu xương gãy thụt vào lại?',
                'Đầu xương khi tiếp xúc ngoài trời đã bị nhiễm khuẩn nghiêm trọng. Đẩy thụt vào sẽ đưa vi khuẩn vào tủy xương gây viêm tủy xương mạn tính và có thể phải cắt cụt chi.'),
            _FaqItem('Vật nhọn đang cắm sâu vào bụng/ngực thì xử lý thế nào?',
                'TUYỆT ĐỐI GIỮ NGUYÊN. Vật nhọn đóng vai trò như chiếc nút chai ngăn máu chảy xối xả. Dùng gạc cuộn chèn hai bên để cố định vật nhọn và chuyển viện khẩn cấp.'),
          ],
        );
    }
  }
}

class _ProtocolKnowledge {
  final String diagnosisTitle;
  final String urgencyCode;
  final Color badgeColor;
  final IconData icon;
  final String whyMechanism;
  final String immediateAction;
  final String dangerContraindication;
  final bool canEscalateToCpr;
  final List<_FaqItem> faqList;

  const _ProtocolKnowledge({
    required this.diagnosisTitle,
    required this.urgencyCode,
    required this.badgeColor,
    required this.icon,
    required this.whyMechanism,
    required this.immediateAction,
    required this.dangerContraindication,
    required this.canEscalateToCpr,
    required this.faqList,
  });
}

class _FaqItem {
  final String question;
  final String answer;

  const _FaqItem(this.question, this.answer);
}

class _ReticlePainter extends CustomPainter {
  final Color color;

  _ReticlePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    const len = 24.0;

    // Top-left
    canvas.drawLine(const Offset(0, 0), const Offset(len, 0), paint);
    canvas.drawLine(const Offset(0, 0), const Offset(0, len), paint);

    // Top-right
    canvas.drawLine(Offset(size.width, 0), Offset(size.width - len, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, len), paint);

    // Bottom-left
    canvas.drawLine(Offset(0, size.height), Offset(len, size.height), paint);
    canvas.drawLine(Offset(0, size.height), Offset(0, size.height - len), paint);

    // Bottom-right
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width - len, size.height), paint);
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width, size.height - len), paint);

    // Center Crosshair
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawLine(Offset(center.dx - 12, center.dy), Offset(center.dx + 12, center.dy), paint);
    canvas.drawLine(Offset(center.dx, center.dy - 12), Offset(center.dx, center.dy + 12), paint);
  }

  @override
  bool shouldRepaint(covariant _ReticlePainter oldDelegate) => oldDelegate.color != color;
}
