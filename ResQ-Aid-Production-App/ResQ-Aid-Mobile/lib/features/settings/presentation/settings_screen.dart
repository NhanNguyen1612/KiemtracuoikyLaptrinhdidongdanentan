import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/services/demo_mode_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../consent/presentation/consent_screen.dart';
import 'ai_model_manager_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDemo = ref.watch(demoModeProvider);
    final db = ref.watch(databaseProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('CÀI ĐẶT & BẢO MẬT'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0.5,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Demo Mode Toggle Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDemo ? const Color(0xFFFEF3C7) : const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isDemo ? Icons.shield_rounded : Icons.warning_rounded,
                    color: isDemo ? const Color(0xFFD97706) : AppTheme.emergencyRed,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isDemo ? 'Chế độ Demo Hội đồng (Bật)' : 'Chế độ Gọi 115 Thật (Live)',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isDemo
                            ? 'Bảo vệ an toàn: Chuyển hướng cuộc gọi sang số kiểm thử (${DemoModeService.defaultDemoPhone})'
                            : 'CẢNH BÁO: Cuộc gọi sẽ kết nối trực tiếp Tổng đài 115!',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDemo ? const Color(0xFF64748B) : Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: isDemo,
                  activeColor: const Color(0xFF16A34A),
                  onChanged: (_) => ref.read(demoModeProvider.notifier).toggle(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // On-Device Pure Local AI Model Manager
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF818CF8)),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AiModelManagerScreen()),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(Icons.memory_rounded, color: Color(0xFF4F46E5), size: 24),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Quản lý Mô hình AI Local (NPU / Tensor)',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Color(0xFF0F172A)),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Kiểm tra RAM, Vector RAG, TraumaVisionNet & tải gói GGUF Offline',
                              style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF94A3B8), size: 14),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Privacy Policy (Nghị định 13)
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ConsentScreen()),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(Icons.privacy_tip_rounded, color: Color(0xFF0284C7), size: 24),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Minh bạch Dữ liệu (Nghị định 13)',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: Color(0xFF0F172A)),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Cam kết xử lý RAM cục bộ, không lưu trữ dữ liệu sinh trắc học',
                              style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF94A3B8), size: 14),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Purge Data Danger Zone
          Container(
            padding: const EdgeInsets.all(16),
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
                    Icon(Icons.delete_sweep_rounded, color: Color(0xFFDC2626), size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Xóa Toàn bộ Dữ liệu Cục bộ',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Color(0xFF991B1B)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Quyền được lãng quên theo Nghị định 13: Xóa sạch hàng đợi Outbox, bộ đếm nhịp và nhật ký ca cấp cứu trên máy này.',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF7F1D1D), height: 1.3),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      await db.purgeAllLocalData();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('✓ Đã xóa sạch toàn bộ dữ liệu nội bộ trên máy!')),
                        );
                      }
                    },
                    icon: const Icon(Icons.delete_forever_rounded, size: 18),
                    label: const Text('XÓA SẠCH DỮ LIỆU ĐÃ LƯU', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Legal Disclaimer Banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.gavel_rounded, color: Color(0xFF475569), size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'TUYÊN BỐ PHÁP LÝ:\nResQ-Aid v2.0 là giải pháp hỗ trợ sơ cứu khẩn cấp, không thay thế cho dịch vụ cấp cứu y tế chuyên nghiệp 115 hay chẩn đoán lâm sàng của bác sĩ.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF475569), height: 1.4, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          const Center(
            child: Text(
              'ResQ-Aid v2.0 — Đại học VKU 2026\nPhiên bản: 2.0.1 (Build 20261105)',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8), height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
