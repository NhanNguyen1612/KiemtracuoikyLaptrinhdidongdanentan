import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/database_provider.dart';

class ConsentScreen extends ConsumerWidget {
  const ConsentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Minh bạch Dữ liệu & Quyền riêng tư'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner Nghị định 13
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
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: const Icon(Icons.verified_user_rounded, color: Color(0xFF0284C7), size: 26),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tuân thủ Nghị định 13/2023/NĐ-CP',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: Color(0xFF0F172A)),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Bảo vệ dữ liệu cá nhân & bảo mật thông tin y tế theo tiêu chuẩn pháp luật Việt Nam.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              '4 NGUYÊN TẮC MINH BẠCH DỮ LIỆU CỦA RESQ-AID:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF475569), letterSpacing: 0.5),
            ),
            const SizedBox(height: 10),

            _buildPrivacyTile(
              icon: Icons.location_on_rounded,
              color: const Color(0xFFDC2626),
              title: '1. Tọa độ GPS Phần cứng',
              desc: 'Chỉ đọc và truyền tọa độ khi bạn bấm SOS khẩn cấp để kíp trực 115 tiếp cận. Không theo dõi hành trình người dùng khi không cấp cứu.',
            ),
            _buildPrivacyTile(
              icon: Icons.camera_alt_rounded,
              color: const Color(0xFF0284C7),
              title: '2. Xử lý Camera AI (MoveNet)',
              desc: '100% xử lý trong RAM máy (On-device In-memory). Không ghi hình, không lưu ảnh ra bộ nhớ máy và tuyệt đối không gửi ảnh lên đám mây.',
            ),
            _buildPrivacyTile(
              icon: Icons.mic_rounded,
              color: const Color(0xFF7C3AED),
              title: '3. Giọng nói Khẩu lệnh (Vosk Offline)',
              desc: 'Nhận diện giọng nói cục bộ (On-device speech engine). Không thu âm cuộc trò chuyện, không truyền tải âm thanh ngoài mục đích nhận lệnh cấp cứu.',
            ),
            _buildPrivacyTile(
              icon: Icons.analytics_rounded,
              color: const Color(0xFF16A34A),
              title: '4. Chỉ số Ép tim (Telemetry Ẩn danh)',
              desc: 'Tần số ép tim (BPM) và chỉ số CCF được lưu trữ ẩn danh với mã UUID tạm thời nhằm hỗ trợ bác sĩ đánh giá chất lượng sơ cứu.',
            ),

            const SizedBox(height: 16),

            // Nút Xóa dữ liệu cục bộ (Nghị định 13 Quyền được lãng quên)
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
                      Expanded(
                        child: Text(
                          'Quyền Yêu cầu Xóa Dữ liệu (Right to be Forgotten)',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF991B1B)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Bạn có quyền xóa sạch toàn bộ lịch sử ca cấp cứu, hàng đợi Drift SQLite và nhật ký lưu trên thiết bị bất kỳ lúc nào.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF7F1D1D), height: 1.35),
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
                        final db = ref.read(databaseProvider);
                        await db.purgeAllLocalData();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              backgroundColor: Color(0xFF0F172A),
                              content: Text('✓ Đã xóa sạch toàn bộ dữ liệu nội bộ trên thiết bị!'),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.delete_forever_rounded, size: 20),
                      label: const Text('XÓA SẠCH DỮ LIỆU CỤC BỘ TRÊN MÁY'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacyTile({
    required IconData icon,
    required Color color,
    required String title,
    required String desc,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 3),
                Text(
                  desc,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
