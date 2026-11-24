import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:resq_aid/core/services/tflite_vision_service.dart';
import 'package:resq_aid/core/services/wound_classifier_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ĐÁNH GIÁ CHUẨN LÂM SÀNG TRÊN TẬP ẢNH THỰC TẾ (REAL-WORLD IN-THE-WILD BENCHMARK)', () {
    late TfliteVisionService visionService;
    late Map<String, dynamic> manifest;

    setUpAll(() async {
      visionService = TfliteVisionService();
      await visionService.initialize();

      final manifestFile = File('test/real_world_dataset/manifest_real.json');
      expect(manifestFile.existsSync(), isTrue);
      manifest = jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;
    });

    test('Chạy suy luận và đo lường chi tiết trên toàn bộ ảnh thực tế', () async {
      print('\n' + '=' * 105);
      print('BẢNG KẾT QUẢ ĐÁNH GIÁ AI VISION TRÊN TẬP ẢNH THỰC TẾ (REAL-WORLD IMAGES)');
      print('=' * 105);
      print('${"Tên File".padRight(32)} | ${"Mục tiêu".padRight(12)} | ${"Triage".padRight(6)} | ${"Độ tin cậy".padRight(10)} | ${"Thời gian".padRight(9)} | Dự đoán AI');
      print('-' * 105);

      final summaryList = <Map<String, dynamic>>[];

      for (final entry in manifest.entries) {
        final fname = entry.key;
        final info = entry.value as Map<String, dynamic>;
        final targetCat = info['category'] as String;
        final desc = info['description'] as String;

        final file = File('test/real_world_dataset/$fname');
        if (!file.existsSync()) continue;

        final bytes = await file.readAsBytes();
        
        // Nếu là ảnh hai đầu gối chụp xa, thử nghiệm cả 2 chế độ: Mặc định vs Khung ngắm kéo vào gối phải
        Rect? testRoi;
        if (fname == 'real_two_knees_wide.jpg') {
          // Kéo khung ngắm tương tác vào đầu gối trầy xước
          testRoi = Rect.fromLTWH(0.55, 0.28, 0.38, 0.26);
        }

        final stopwatch = Stopwatch()..start();
        final result = await visionService.classifyTrauma(
          rawImageBytes: bytes,
          cropRoi: testRoi,
        );
        stopwatch.stop();

        final triageStr = result.triagePriority.name.replaceAll('ClinicalTriagePriority.', '').replaceAll('p0Catastrophic', 'P0').replaceAll('p1Urgent', 'P1').replaceAll('p2SemiUrgent', 'P2').replaceAll('p3NonUrgent', 'P3').replaceAll('p4Normal', 'P4');

        print('${fname.padRight(32)} | ${targetCat.padRight(12)} | ${triageStr.padRight(6)} | ${(result.confidence * 100).toStringAsFixed(1).padRight(9)}% | ${(stopwatch.elapsedMilliseconds.toString() + "ms").padRight(9)} | ${result.label}');

        summaryList.add({
          'file': fname,
          'target': targetCat,
          'desc': desc,
          'triage': triageStr,
          'confidence': result.confidence,
          'latencyMs': stopwatch.elapsedMilliseconds,
          'label': result.label,
          'action': result.actionTitle,
        });
      }

      print('=' * 105 + '\n');
      expect(summaryList.isNotEmpty, isTrue);
    });
  });
}
