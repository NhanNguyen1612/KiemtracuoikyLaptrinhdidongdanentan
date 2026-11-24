import 'package:flutter_test/flutter_test.dart';
import 'package:resq_aid/core/services/medical_dialogue_brain.dart';
import 'package:resq_aid/core/services/voice_dialogue_service.dart';

void main() {
  group('CẤP ĐỘ 3 — HYBRID AI ENGINE & SYMPTOM MAPPING TEST SUITE', () {
    late VoiceDialogueService service;
    late MedicalDialogueBrain brain;

    setUp(() {
      service = VoiceDialogueService();
      brain = MedicalDialogueBrain();
      service.clearHistory();
      brain.reset();
    });

    // =========================================================================
    // PHẦN 1: TẦNG 2 - FUZZY MATCHING & CHỊU LỖI CHÍNH TẢ (TYPO TOLERANCE)
    // =========================================================================
    test('1. Fuzzy Match: Gõ sai chính tả ép tim (bep tim / ep ty) vẫn nhận diện chuẩn CPR', () {
      final answer1 = service.resolveMedicalQuery('bep tim kieu gi');
      expect(answer1, contains('110 BPM'));

      final answer2 = service.resolveMedicalQuery('ep ty cho nan nhan');
      expect(answer2, contains('110 BPM'));
    });

    test('2. Fuzzy Match: Gõ không dấu & sai nhẹ (nhoi mau co tim, gay suong) nhận diện đúng', () {
      final answerHeart = service.resolveMedicalQuery('nan nhan bi nhoi mau co tim');
      expect(answerHeart, contains('nhồi máu cơ tim'));
      expect(answerHeart, contains('115'));

      final answerFracture = service.resolveMedicalQuery('toi nghi bi gay suong chan');
      expect(answerFracture, contains('BẤT ĐỘNG'));
      expect(answerFracture, contains('nẹp cứng'));
    });

    test('3. Fuzzy Match: Chịu lỗi chính tả bỏng (chom da) & sốt co giật (so giat)', () {
      final answerBurn = service.resolveMedicalQuery('co nen chom da len vet bong');
      expect(answerBurn, contains('chườm đá lạnh'));

      final answerConv = service.resolveMedicalQuery('be bi so giat o nha');
      expect(answerConv, contains('co giật'));
    });

    // =========================================================================
    // PHẦN 2: TẦNG 3 - SYMPTOM MAPPING ENGINE (MÔ TẢ TRIỆU CHỨNG KHÔNG CẦN TÊN BỆNH)
    // =========================================================================
    test('4. Symptom Mapping: "Tim đập loạn, khó thở, sợ hãi vô cớ" -> Nhận diện Cơn hoảng loạn (Panic Attack)', () {
      final answer = service.resolveMedicalQuery('Tim đập loạn, khó thở, sợ hãi vô cớ');
      expect(answer, contains('hoảng loạn'));
      expect(answer, contains('Panic Attack'));
      expect(answer, contains('4 giây'));
    });

    test('5. Symptom Mapping: "Bàn tay run rẩy, vã mồ hôi, đói cồn cào" -> Nhận diện Hạ đường huyết (Hypoglycemia)', () {
      final answer = service.resolveMedicalQuery('Bàn tay run rẩy, vã mồ hôi, đói cồn cào hoa mắt');
      expect(answer, contains('hạ đường huyết'));
      expect(answer, contains('15-15'));
      expect(answer, contains('nước đường'));
    });

    test('6. Symptom Mapping: "Mặt đỏ bừng, đau đầu dữ dội, mắt mờ bừng" -> Nhận diện Cơn tăng huyết áp cấp', () {
      final answer = service.resolveMedicalQuery('Mặt đỏ bừng, đau đầu dữ dội, mắt mờ bừng bốc hỏa');
      expect(answer, contains('tăng huyết áp'));
      expect(answer, contains('30 độ'));
      expect(answer, contains('180 mmHg'));
    });

    test('7. Symptom Mapping: "Miệng méo, tay yếu rơi thõng, nói ngọng bỗng nhiên" -> Nhận diện Đột quỵ não FAST', () {
      final answer = service.resolveMedicalQuery('Miệng méo xệ má, tay yếu rơi thõng, nói ngọng bỗng nhiên');
      expect(answer.toLowerCase(), contains('đột quỵ'));
      expect(answer, contains('FAST'));
      expect(answer, contains('thời gian vàng'));
    });

    test('8. Symptom Mapping: "Đau thắt ngực trái lan ra cánh tay trái, vã mồ hôi lạnh" -> Nhận diện Nhồi máu cơ tim', () {
      final answer = service.resolveMedicalQuery('Đau thắt bóp nghẹt ngực trái lan ra cánh tay trái, vã mồ hôi lạnh');
      expect(answer, contains('nhồi máu cơ tim'));
      expect(answer, contains('115'));
      expect(answer, contains('Fowler'));
    });

    test('9. Symptom Mapping: "Bụng cứng như gỗ, đau nhói khi sờ ấn vào" -> Nhận diện Đau bụng cấp ngoại khoa', () {
      final answer = service.resolveMedicalQuery('Bụng cứng như gỗ, đau nhói khi sờ ấn tay vào');
      expect(answer, contains('NGOẠI KHOA'));
      expect(answer, contains('ruột thừa'));
      expect(answer, contains('CẤM'));
    });

    test('10. Symptom Mapping: "Khớp ngón chân cái sưng nóng đỏ đau sau bữa tiệc nhậu hải sản" -> Nhận diện Cơn gút cấp', () {
      final answer = service.resolveMedicalQuery('Khớp ngón chân cái sưng nóng đỏ đau dữ dội sau bữa tiệc nhậu hải sản bia');
      expect(answer, contains('gút cấp'));
      expect(answer, contains('Kê cao'));
    });

    test('11. Symptom Mapping: "Nóng rát thượng vị ợ chua trào ngược lên ngực họng sau khi ăn no" -> Nhận diện GERD', () {
      final answer = service.resolveMedicalQuery('Nóng rát thượng vị ợ chua trào ngược lên ngực họng sau khi ăn no nằm xuống');
      expect(answer, contains('trào ngược dạ dày'));
      expect(answer, contains('GERD'));
    });

    test('12. Symptom Mapping: "Đau thắt lưng lan dọc xuống mông đùi kèm tê bì chân" -> Nhận diện Thoát vị đĩa đệm', () {
      final answer = service.resolveMedicalQuery('Đau thắt lưng lan dọc xuống mông đùi kèm tê bì chân không đứng thẳng được');
      expect(answer, contains('đau thắt lưng'));
      expect(answer, contains('thoát vị đĩa đệm'));
    });

    // =========================================================================
    // PHẦN 3: TẦNG 4 - SMART CLARIFICATION CHO CÁC CÂU HỎI MƠ HỒ
    // =========================================================================
    test('13. Smart Clarification: "Trẻ bị sốt" hỏi lại sốt mấy độ, tuổi, có co giật không', () {
      final answer = service.resolveMedicalQuery('Trẻ bị sốt');
      expect(answer, contains('Bé sốt đo được bao nhiêu độ?'));
      expect(answer, contains('mấy tuổi'));
      expect(answer, contains('co giật'));
    });

    test('14. Smart Clarification: "Người nhà bị ngã" hỏi lại va đầu, tỉnh, đau cổ lưng, gãy xương', () {
      final answer = service.resolveMedicalQuery('Người nhà bị ngã');
      expect(answer, contains('va đập đầu bất tỉnh'));
      expect(answer, contains('Cổ và lưng'));
      expect(answer, contains('gãy xương'));
    });

    test('15. Smart Clarification: "Bị dị ứng" hỏi lại ngứa da hay sưng môi mắt khó thở rít', () {
      final answer = service.resolveMedicalQuery('Bị dị ứng');
      expect(answer, contains('nổi mẩn ngứa'));
      expect(answer, contains('sưng phù môi mắt'));
      expect(answer, contains('khó thở rít'));
    });

    test('16. Smart Clarification: "Tôi bị đau ngực" hỏi lại tính chất đè nặng lan vai tay hay đau nhói khi hít sâu', () {
      final answer = service.resolveMedicalQuery('Tôi bị đau ngực');
      expect(answer, contains('đè nặng bóp nghẹt lan ra vai/tay trái'));
      expect(answer, contains('hít thở sâu'));
    });

    test('17. Smart Clarification: "Tôi bị đau đầu" hỏi lại xuất hiện từ từ hay bộc phát sét đánh', () {
      final answer = service.resolveMedicalQuery('Tôi bị đau đầu');
      expect(answer, contains('từ từ hay bộc phát dữ dội'));
      expect(answer, contains('sét đánh'));
      expect(answer, contains('cứng cổ'));
    });

    // =========================================================================
    // PHẦN 4: MULTI-TURN CONTEXT ACCUMULATION (TÍCH LŨY NGỮ CẢNH QUA NHIỀU VÒNG)
    // =========================================================================
    test('18. Multi-turn: Lượt 1 "đau ngực" (mơ hồ) + Lượt 2 "lan ra cánh tay trái và vã mồ hôi" -> Nhồi máu cơ tim', () {
      service.clearHistory();

      // Lượt 1: Nói mơ hồ -> AI hỏi lại thông minh
      final turn1 = service.resolveMedicalQuery('Tôi bị đau ngực');
      expect(turn1, contains('đè nặng bóp nghẹt lan ra vai/tay trái'));

      // Lượt 2: Người dùng cung cấp thêm triệu chứng -> AI ghép context Lượt 1 + Lượt 2
      final turn2 = service.resolveMedicalQuery('đau lan ra cánh tay trái và vã mồ hôi lạnh');
      expect(turn2, contains('BÁO ĐỘNG ĐỎ CẤP CỨU'));
      expect(turn2, contains('nhồi máu cơ tim'));
      expect(turn2, contains('Fowler'));
    });

    test('19. Multi-turn: Lượt 1 "Bé bị sốt" (mơ hồ) + Lượt 2 "bé đang co giật chân tay" -> Sốt cao co giật trẻ nhỏ', () {
      service.clearHistory();

      // Lượt 1: Nói mơ hồ -> AI hỏi lại thông minh
      final turn1 = service.resolveMedicalQuery('Bé bị sốt');
      expect(turn1, contains('Bé sốt đo được bao nhiêu độ?'));

      // Lượt 2: Cung cấp co giật -> AI chuyển ngay sang phác đồ Sốt co giật
      final turn2 = service.resolveMedicalQuery('bé đang co giật chân tay trợn mắt');
      expect(turn2, contains('nằm nghiêng'));
      expect(turn2, contains('CẤM nhét'));
      expect(turn2, contains('hậu môn'));
    });

    test('20. Multi-turn: Lượt 1 "bạn tôi đánh tôi tôi thấy mình bị đau đầu" + Lượt 2 "không buồn nôn toán xung quanh đầu" -> Hướng dẫn chấn thương đầu kín sau va chạm', () {
      service.clearHistory();

      final turn1 = service.resolveMedicalQuery('bạn tôi đánh tôi tôi thấy mình bị đau đầu');
      expect(turn1, contains('từ từ hay bộc phát dữ dội'));

      final turn2 = service.resolveMedicalQuery('không buồn nôn toán xung quanh đầu');
      expect(turn2, isNot(contains('Xử trí nôn ói')));
      expect(turn2, contains('va chạm/đánh vào vùng đầu'));
    });
  });
}
