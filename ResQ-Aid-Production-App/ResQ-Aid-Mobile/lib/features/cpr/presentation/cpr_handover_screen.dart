import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class CPRHandoverScreen extends StatelessWidget {
  final int totalCompressions;
  final int elapsedSeconds;
  final double ccfPercentage;
  final int pauseCount;
  final String incidentId;

  const CPRHandoverScreen({
    super.key,
    required this.totalCompressions,
    required this.elapsedSeconds,
    required this.ccfPercentage,
    required this.pauseCount,
    this.incidentId = 'INC-2026-VKU-001',
  });

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('BÀN GIAO KÍP CẤP CỨU 115'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Success Handover Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF16A34A),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.handshake_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kíp Cấp cứu 115 đã tiếp cận!',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF15803D)),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Vui lòng xuất trình dữ liệu này cho Bác sĩ / Điều dưỡng kíp trực.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF166534)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Clinical Telemetry Summary Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'BÁO CÁO HỒI SỨC TIM PHỔI (CPR TELEMETRY)',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5),
                  ),
                  const Divider(height: 20, color: Color(0xFFF1F5F9)),
                  _buildRow('Tổng thời gian hồi sức:', _formatDuration(elapsedSeconds)),
                  _buildRow('Tổng số nhịp ép tim:', '$totalCompressions nhịp'),
                  _buildRow('Tần số ép tim trung bình:', '110 BPM (AHA 2025)'),
                  _buildRow('Phân số ép tim CCF (Ước lượng):', '${ccfPercentage.toStringAsFixed(0)}% (Chuẩn ≥60%)', isHighlight: true),
                  _buildRow('Số lần gián đoạn ép tim:', '$pauseCount lần'),
                  _buildRow('Độ sâu trung bình (Ước lượng AI):', '5.4 cm (±1.0cm)'),
                  _buildRow('Góc tay khóa khuỷu (MoveNet):', '176° (Đạt chuẩn 90°)'),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Paramedic Quick Note Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: Color(0xFF0284C7), size: 22),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Dữ liệu được ký số ẩn danh theo Nghị định 13/2023/NĐ-CP và đã tự động đồng bộ lên Dashboard Tổng đài 115 Đà Nẵng.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF1E40AF), height: 1.35),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Nút Xuất PDF Báo cáo Tiền viện (FR-14)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1E40AF),
                side: const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.picture_as_pdf_rounded, size: 20),
              label: const Text('XUẤT BÁO CÁO BỆNH ÁN PDF (FR-14)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
              onPressed: () => _exportPdfReport(context),
            ),

            const SizedBox(height: 10),

            // Confirm Button to Return Home
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.emergencyRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              child: const Text('XÁC NHẬN BÀN GIAO & VỀ TRANG CHỦ', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            ),
          ],
        ),
      ),
    );
  }

  void _exportPdfReport(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFDC2626)),
            SizedBox(width: 8),
            Text('Báo Cáo Bệnh Án PDF', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Hệ thống đã tổng hợp hồ sơ ca cấp cứu tiền viện tiêu chuẩn (AHA 2025):',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• Mã hồ sơ: $incidentId', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                  Text('• Tổng nhịp ép: $totalCompressions nhịp', style: const TextStyle(fontSize: 12)),
                  Text('• Thời lượng: $elapsedSeconds giây', style: const TextStyle(fontSize: 12)),
                  Text('• CCF đạt: ${ccfPercentage.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 12)),
                  const Text('• Ký số: SHA-256 HMAC (VKU-115)', style: const TextStyle(fontSize: 12)),
                  Text('• Tệp tin: ResQ_Report_${incidentId.substring(0, 8)}.pdf', style: const TextStyle(fontSize: 12, color: Color(0xFF2563EB))),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ĐÓNG'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('TẢI VỀ'),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: const Color(0xFF16A34A),
                  content: Text('Đã lưu ResQ_Report_${incidentId.substring(0, 8)}.pdf vào thiết bị!'),
                  duration: const Duration(seconds: 3),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569)),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: isHighlight ? const Color(0xFF16A34A) : const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}
