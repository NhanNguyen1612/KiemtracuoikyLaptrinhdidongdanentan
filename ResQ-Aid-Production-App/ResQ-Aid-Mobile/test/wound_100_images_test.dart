import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:resq_aid/core/services/tflite_vision_service.dart';
import 'package:resq_aid/core/services/wound_classifier_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('KIỂM THỬ NGOẠI KHOA & THỊ GIÁC AI TRÊN 1,200 ẢNH THỰC TẾ (100 ẢNH / TRƯỜNG HỢP)', () {
    late TfliteVisionService visionService;
    late Map<String, dynamic> manifest;

    setUpAll(() async {
      visionService = TfliteVisionService();
      await visionService.initialize();

      final manifestFile = File('test/wound_dataset_100/manifest.json');
      expect(manifestFile.existsSync(), isTrue, reason: 'Manifest file phải tồn tại');
      final content = await manifestFile.readAsString();
      manifest = jsonDecode(content) as Map<String, dynamic>;
      expect(manifest.length, equals(1200), reason: 'Phải kiểm thử chính xác 1,200 ảnh');
    });

    test('Toàn bộ 1,200 ảnh chấn thương và ngoại khoa thực tế (12 nhóm x 100) phải đạt 100% PASS', () async {
      int passedCount = 0;
      final totalImages = manifest.length;
      final failedList = <String>[];
      final categoryStats = <String, Map<String, int>>{};

      for (final entry in manifest.entries) {
        final fileName = entry.key;
        final expectedClass = entry.value as String;

        categoryStats.putIfAbsent(expectedClass, () => {'total': 0, 'passed': 0});
        categoryStats[expectedClass]!['total'] = categoryStats[expectedClass]!['total']! + 1;

        final imageFile = File('test/wound_dataset_100/$fileName');
        expect(imageFile.existsSync(), isTrue, reason: 'Tệp $fileName phải tồn tại trên đĩa');

        final bytes = await imageFile.readAsBytes();
        final result = await visionService.classifyTrauma(rawImageBytes: bytes);
        final label = result.label;

        bool isCorrect = false;
        switch (expectedClass) {
          case 'fracture':
            isCorrect = label.contains('Gãy xương') || label.contains('Trật khớp') || label.contains('Biến dạng chi');
            break;
          case 'cut':
            isCorrect = label.contains('Vết đứt tay') || label.contains('Rách da');
            break;
          case 'arterial':
            isCorrect = label.contains('động mạch') || label.contains('chảy máu ồ ạt');
            break;
          case 'deep_wound':
            isCorrect = label.contains('hở sâu') || label.contains('Toác mép');
            break;
          case 'abrasion':
            isCorrect = label.contains('Trầy xước') || label.contains('bình thường');
            break;
          case 'burn_d2':
            isCorrect = label.contains('nước sôi') || label.contains('Độ 2');
            break;
          case 'burn_d3':
            isCorrect = label.contains('hoại tử') || label.contains('Độ 3');
            break;
          case 'tetanus':
            isCorrect = label.contains('rỉ sét') || label.contains('Giẫm đinh') || label.contains('uốn ván');
            break;
          case 'animal_bite':
            isCorrect = label.contains('chó cắn') || label.contains('Động vật cào') || label.contains('bệnh dại');
            break;
          case 'bruise':
            isCorrect = label.contains('Bầm tím') || label.contains('Sưng tấy') || label.contains('Viêm mô');
            break;
          case 'clean_skin':
            isCorrect = label.contains('lành lặn') || label.contains('Không có vết thương');
            break;
          case 'object':
            isCorrect = label.contains('Không phát hiện') || label.contains('Đồ vật');
            break;
        }

        if (isCorrect) {
          passedCount++;
          categoryStats[expectedClass]!['passed'] = categoryStats[expectedClass]!['passed']! + 1;
        } else {
          failedList.add('$fileName [Kỳ vọng: $expectedClass, Thực tế: $label]');
        }
      }

      print('\n======================================================================');
      print('BÁO CÁO KIỂM THỬ THỊ GIÁC AI VISION TRÊN TOÀN BỘ 1,200 ẢNH Y KHOA:');
      print('TỔNG SỐ ẢNH ĐÃ KIỂM THỬ: $totalImages');
      print('SỐ ẢNH ĐẠT CHUẨN XÁC: $passedCount / $totalImages (${(passedCount / totalImages * 100).toStringAsFixed(2)}%)');
      print('----------------------------------------------------------------------');
      categoryStats.forEach((cat, stat) {
        final tot = stat['total']!;
        final pas = stat['passed']!;
        final pct = (pas / tot * 100).toStringAsFixed(1);
        print('  • Nhóm ${cat.padRight(14)}: $pas / $tot ($pct%)');
      });
      print('----------------------------------------------------------------------');
      if (failedList.isNotEmpty) {
        print('CÁC CA KHÔNG ĐẠT:');
        for (final fail in failedList) {
          print('  - $fail');
        }
      } else {
        print('XUẤT SẮC: 100% TẤT CẢ 1,200/1,200 ẢNH ĐỀU PASS HOÀN TOÀN!');
      }
      print('======================================================================\n');

      expect(failedList, isEmpty, reason: 'Tất cả 1,200 ảnh chấn thương phải nhận diện chính xác 100%');
      expect(passedCount, equals(totalImages));
    }, timeout: const Timeout(Duration(seconds: 90)));

    test('Ảnh 1 Người dùng: Người lành lặn mặc áo đen nhận diện đúng DA LÀNH LẶN (Không nhầm Bỏng độ 3)', () async {
      final userFile = File('test/wound_dataset_100/user_healthy_person.jpg');
      expect(userFile.existsSync(), isTrue);

      final bytes = await userFile.readAsBytes();
      final result = await visionService.classifyTrauma(rawImageBytes: bytes);

      expect(result.label, contains('lành lặn'));
      expect(result.label, isNot(contains('Bỏng')));
      print('Ảnh 1 Người lành lặn: ${result.label} (Độ tin cậy: ${(result.confidence * 100).toStringAsFixed(1)}%)');
    });

    test('Ảnh 2 Người dùng: Ngón tay gãy biến dạng góc nhận diện đúng GÃY XƯƠNG / TRẬT KHỚP & Bật Auto-ROI + Triage 1-chạm', () async {
      final userFile = File('test/wound_dataset_100/user_fracture_finger.jpg');
      expect(userFile.existsSync(), isTrue);

      final bytes = await userFile.readAsBytes();
      final result = await visionService.classifyTrauma(rawImageBytes: bytes);

      expect(result.label, contains('Gãy xương'));
      expect(result.label, contains('Trật khớp ngón tay'));
      expect(result.woundRoi, isNotNull, reason: 'Auto-ROI phải trích xuất được Bounding Box');
      expect(result.needsClarification, isTrue, reason: 'Phải bật tính năng hỏi xác minh lâm sàng 1-chạm');
      expect(result.clarificationOptions, isNotEmpty);
      print('Ảnh 2 Ngón tay gãy (ảnh gốc): ${result.label} (Độ tin cậy: ${(result.confidence * 100).toStringAsFixed(1)}%)');
      print('  • Auto-ROI Bounding Box: ${result.woundRoi}');
      print('  • Câu hỏi lâm sàng 1 chạm: ${result.clarificationQuestion}');
    });

    test('Ảnh 2 Người dùng (Chụp lại lúc 9:15): Ngón tay gãy nhận diện đúng GÃY XƯƠNG / TRẬT KHỚP', () async {
      final userFile = File('test/wound_dataset_100/user_fracture_finger_915.jpg');
      expect(userFile.existsSync(), isTrue);

      final bytes = await userFile.readAsBytes();
      final result = await visionService.classifyTrauma(rawImageBytes: bytes);

      expect(result.label, contains('Gãy xương'));
      expect(result.label, contains('Trật khớp ngón tay'));
      print('Ảnh 2 Ngón tay gãy (ảnh 9:15): ${result.label} (Độ tin cậy: ${(result.confidence * 100).toStringAsFixed(1)}%)');
    });

    test('Ảnh 3 Người dùng: Đầu gối trầy xước rớm máu nhận diện đúng TRẦY XƯỚC (Không nhầm Bỏng độ 3)', () async {
      final userFile = File('test/wound_dataset_100/user_knee_scrape.jpg');
      expect(userFile.existsSync(), isTrue);

      final bytes = await userFile.readAsBytes();
      final result = await visionService.classifyTrauma(rawImageBytes: bytes);

      expect(result.label, contains('Trầy xước'));
      expect(result.label, isNot(contains('Bỏng')));
      print('Ảnh 3 Đầu gối trầy xước: ${result.label} (Độ tin cậy: ${(result.confidence * 100).toStringAsFixed(1)}%)');
    });

    test('Ảnh 4 Người dùng: Đòn roi tụ máu thâm tím nhận diện đúng BẦM TÍM TỤ MÁU (Không nhầm Da lành)', () async {
      final userFile = File('test/wound_dataset_100/user_bruise_hematoma.jpg');
      expect(userFile.existsSync(), isTrue);

      final bytes = await userFile.readAsBytes();
      final result = await visionService.classifyTrauma(rawImageBytes: bytes);
      print('Ảnh 4 Result: ${result.label}');

      expect(result.label, contains('Bầm tím'));
      print('Ảnh 4 Đòn roi thâm tím: ${result.label} (Độ tin cậy: ${(result.confidence * 100).toStringAsFixed(1)}%)');
    });

    test('Ảnh 5 Người dùng (10:18): Bàn tay giơ ngón giữa lành lặn nhận diện đúng DA LÀNH LẶN (Không nhầm Gãy xương)', () async {
      final userFile = File('test/wound_dataset_100/user_middle_finger_1018.jpg');
      expect(userFile.existsSync(), isTrue);

      final bytes = await userFile.readAsBytes();
      final result = await visionService.classifyTrauma(rawImageBytes: bytes);

      expect(result.label, contains('lành lặn'));
      expect(result.label, isNot(contains('Gãy xương')));
      print('Ảnh 5 Ngón giữa lành lặn: ${result.label} (Độ tin cậy: ${(result.confidence * 100).toStringAsFixed(1)}%)');
    });

    test('Ảnh 6 Người dùng (10:18): Ngón tay gãy/trật khớp ngang 90 độ nhận diện đúng GÃY XƯƠNG / TRẬT KHỚP', () async {
      final userFile = File('test/wound_dataset_100/user_fracture_finger_1018.jpg');
      expect(userFile.existsSync(), isTrue);

      final bytes = await userFile.readAsBytes();
      final result = await visionService.classifyTrauma(rawImageBytes: bytes);

      expect(result.label, contains('Gãy xương'));
      expect(result.label, contains('Trật khớp ngón tay'));
      print('Ảnh 6 Ngón tay gãy 10:18: ${result.label} (Độ tin cậy: ${(result.confidence * 100).toStringAsFixed(1)}%)');
    });

    test('Ảnh 7 Người dùng (12:16): Cùi chỏ trầy xước rớm máu nhận diện đúng TRẦY XƯỚC (Không nhầm Da lành lặn)', () async {
      final userFile = File('test/wound_dataset_100/user_abrasion_elbow.jpg');
      expect(userFile.existsSync(), isTrue);

      final bytes = await userFile.readAsBytes();
      final result = await visionService.classifyTrauma(rawImageBytes: bytes);

      expect(result.label, contains('Trầy xước'));
      expect(result.label, isNot(contains('lành lặn')));
      expect(result.triagePriority, equals(ClinicalTriagePriority.p3NonUrgent));
      print('Ảnh 7 Cùi chỏ trầy xước: ${result.label} (Độ tin cậy: ${(result.confidence * 100).toStringAsFixed(1)}%)');
      print('  • Hành động lâm sàng: ${result.actionTitle}');
    });

    test('Ảnh 8 Người dùng (15:59): Hai đầu gối chụp xa - khi kéo khung ngắm vào đầu gối trầy xước nhận diện đúng TRẦY XƯỚC (P3)', () async {
      final userFile = File('test/wound_dataset_100/user_two_knees_1559.jpg');
      expect(userFile.existsSync(), isTrue);

      final bytes = await userFile.readAsBytes();
      
      // 1. Khi chưa kéo khung ngắm (mặc định ở giữa 2 chân và da lành) -> Da lành lặn / Không có thương tích
      final defaultResult = await visionService.classifyTrauma(rawImageBytes: bytes);
      expect(defaultResult.label, contains('lành lặn'));
      print('Ảnh 8 khi chưa kéo khung ngắm: ${defaultResult.label}');

      // 2. Khi người dùng kéo khung ngắm trúng đầu gối phải bị trầy rớm máu
      final croppedResult = await visionService.classifyTrauma(
        rawImageBytes: bytes,
        cropRoi: Rect.fromLTWH(0.55, 0.28, 0.38, 0.26),
      );
      print('croppedResult: label="${croppedResult.label}", triage=${croppedResult.triagePriority}, isNonTrauma=${croppedResult.isNonTraumaObject}');
      expect(croppedResult.label, contains('Trầy xước'));
      expect(croppedResult.triagePriority, equals(ClinicalTriagePriority.p3NonUrgent));
      print('Ảnh 8 sau khi KÉO KHUNG NGẮM vào gối phải: ${croppedResult.label} (Độ tin cậy: ${(croppedResult.confidence * 100).toStringAsFixed(1)}%)');
      print('  • Hành động lâm sàng: ${croppedResult.actionTitle}');
    });

    test('CHIẾN LƯỢC CLAUDE (PHƯƠNG ÁN 1): Bộ phân xử an toàn fuse() CHỈ ĐƯỢC LEO THANG, KHÔNG BAO GIỜ HẠ CẤP', () {
      const baseResult = TfliteInferenceResult(
        label: 'Tổn thương da bình thường / Trầy xước nhẹ',
        confidence: 0.965,
        latencyMs: 30,
        modelName: 'MobileNetV3',
        runtimeEngine: 'TFLite',
        isRealNeuralNetwork: true,
        isNonTraumaObject: false,
        triagePriority: ClinicalTriagePriority.p3NonUrgent,
        guardrailStatus: 'P3 KHÔNG KHẨN CẤP',
        safetyChecklist: ['Rửa nước muối sinh lý'],
      );

      // 1. Leo thang khi có cờ P0 (Chảy máu không cầm)
      final p0Fused = TfliteVisionService.fuse(
        currentResult: baseResult,
        activeRedFlagIds: ['bleeding_10m'],
      );
      expect(p0Fused.triagePriority, equals(ClinicalTriagePriority.p0Catastrophic));
      expect(p0Fused.label, contains('chảy máu ồ ạt'));
      expect(p0Fused.guardrailStatus, contains('RED-FLAG LÂM SÀNG'));

      // 2. Leo thang khi có cờ P1 (Biến dạng khớp / Gãy xương)
      final p1Fused = TfliteVisionService.fuse(
        currentResult: baseResult,
        activeRedFlagIds: ['deformity_immobility'],
      );
      expect(p1Fused.triagePriority, equals(ClinicalTriagePriority.p1Urgent));
      expect(p1Fused.label, contains('Gãy xương'));

      // 3. Nguyên tắc bất đối xứng: Cờ P1 KHÔNG BAO GIỜ được phép hạ cấp một ca đang là P0!
      final p0Initial = TfliteInferenceResult(
        label: 'Vết rách đứt động mạch',
        confidence: 0.99,
        latencyMs: 25,
        modelName: 'MobileNetV3',
        runtimeEngine: 'TFLite',
        isRealNeuralNetwork: true,
        isNonTraumaObject: false,
        triagePriority: ClinicalTriagePriority.p0Catastrophic,
        guardrailStatus: 'P0 CẤP CỨU HỒI SỨC',
        safetyChecklist: const ['Garo chẹn động mạch'],
      );
      final p0Protected = TfliteVisionService.fuse(
        currentResult: p0Initial,
        activeRedFlagIds: ['deformity_immobility'], // cờ P1
      );
      // Vẫn phải là P0, không được bị hạ cấp xuống P1!
      expect(p0Protected.triagePriority, equals(ClinicalTriagePriority.p0Catastrophic));

      // 4. Khi bỏ chọn toàn bộ cờ, trả về kết quả ban đầu
      final unchanged = TfliteVisionService.fuse(
        currentResult: baseResult,
        activeRedFlagIds: [],
      );
      expect(unchanged.triagePriority, equals(baseResult.triagePriority));
      expect(unchanged.label, equals(baseResult.label));
    });

    test('CHIẾN LƯỢC CLAUDE (PHƯƠNG ÁN 1): Chuyển đổi màu CIELab chuẩn xác để đo màu tương đối ΔE', () {
      final labWhite = List<double>.filled(3, 0.0);
      TfliteVisionService.rgbToLab(255, 255, 255, labWhite);
      expect(labWhite[0], closeTo(100.0, 1.0)); // L của trắng gần 100

      final labBlack = List<double>.filled(3, 0.0);
      TfliteVisionService.rgbToLab(0, 0, 0, labBlack);
      expect(labBlack[0], closeTo(0.0, 1.0)); // L của đen gần 0

      final labRed = List<double>.filled(3, 0.0);
      TfliteVisionService.rgbToLab(255, 0, 0, labRed);
      expect(labRed[1], greaterThan(50.0)); // a* của đỏ dương rất cao
    });

    test('CHIẾN LƯỢC CLAUDE (GIAI ĐOẠN 2): Kiểm thử Interface WoundClassifier & Action-oriented Triage Classes', () async {
      // 1. Kiểm thử Interface WoundClassifier đa hình
      final WoundClassifier classifier = visionService;
      final userFile = File('test/wound_dataset_100/user_fracture_finger_1018.jpg');
      final bytes = await userFile.readAsBytes();

      final result = await classifier.classify(
        TraumaClassificationInput(rawImageBytes: bytes),
      );

      expect(result.label, contains('Gãy xương'));
      expect(result.actionClass, equals(TraumaActionClass.urgentHospital));
      expect(result.actionTitle, contains('SƠ CỨU KHẨN & ĐẾN TRUNG TÂM CHẤN THƯƠNG'));

      // 2. Kiểm thử chuyển đổi 4 Bậc hành động lâm sàng
      expect(ClinicalTriagePriority.p0Catastrophic.toActionClass(), equals(TraumaActionClass.immediate115));
      expect(ClinicalTriagePriority.p1Urgent.toActionClass(), equals(TraumaActionClass.urgentHospital));
      expect(ClinicalTriagePriority.p2SemiUrgent.toActionClass(), equals(TraumaActionClass.semiUrgentClinic));
      expect(ClinicalTriagePriority.p3NonUrgent.toActionClass(), equals(TraumaActionClass.homeCareSafe));
      expect(ClinicalTriagePriority.p4Normal.toActionClass(), equals(TraumaActionClass.homeCareSafe));

      // 3. Kiểm thử toán tử Sobel Gradient Edge
      final flatLuma = List<double>.filled(64 * 64, 128.0);
      final flatEdges = TfliteVisionService.computeSobelEdges(flatLuma, 64, 64);
      expect(flatEdges['meanGrad'], equals(0.0));
      expect(flatEdges['sharpEdgeCount'], equals(0.0));

      // Tạo ma trận có mép rách toác dốc đứng (Step edge)
      final stepLuma = List<double>.filled(64 * 64, 0.0);
      for (int y = 0; y < 64; y++) {
        for (int x = 32; x < 64; x++) {
          stepLuma[y * 64 + x] = 255.0;
        }
      }
      final stepEdges = TfliteVisionService.computeSobelEdges(stepLuma, 64, 64);
      expect(stepEdges['maxGrad']!, greaterThan(200.0));
      expect(stepEdges['sharpEdgeCount']!, greaterThan(50.0));

      // 4. Kiểm thử phát hiện phản xạ bọng nước Specular Highlight
      final rList = List<int>.filled(64 * 64, 100);
      final gList = List<int>.filled(64 * 64, 100);
      final bList = List<int>.filled(64 * 64, 100);
      // Tạo điểm bọng nước phản xạ sáng chói (V=255, Sat=0)
      for (int i = 0; i < 10; i++) {
        rList[i] = 255;
        gList[i] = 255;
        bList[i] = 255;
      }
      final highlights = TfliteVisionService.countSpecularHighlights(rList, gList, bList, 64 * 64);
      expect(highlights, equals(10));
    });
  });
}
