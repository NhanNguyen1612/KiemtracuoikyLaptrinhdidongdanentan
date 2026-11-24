import 'package:flutter/material.dart';
import '../../../core/ai/ai_model_manager_service.dart';
import '../../../core/ai/medical_neural_nlp_engine.dart';
import '../../../core/services/device_health_service.dart';

class AiModelManagerScreen extends StatefulWidget {
  const AiModelManagerScreen({super.key});

  @override
  State<AiModelManagerScreen> createState() => _AiModelManagerScreenState();
}

class _AiModelManagerScreenState extends State<AiModelManagerScreen> {
  DeviceMemoryProfile? _memProfile;
  double _batteryTempC = 36.5;
  int _protocolCount = 60;
  final Map<String, bool> _installedMap = {};
  final Map<String, double> _downloadProgress = {};
  String _testQuery = 'bạn tôi bị miếng sắt rỉ quẹt vào chân chảy máu';
  NeuralNlpPrediction? _liveBenchmark;

  @override
  void initState() {
    super.initState();
    _loadDiagnostics();
  }

  Future<void> _loadDiagnostics() async {
    final diag = await AiModelManagerService.instance.getRuntimeDiagnostics();
    final statusMap = <String, bool>{};
    for (final pack in AiModelManagerService.downloadablePacks) {
      statusMap[pack.id] = await AiModelManagerService.instance.isPackInstalled(pack);
    }
    final bench = MedicalNeuralNlpEngine.instance.infer(_testQuery);
    if (mounted) {
      setState(() {
        _memProfile = diag.memory;
        _batteryTempC = diag.batteryTempC;
        _protocolCount = diag.bundledProtocols;
        _installedMap.addAll(statusMap);
        _liveBenchmark = bench;
      });
    }
  }

  Future<void> _startDownload(LocalModelPackSpec spec) async {
    setState(() => _downloadProgress[spec.id] = 0.01);
    try {
      await for (final p in AiModelManagerService.instance.downloadPack(spec)) {
        if (!mounted) return;
        setState(() => _downloadProgress[spec.id] = p);
      }
      if (mounted) {
        setState(() {
          _downloadProgress.remove(spec.id);
          _installedMap[spec.id] = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã tải thành công mô hình ${spec.name}')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _downloadProgress.remove(spec.id));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể tải gói mở rộng (Kiểm tra Wi-Fi): $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mem = _memProfile;

    return Scaffold(
      backgroundColor: const Color(0xFF0B1120),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        title: const Text(
          'QUẢN LÝ MÔ HÌNH AI LOCAL',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. THÔNG SỐ PHẦN CỨNG ANDROID THỰC TẾ
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
                const Row(
                  children: [
                    Icon(Icons.memory_rounded, color: Color(0xFF38BDF8), size: 22),
                    SizedBox(width: 8),
                    Text(
                      'PHẦN CỨNG THIẾT BỊ & ĐỊNH CỠ NPU/CPU',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  mem != null
                      ? '• Bộ nhớ RAM: ${mem.availRamMb} MB trống / ${mem.totalRamMb} MB tổng (${mem.cpuCores} nhân CPU)\n'
                        '• Nhiệt độ pin hiện tại: ${_batteryTempC.toStringAsFixed(1)} °C\n'
                        '• Đề xuất tự động: ${mem.recommendedModel}'
                      : 'Đang đọc cảm biến phần cứng Android...',
                  style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12.5, height: 1.5),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 2. CÁC MẠNG NƠ-RON NHÚNG SẴN TRONG APK (HOẠT ĐỘNG NGAY 100% OFFLINE)
          const Text(
            'MẠNG NƠ-RON NHÚNG SẴN (ACTIVE ON-DEVICE)',
            style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w800, fontSize: 11.5),
          ),
          const SizedBox(height: 8),
          _buildBundledModelTile(
            title: 'TraumaVisionNet Multi-Task CNN',
            subtitle: 'TFLite v3 FlatBuffer (1.34 MB) • 12 nhóm chấn thương + Auto-ROI + Quality Gate',
            badge: 'ACTIVE • GPU/XNNPACK',
          ),
          const SizedBox(height: 8),
          _buildBundledModelTile(
            title: 'MedicalNlpNet 128D Bi-Encoder + Vector RAG',
            subtitle: 'Conv1D Sequence + $_protocolCount Vector Phác đồ Bộ Y Tế & AHA 2025 (1.12 MB)',
            badge: 'ACTIVE • < 1ms',
          ),

          const SizedBox(height: 16),

          // 3. KIỂM ĐỊNH VECTOR & ENTROPY TRỰC TIẾP TRÊN MÁY
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'KIỂM TRA SUY LUẬN TENSOR TRỰC TIẾP (ZERO IF-ELSE)',
                  style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w800, fontSize: 12),
                ),
                const SizedBox(height: 8),
                TextField(
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Nhập câu hỏi sơ cứu bất kỳ để xem Vector Cosine...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.play_arrow_rounded, color: Color(0xFF10B981)),
                      onPressed: () {
                        setState(() {
                          _liveBenchmark = MedicalNeuralNlpEngine.instance.infer(_testQuery);
                        });
                      },
                    ),
                  ),
                  onChanged: (v) {
                    _testQuery = v;
                    if (v.trim().isNotEmpty) {
                      setState(() {
                        _liveBenchmark = MedicalNeuralNlpEngine.instance.infer(v);
                      });
                    }
                  },
                ),
                if (_liveBenchmark != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    '• Node Vector RAG: ${_liveBenchmark!.topProtocol.id}\n'
                    '• Cosine Similarity: ${_liveBenchmark!.topCosineSimilarity.toStringAsFixed(4)} | Xác suất: ${(_liveBenchmark!.topDocProbability * 100).toStringAsFixed(1)}%\n'
                    '• Predictive Entropy H(p): ${_liveBenchmark!.docEntropy.toStringAsFixed(4)} | Thời gian: ${_liveBenchmark!.latencyUs} µs',
                    style: const TextStyle(color: Colors.white70, fontSize: 11.5, fontFamily: 'monospace', height: 1.45),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 18),

          // 4. GÓI MỞ RỘNG LOCAL LLM GGUF (TẢI 1 LẦN VỀ BỘ NHỚ MÁY)
          const Text(
            'GÓI MỞ RỘNG LOCAL LLM GGUF (TÙY CHỌN TẢI VỀ BỘ NHỚ MÁY)',
            style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w800, fontSize: 11.5),
          ),
          const SizedBox(height: 8),
          for (final pack in AiModelManagerService.downloadablePacks) ...[
            _buildDownloadablePackCard(pack),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _buildBundledModelTile({
    required String title,
    required String subtitle,
    required String badge,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13.5)),
                const SizedBox(height: 3),
                Text(subtitle, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.18),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              badge,
              style: const TextStyle(color: Color(0xFF34D399), fontWeight: FontWeight.w900, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadablePackCard(LocalModelPackSpec pack) {
    final isInstalled = _installedMap[pack.id] == true;
    final progress = _downloadProgress[pack.id];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  pack.name,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13.5),
                ),
              ),
              Text(
                '${pack.sizeMb} MB • ${pack.quantization}',
                style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(pack.description, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5)),
          const SizedBox(height: 10),
          if (progress != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(value: progress, color: const Color(0xFF38BDF8)),
                const SizedBox(height: 4),
                Text(
                  'Đang tải về bộ nhớ thiết bị: ${(progress * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isInstalled)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
                    onPressed: () async {
                      await AiModelManagerService.instance.deletePack(pack);
                      setState(() => _installedMap[pack.id] = false);
                    },
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('Gỡ gói', style: TextStyle(fontSize: 12)),
                  )
                else
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => _startDownload(pack),
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: const Text('Tải GGUF về máy', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
