import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../services/device_health_service.dart';
import 'medical_neural_nlp_engine.dart';

class LocalModelPackSpec {
  final String id;
  final String name;
  final String family;
  final String quantization;
  final int sizeMb;
  final int minRamMb;
  final String fileName;
  final String downloadUrl;
  final String description;

  const LocalModelPackSpec({
    required this.id,
    required this.name,
    required this.family,
    required this.quantization,
    required this.sizeMb,
    required this.minRamMb,
    required this.fileName,
    required this.downloadUrl,
    required this.description,
  });
}

/// Quản lý các mô hình AI On-Device (Cả mô hình nhúng sẵn trong APK và gói GGUF mở rộng tải về bộ nhớ máy)
class AiModelManagerService {
  static final AiModelManagerService instance = AiModelManagerService._();
  AiModelManagerService._();

  static const List<LocalModelPackSpec> downloadablePacks = [
    LocalModelPackSpec(
      id: 'qwen25_05b_q4',
      name: 'Qwen2.5-0.5B-Instruct (Siêu nhẹ)',
      family: 'GGUF Local LLM • Tiếng Việt',
      quantization: 'Q4_K_M (INT4)',
      sizeMb: 398,
      minRamMb: 3072,
      fileName: 'qwen2.5-0.5b-instruct-q4_k_m.gguf',
      downloadUrl:
          'https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf',
      description: 'Tối ưu cho máy Android RAM 3GB - 4GB, tốc độ sinh từ ~32 tokens/giây.',
    ),
    LocalModelPackSpec(
      id: 'qwen25_15b_q4',
      name: 'Qwen2.5-1.5B-Instruct (Chuẩn Y khoa)',
      family: 'GGUF Local LLM • Tiếng Việt',
      quantization: 'Q4_K_M (INT4)',
      sizeMb: 986,
      minRamMb: 5500,
      fileName: 'qwen2.5-1.5b-instruct-q4_k_m.gguf',
      downloadUrl:
          'https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf',
      description: 'Khuyên dùng cho máy Android RAM ≥ 6GB, lập luận tiếng Việt sâu kết hợp Vector RAG.',
    ),
  ];

  Future<Directory> _getModelsDir() async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory('${support.path}/local_ai_models');
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<bool> isPackInstalled(LocalModelPackSpec spec) async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) return false;
    try {
      final dir = await _getModelsDir();
      final f = File('${dir.path}/${spec.fileName}');
      return f.existsSync() && f.lengthSync() > 1024 * 1024;
    } catch (_) {
      return false;
    }
  }

  Future<void> deletePack(LocalModelPackSpec spec) async {
    final dir = await _getModelsDir();
    final f = File('${dir.path}/${spec.fileName}');
    if (f.existsSync()) {
      await f.delete();
    }
  }

  /// Tải gói trọng số GGUF trực tiếp về thư mục ứng dụng có theo dõi phần trăm tiến trình
  Stream<double> downloadPack(LocalModelPackSpec spec) async* {
    final dir = await _getModelsDir();
    final targetFile = File('${dir.path}/${spec.fileName}');
    final tempFile = File('${dir.path}/${spec.fileName}.part');

    final client = HttpClient();
    try {
      final req = await client.getUrl(Uri.parse(spec.downloadUrl));
      final resp = await req.close();
      if (resp.statusCode >= 400) {
        throw HttpException('HTTP ${resp.statusCode} khi tải mô hình ${spec.name}');
      }

      final totalBytes = resp.contentLength > 0 ? resp.contentLength : spec.sizeMb * 1024 * 1024;
      int received = 0;
      final sink = tempFile.openWrite();

      await for (final chunk in resp) {
        sink.add(chunk);
        received += chunk.length;
        yield (received / totalBytes).clamp(0.0, 0.99);
      }
      await sink.flush();
      await sink.close();

      if (targetFile.existsSync()) {
        await targetFile.delete();
      }
      await tempFile.rename(targetFile.path);
      yield 1.0;
    } finally {
      client.close(force: true);
    }
  }

  Future<({DeviceMemoryProfile memory, int bundledProtocols, double batteryTempC})> getRuntimeDiagnostics() async {
    final mem = await DeviceHealthService.getMemoryProfile();
    final temp = await DeviceHealthService.getBatteryTemperatureC();
    MedicalNeuralNlpEngine.instance.ensureInitializedSync();
    return (
      memory: mem,
      bundledProtocols: MedicalNeuralNlpEngine.instance.protocolCount,
      batteryTempC: temp,
    );
  }
}
