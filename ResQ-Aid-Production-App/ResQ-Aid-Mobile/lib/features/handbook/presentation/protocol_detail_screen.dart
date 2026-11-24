import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/database/app_database.dart';
import '../../../core/services/demo_mode_service.dart';
import '../../../core/services/tts_service.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/protocol_model.dart';
import 'ai_first_aid_assistant_sheet.dart';

class ProtocolDetailScreen extends StatefulWidget {
  final ProtocolEntry protocol;

  const ProtocolDetailScreen({super.key, required this.protocol});

  @override
  State<ProtocolDetailScreen> createState() => _ProtocolDetailScreenState();
}

class _ProtocolDetailScreenState extends State<ProtocolDetailScreen> {
  bool _isSpeaking = false;

  Future<void> _speakGuidance(ProtocolDetail detail) async {
    setState(() => _isSpeaking = true);
    final buffer = StringBuffer();
    buffer.writeln('${widget.protocol.title}. ${detail.quickSummary}.');
    for (final s in detail.steps) {
      buffer.writeln('Bước ${s.step}: ${s.title}. ${s.instruction}.');
    }
    await TtsService.speak(buffer.toString());
    if (mounted) {
      setState(() => _isSpeaking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = ProtocolDetail.fromJsonString(widget.protocol.contentJson);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          widget.protocol.title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.smart_toy_rounded, color: Color(0xFF0284C7)),
            tooltip: 'Trợ lý AI Khám Hiện trường',
            onPressed: () {
              AiFirstAidAssistantSheet.show(
                context,
                widget.protocol.protocolCode,
                widget.protocol.title,
              );
            },
          ),
          IconButton(
            icon: Icon(
              _isSpeaking ? Icons.record_voice_over_rounded : Icons.volume_up_rounded,
              color: _isSpeaking ? AppTheme.emergencyRed : AppTheme.medicalBlue,
            ),
            tooltip: 'Đọc to toàn bộ hướng dẫn',
            onPressed: () => _speakGuidance(detail),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quick Summary & Target Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.verified_rounded, color: Color(0xFF0284C7), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Đối tượng: ${detail.target}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 10.5,
                                    color: Color(0xFF15803D),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Chuẩn AHA ✓',
                              style: TextStyle(fontSize: 11, color: Color(0xFF1D4ED8), fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          detail.quickSummary,
                          style: const TextStyle(color: Color(0xFF334155), fontSize: 13, height: 1.35, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // NÚT TRỢ LÝ AI KHÁM HIỆN TRƯỜNG & HỎI ĐÁP
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: const Color(0xFF38BDF8), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0284C7).withOpacity(0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    AiFirstAidAssistantSheet.show(
                      context,
                      widget.protocol.protocolCode,
                      widget.protocol.title,
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0284C7).withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.smart_toy_rounded, color: Color(0xFF38BDF8), size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'TRỢ LÝ BÁC SĨ AI (GIỌNG NÓI & QUAY KHÁM)',
                                      style: TextStyle(
                                        fontFamily: 'Roboto',
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 13,
                                        letterSpacing: 0.3,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  SizedBox(width: 6),
                                  Icon(Icons.auto_awesome, color: Color(0xFFFBBF24), size: 14),
                                ],
                              ),
                              SizedBox(height: 3),
                              Text(
                                '🎙️ Đối thoại 2 chiều rảnh tay (không gõ phím) • Camera quét hiện trường',
                                style: TextStyle(
                                  fontFamily: 'Roboto',
                                  color: Color(0xFF94A3B8),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF38BDF8), size: 14),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 18),

            const Text(
              'CÁC BƯỚC XỬ TRÍ TUẦN TỰ (CHUẨN AHA / BỘ Y TẾ):',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF475569), letterSpacing: 0.5),
            ),
            const SizedBox(height: 10),

            // Step List
            ...detail.steps.map((step) => _buildStepCard(step)),

            const SizedBox(height: 14),

            // Severe Contraindications Warning Callout
            if (detail.contraindications.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.dangerous_rounded, color: Color(0xFFDC2626), size: 20),
                        SizedBox(width: 8),
                        Text(
                          'CẢNH BÁO NGUY HIỂM — TUYỆT ĐỐI TRÁNH:',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: Color(0xFF991B1B)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...detail.contraindications.map(
                      (c) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• ', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold, fontSize: 14)),
                            Expanded(
                              child: Text(
                                c,
                                style: const TextStyle(fontSize: 12.5, color: Color(0xFF7F1D1D), fontWeight: FontWeight.w600, height: 1.3),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Call 115 Action Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.safeGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () async {
                  final phone = await DemoModeService.getEmergencyPhone();
                  final uri = Uri.parse('tel:$phone');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  }
                },
                icon: const Icon(Icons.phone_in_talk_rounded, size: 20),
                label: const Text('GỌI ĐIỆN THOẠI 115 TRỢ GIÚP'),
              ),
            ),
            const SizedBox(height: 70),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0284C7),
        elevation: 6,
        icon: const Icon(Icons.record_voice_over_rounded, color: Colors.white, size: 20),
        label: const Text(
          '🎙️ BÁC SĨ AI (RẢNH TAY)',
          style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w900, color: Colors.white, fontSize: 12),
        ),
        onPressed: () {
          AiFirstAidAssistantSheet.show(
            context,
            widget.protocol.protocolCode,
            widget.protocol.title,
          );
        },
      ),
    );
  }

  Widget _buildStepCard(ProtocolStep step) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    step.step.toString().padLeft(2, '0'),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  step.title,
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            step.instruction,
            style: const TextStyle(fontSize: 13, height: 1.4, color: Color(0xFF334155), fontWeight: FontWeight.w500),
          ),
          if (step.warning != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, color: Color(0xFFD97706), size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      step.warning!,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
