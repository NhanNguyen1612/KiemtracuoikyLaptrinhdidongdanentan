import 'package:flutter_test/flutter_test.dart';
import 'package:resq_aid/core/services/gemma_local_llm_service.dart';
import 'package:resq_aid/core/services/medical_dialogue_brain.dart';
import 'package:resq_aid/core/services/voice_dialogue_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CẤP ĐỘ 4 — ON-DEVICE LLM GEMMA 2B Q4 TEST SUITE', () {
    late GemmaLocalLlmService gemmaService;
    late VoiceDialogueService voiceService;

    setUp(() {
      gemmaService = GemmaLocalLlmService();
      voiceService = VoiceDialogueService();
      MedicalDialogueBrain().reset();
    });

    test('1. Gemma Model Config: Kiểm tra thông số kỹ thuật mô hình On-Device Q4', () {
      final config = gemmaService.config;
      expect(config.modelName, equals('Gemma-2B-IT-Q4'));
      expect(config.quantization, contains('INT4'));
      expect(config.parameterCount, contains('2.5B'));
      expect(config.contextLength, equals(2048));
      expect(config.vocabularySize, equals(256000));
      expect(config.memoryFootprintMb, equals(1340));
      expect(config.runtimeBackend, contains('MediaPipe'));
    });

    test('2. Prompt Template: Chuẩn định dạng Gemma 2B Instruction Tuning', () {
      final prompt = gemmaService.formatPrompt(
        'Bị kiến ba khoang cắn thì làm sao?',
        conversationHistory: 'Bệnh nhân đang ở phòng khách',
      );

      expect(prompt, contains('<start_of_turn>system'));
      expect(prompt, contains('Bác sĩ Trợ lý Cấp cứu AI ResQ-Aid'));
      expect(prompt, contains('<start_of_turn>context'));
      expect(prompt, contains('Bệnh nhân đang ở phòng khách'));
      expect(prompt, contains('<start_of_turn>user'));
      expect(prompt, contains('Bị kiến ba khoang cắn thì làm sao?'));
      expect(prompt, contains('<start_of_turn>model'));
      expect(prompt, contains('<end_of_turn>'));
    });

    test('3. Medical Guardrails: Hàng rào an toàn loại bỏ mẹo dân gian nguy hại', () {
      expect(MedicalGuardrails.checkSafety('Rửa bằng nước muối sinh lý và bôi kem làm dịu da'), isTrue);
      expect(MedicalGuardrails.checkSafety('Hãy đắp phân bò và chích lể lấy máu độc'), isFalse);
      expect(MedicalGuardrails.checkSafety('Bôi kem đánh răng lên vết bỏng'), isFalse);
      expect(MedicalGuardrails.checkSafety('Nhét thìa vào miệng khi đang co giật'), isFalse);

      final sanitized = MedicalGuardrails.sanitizeResponse('Đắp phân bò lên vết thương');
      expect(sanitized, contains('[CẢNH BÁO Y TẾ]'));
    });

    test('4. On-Device LLM Synthesis: Câu hỏi mở về Kiến ba khoang', () {
      final response = gemmaService.generateSync('Bị kiến ba khoang cắn thì rửa bằng gì?');
      expect(response, contains('KIẾN BA KHOANG'));
      expect(response, contains('pederin'));
      expect(response, contains('nước muối sinh lý'));
      expect(response, contains('TUYỆT ĐỐI KHÔNG'));
    });

    test('5. On-Device LLM Synthesis: Dị ứng lông sâu róm', () {
      final response = gemmaService.generateSync('Bị lông sâu róm dính vào tay ngứa buốt quá');
      expect(response, contains('SÂU RÓM'));
      expect(response, contains('băng dính'));
      expect(response, contains('gai lông'));
      expect(response, contains('Chườm lạnh'));
    });

    test('6. On-Device LLM Synthesis: Say cà phê hồi hộp tim đập nhanh', () {
      final response = gemmaService.generateSync('Uống cà phê đậm đặc bị say tim đập thình thịch');
      expect(response, contains('SAY CÀ PHÊ'));
      expect(response, contains('nước lọc ấm'));
      expect(response, contains('hít thở'));
    });

    test('7. On-Device LLM Synthesis: Tụt huyết áp tư thế ở người già', () {
      final response = gemmaService.generateSync('Người già bị tụt huyết áp choáng váng');
      expect(response, contains('TỤT HUYẾT ÁP'));
      expect(response, contains('kê hai chân cao'));
      expect(response, contains('trà gừng'));
    });

    test('8. On-Device LLM Synthesis: Chuột rút bắp chân (vọp bẻ)', () {
      final response = gemmaService.generateSync('Bị chuột rút bắp chân đau quặn khi bơi');
      expect(response, contains('CHUỘT RÚT'));
      expect(response, contains('duỗi thẳng chân'));
      expect(response, contains('kéo ngược ngón chân'));
    });

    test('9. On-Device LLM Synthesis: Đau mắt hàn / bỏng tia cực tím', () {
      final response = gemmaService.generateSync('Thợ cơ khí bị đau mắt hàn cộm xốn chảy nước mắt');
      expect(response, contains('ĐAU MẮT HÀN'));
      expect(response, contains('nước muối sinh lý'));
      expect(response, contains('Chườm lạnh'));
    });

    test('10. On-Device LLM Synthesis: Zona thần kinh / Giời leo', () {
      final response = gemmaService.generateSync('Bị nổi mụn nước giời leo đau rát một bên sườn');
      expect(response, contains('ZONA'));
      expect(response, contains('Acyclovir'));
      expect(response, contains('TUYỆT ĐỐI KHÔNG nhai đỗ xanh'));
    });

    test('11. Future Async Generation: Đầy đủ đo lường độ trễ và số lượng token', () async {
      final result = await gemmaService.generate('Tư vấn chăm sóc sức khỏe mùa nắng nóng');
      expect(result.tokensGenerated, greaterThan(20));
      expect(result.latencyMs, greaterThan(0));
      expect(result.tokensPerSecond, greaterThan(0));
      expect(result.modelTag, equals('Gemma-2B-IT-Q4'));
      expect(result.safetyPassed, isTrue);
    });

    test('12. Streaming Tokens Generation: Stream nhả từng từ mô phỏng Voice Orb live', () async {
      final stream = gemmaService.generateStream('Say cà phê làm sao');
      final emittedWords = <String>[];
      await for (final word in stream) {
        emittedWords.add(word);
      }
      expect(emittedWords.length, greaterThan(10));
      expect(emittedWords.join(''), contains('SAY CÀ PHÊ'));
    });

    test('13. Tích hợp trọn vẹn vào VoiceDialogueService & MedicalDialogueBrain', () {
      // Khi gặp câu hỏi mở ngoài 65 chủ đề cứng -> Tự động kích hoạt Gemma 2B Local
      final answer = voiceService.resolveMedicalQuery('Bị kiến ba khoang đốt sưng rát da');
      expect(answer, contains('KIẾN BA KHOANG'));
      expect(answer, contains('pederin'));

      // Nhưng khi gặp câu hỏi cấp cứu chuyên khoa -> Vẫn giữ độ trễ siêu tốc của Cấp 1, 2, 3
      final cprAnswer = voiceService.resolveMedicalQuery('bep tim kieu gi');
      expect(cprAnswer, contains('110 BPM'));

      final strokeAnswer = voiceService.resolveMedicalQuery('người nhà bị méo miệng nói ngọng');
      expect(strokeAnswer, contains('F.A.S.T'));
    });
  });
}
