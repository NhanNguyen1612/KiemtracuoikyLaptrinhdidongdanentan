import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resq_aid/core/services/voice_dialogue_service.dart';
import 'package:resq_aid/core/widgets/voice_dialogue_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FEATURE: ĐỐI THOẠI GIỌNG NÓI 2 CHIỀU RẢNH TAY (VOICE DIALOGUE AI)', () {
    late VoiceDialogueService service;

    setUp(() {
      service = VoiceDialogueService();
      service.clearHistory();
    });

    test('1. Tình huống Ép tim CPR: Nạn nhân có mạch / thở lại', () {
      final answer = service.resolveMedicalQuery('nạn nhân có mạch lại rồi');
      expect(answer, contains('Dừng ép tim ngay'));
      expect(answer, contains('tư thế hồi phục'));
    });

    test('2. Tình huống Ép tim CPR: Cứu hộ viên mỏi tay đuối sức', () {
      final answer = service.resolveMedicalQuery('tôi mỏi tay quá xử lý sao');
      expect(answer, contains('Đổi người ép tim'));
      expect(answer, contains('khóa thẳng 2 khuỷu tay 180 độ'));
    });

    test('3. Tình huống Đo nhịp tim & độ sâu ép tim', () {
      final answerDepth = service.resolveMedicalQuery('độ sâu ép bao nhiêu xăng ti mét');
      expect(answerDepth, contains('5 đến 6 xăng ti mét'));

      final answerRate = service.resolveMedicalQuery('nhịp tim tốc độ thế nào');
      expect(answerRate, contains('110 BPM'));
    });

    test('4. Tình huống Máy AED hỗ trợ khử rung tim', () {
      final answer = service.resolveMedicalQuery('đã có máy aed sốc điện');
      expect(answer, contains('Bật nguồn máy AED ngay'));
    });

    test('5. Tình huống Kiểm tra Tư thế (Posture Check)', () {
      final answerPosture = service.resolveMedicalQuery('tư thế tay đã đúng chưa');
      expect(answerPosture, contains('khóa thẳng tuyệt đối 180 độ'));
      expect(answerPosture, contains('vuông góc 90 độ'));

      final answerKneel = service.resolveMedicalQuery('quỳ như thế nào');
      expect(answerKneel, contains('Quỳ sát cạnh hông ngực'));
    });

    test('6. Tình huống Quét Camera Vết thương & Bỏng (Chườm đá lạnh & Kem đánh răng)', () {
      final answerIce = service.resolveMedicalQuery('có được chườm đá lạnh lên vết bỏng không');
      expect(answerIce, contains('KHÔNG chườm đá lạnh'));
      expect(answerIce, contains('15 đến 20 phút'));

      final answerPaste = service.resolveMedicalQuery('có được bôi kem đánh răng hay mỡ trăn không');
      expect(answerPaste, contains('Cấm tuyệt đối bôi kem đánh răng'));
    });

    test('7. Tình huống Quét Camera Vết thương: Bọng nước & Giật điện', () {
      final answerBlister = service.resolveMedicalQuery('bọng nước có chọc vỡ không');
      expect(answerBlister, contains('không chọc vỡ'));

      final answerElec = service.resolveMedicalQuery('vết bỏng sau giật điện có điểm ra ở đâu');
      expect(answerElec, contains('Ngắt nguồn điện'));
      expect(answerElec, contains('điểm dòng điện vào và điểm dòng điện đi ra'));
    });

    test('8. Tình huống Đuối nước & Nghẹn dị vật Heimlich', () {
      final answerDrown = service.resolveMedicalQuery('có nên vác dốc ngược nạn nhân chạy xóc nước không');
      expect(answerDrown, contains('không vác dốc ngược'));

      final answerChoke = service.resolveMedicalQuery('nghẹn dị vật xử lý thế nào');
      expect(answerChoke, contains('5 cú vỗ lưng'));
      expect(answerChoke, contains('Heimlich'));
    });

    test('9. Lưu trữ lịch sử đối thoại 2 chiều chuẩn xác (User turn & AI turn)', () async {
      await service.simulateSpokenInput('Nạn nhân có mạch lại rồi');
      expect(service.conversationHistory.length, equals(2));
      expect(service.conversationHistory[0].isUser, isTrue);
      expect(service.conversationHistory[0].text, equals('Nạn nhân có mạch lại rồi'));
      expect(service.conversationHistory[1].isUser, isFalse);
      expect(service.conversationHistory[1].text, contains('Dừng ép tim'));
    });

    test('11. Đối thoại đa lượt: Hỏi bị hóc và hỏi tiếp cách làm chi tiết (giữ đúng chủ đề)', () {
      // Lượt 1: Báo bị hóc
      final answer1 = service.resolveMedicalQuery('tôi bị hóc dị vật');
      expect(answer1, contains('ho to'));
      expect(answer1, contains('Heimlich'));

      // Lượt 2: Hỏi cách làm chi tiết (không nhắc lại chữ hóc) -> Não AI vẫn nhớ chủ đề Hóc dị vật
      final answer2 = service.resolveMedicalQuery('hướng dẫn cách làm chi tiết');
      expect(answer2, contains('Vỗ lưng'));
      expect(answer2, contains('gót bàn tay'));
      expect(answer2, contains('Thủ thuật Heimlich'));
      expect(answer2, contains('trên rốn và dưới mũi ức'));
    });

    test('12. Đứt tay: Sơ cứu tức thì và chủ động gợi ý Quét Camera vết thương', () {
      service.clearHistory();
      final answer = service.resolveMedicalQuery('tôi bị đứt tay chảy máu');
      expect(answer, contains('ấn chặt trực tiếp'));
      expect(answer, contains('nâng cao tay'));
      expect(answer, contains('Quét Camera'));

      // Lượt hỏi chi tiết tiếp theo
      final answerDetail = service.resolveMedicalQuery('cách làm chi tiết');
      expect(answerDetail, contains('Cầm máu'));
      expect(answerDetail, contains('KHÔNG đổ cồn'));
      expect(answerDetail, contains('Quét Camera'));
    });

    test('13. Đối tượng trẻ sơ sinh dưới 1 tuổi: Tự động phát hiện và cảnh báo cấm Heimlich', () {
      service.clearHistory();
      final answer = service.resolveMedicalQuery('bé sơ sinh dưới 1 tuổi bị sặc hóc sữa');
      expect(answer, contains('sơ sinh'));
      expect(answer, contains('vỗ lưng'));
      expect(answer, contains('2 ngón tay'));

      final answerDetail = service.resolveMedicalQuery('làm chi tiết thế nào');
      expect(answerDetail, contains('dốc đầu'));
      expect(answerDetail, contains('CẤM ép bụng Heimlich'));
    });

    test('14. Khủng hoảng tâm thần: Câu hỏi "Tôi bị thần kinh" phản hồi thấu cảm chuẩn y khoa', () {
      service.clearHistory();
      final answer = service.resolveMedicalQuery('Tôi bị thần kinh');
      // Tuyệt đối không trả về Heimlich hóc nghẹn
      expect(answer, isNot(contains('Heimlich')));
      expect(answer, isNot(contains('vỗ lưng')));
      // Trả lời chuẩn khủng hoảng tâm thần
      expect(answer, contains('4 giây'));
      expect(answer, contains('5-4-3-2-1'));

      // Đào sâu chi tiết
      final answerDetail = service.resolveMedicalQuery('cách làm chi tiết');
      expect(answerDetail, contains('Box Breathing'));
      expect(answerDetail, contains('tiếp đất 5-4-3-2-1'));
      expect(answerDetail, contains('19009095'));
    });

    test('15. Chuyển đổi chủ đề linh hoạt: Từ hóc dị vật sang khủng hoảng thần kinh không bị dính topic cũ', () {
      service.clearHistory();
      // Bước 1: Hỏi về hóc
      final answerChoke = service.resolveMedicalQuery('bé bị hóc dị vật');
      expect(answerChoke, contains('Heimlich'));

      // Bước 2: Chuyển sang thần kinh -> Não AI phải chuyển topic ngay lập tức, không được regurgitate Heimlich
      final answerMental = service.resolveMedicalQuery('Tôi bị thần kinh');
      expect(answerMental, isNot(contains('Heimlich')));
      expect(answerMental, contains('4 giây'));

      // Bước 3: Chuyển tiếp sang đứt tay
      final answerCut = service.resolveMedicalQuery('tôi bị đứt tay');
      expect(answerCut, contains('cầm máu'));
      expect(answerCut, contains('Quét Camera'));
    });

    test('16. Danh mục bệnh mở rộng: Nhồi máu cơ tim, Đột quỵ FAST, Rắn cắn, Say nắng sốc nhiệt', () {
      service.clearHistory();
      // Nhồi máu cơ tim
      final answerHeart = service.resolveMedicalQuery('bị đau thắt ngực nhồi máu cơ tim');
      expect(answerHeart, contains('Fowler'));
      expect(answerHeart, contains('115'));

      // Đột quỵ
      final answerStroke = service.resolveMedicalQuery('người nhà nghi ngờ đột quỵ méo miệng');
      expect(answerStroke, contains('FAST'));
      expect(answerStroke, contains('thời gian vàng'));

      // Rắn cắn
      final answerSnake = service.resolveMedicalQuery('bị rắn cắn vào chân');
      expect(answerSnake, contains('bất động'));
      expect(answerSnake, contains('THẤP HƠN tim'));

      // Say nắng
      final answerHeat = service.resolveMedicalQuery('bị say nắng sốc nhiệt');
      expect(answerHeat, contains('râm mát'));
      expect(answerHeat, contains('hạ thân nhiệt'));
    });

    test('17. CẤP ĐỘ 2 - Cấp cứu sốc phản vệ khẩn cấp & Tiêm bút EpiPen', () {
      service.clearHistory();
      final answer = service.resolveMedicalQuery('người nhà bị sốc phản vệ dị ứng ngạt thở');
      expect(answer, contains('SỐC PHẢN VỆ'));
      expect(answer, contains('Epinephrine'));
      expect(answer, contains('EpiPen'));
      expect(answer, contains('30cm'));
    });

    test('18. CẤP ĐỘ 2 - Cơn tăng huyết áp cấp & Trào ngược dạ dày thực quản GERD', () {
      service.clearHistory();
      final answerBp = service.resolveMedicalQuery('huyết áp vọt lên cao 180');
      expect(answerBp, contains('tăng huyết áp'));
      expect(answerBp, contains('180 mmHg'));

      final answerGerd = service.resolveMedicalQuery('bị trào ngược gerd ợ nóng rát ngực');
      expect(answerGerd, contains('trào ngược dạ dày'));
      expect(answerGerd, contains('nhồi máu cơ tim'));
    });

    test('19. CẤP ĐỘ 2 - Nhi khoa chuyên biệt: Sốt cao co giật trẻ nhỏ & Trẻ sơ sinh sặc sữa', () {
      service.clearHistory();
      final answerChild = service.resolveMedicalQuery('bé bị sốt co giật');
      expect(answerChild, contains('nằm nghiêng'));
      expect(answerChild, contains('CẤM nhét'));
      expect(answerChild, contains('hậu môn'));

      final answerMilk = service.resolveMedicalQuery('bé sơ sinh bị sặc sữa');
      expect(answerMilk, contains('SẶC SỮA'));
      expect(answerMilk, contains('nằm sấp'));
      expect(answerMilk, contains('2 ngón tay'));
    });

    test('20. CẤP ĐỘ 2 - Chấn thương ngoại khoa: Bong gân R.I.C.E, Hóc xương cá, Rơi rụng răng cửa', () {
      service.clearHistory();
      // Bong gân
      final answerSprain = service.resolveMedicalQuery('tôi bị bong gân trẹo chân');
      expect(answerSprain, contains('R.I.C.E'));
      expect(answerSprain, contains('Chườm đá'));

      // Hóc xương cá
      final answerBone = service.resolveMedicalQuery('bị hóc xương cá ở cổ');
      expect(answerBone, contains('CẤM nuốt cục cơm nguội'));
      expect(answerBone, contains('Tai - Mũi - Họng'));

      // Rơi răng cửa
      final answerTooth = service.resolveMedicalQuery('bị ngã rơi răng cửa ra ngoài');
      expect(answerTooth, contains('RĂNG BỊ RƠI'));
      expect(answerTooth, contains('sữa tươi'));
      expect(answerTooth, contains('1 giờ vàng'));
    });

    test('21. CẤP ĐỘ 2 - Câu hỏi mơ hồ: Hệ thống Smart Clarification hỏi lại phân loại thông minh', () {
      service.clearHistory();
      // Câu hỏi quá ngắn "tôi bị đau"
      final answerPain = service.resolveMedicalQuery('tôi bị đau');
      expect(answerPain, contains('vùng nào cụ thể'));
      expect(answerPain, contains('ngực, bụng, đầu'));

      // Câu hỏi quá ngắn "tôi bị mệt"
      final answerFatigue = service.resolveMedicalQuery('tôi bị mệt');
      expect(answerFatigue, contains('hạ đường huyết'));
      expect(answerFatigue, contains('khó thở'));
    });

    test('22. CẤP ĐỘ 2 - Đau thắt lưng cấp & Cơn gút cấp sưng ngón chân cái', () {
      service.clearHistory();
      final answerBack = service.resolveMedicalQuery('bị đau thắt lưng buốt cột sống');
      expect(answerBack, contains('thoát vị đĩa đệm'));
      expect(answerBack, contains('đệm cứng'));

      final answerGout = service.resolveMedicalQuery('bị cơn gút đau khớp ngón chân cái');
      expect(answerGout, contains('gút cấp tính'));
      expect(answerGout, contains('axit uric'));
    });

    test('23. Cấp cứu phức hợp đa bệnh lý: Chó cắn và co giật đồng thời', () {
      service.clearHistory();
      final answer = service.resolveMedicalQuery('tôi bảo bạn tôi bị chó cắn và co giật');
      // Phải bao gồm cả xử trí co giật khẩn cấp (115, nằm nghiêng, cấm nhét thìa)
      expect(answer, contains('CO GIẬT'));
      expect(answer, contains('115'));
      expect(answer, contains('CẤM nhét'));
      // VÀ phải bao gồm cả xử trí chó cắn phòng dại (xối rửa 15 phút, tiêm phòng dại / huyết thanh)
      expect(answer, contains('CHÓ CẮN'));
      expect(answer, contains('15 phút'));
      expect(answer, contains('tiêm'));
      expect(answer, contains('dại'));
      expect(answer, contains('bệnh viện'));
    });

    test('24. CẤP ĐỘ 3 - Nhận diện đa dạng cách nói dân gian, từ lóng và ngôi thứ ba như bác sĩ thực thụ', () {
      service.clearHistory();

      // 1. "bạn tôi bị xỉu" -> Ngất xỉu (Fainting)
      final resFaint = service.resolveMedicalQuery('bạn tôi bị xỉu');
      expect(resFaint.toLowerCase(), anyOf(contains('ngất'), contains('xỉu'), contains('nằm')));

      // 2. "con tôi ngộp nước" -> Đuối nước (Drowning)
      final resDrown = service.resolveMedicalQuery('con tôi ngộp nước');
      expect(resDrown.toLowerCase(), anyOf(contains('đuối nước'), contains('ép tim'), contains('hô hấp'), contains('ngạt')));

      // 3. "mẹ tôi bị điện đánh" -> Điện giật (ElectricShock)
      final resElec = service.resolveMedicalQuery('mẹ tôi bị điện đánh');
      expect(resElec.toLowerCase(), anyOf(contains('điện'), contains('cắt nguồn'), contains('cầu dao')));

      // 4. "uống nhầm thuốc sâu rồi" -> Ngộ độc (Poisoning)
      final resPoison = service.resolveMedicalQuery('uống nhầm thuốc sâu rồi');
      expect(resPoison.toLowerCase(), anyOf(contains('ngộ độc'), contains('thuốc'), contains('115'), contains('bệnh viện')));

      // 5. "bị phỏng nước sôi" -> Bỏng (Burn)
      final resBurn = service.resolveMedicalQuery('bị phỏng nước sôi');
      expect(resBurn.toLowerCase(), anyOf(contains('bỏng'), contains('nước mát'), contains('xối')));

      // 6. "bị chó táp vào tay" -> Chó mèo cắn (DogCatBite)
      final resDog = service.resolveMedicalQuery('bị chó táp vào tay');
      expect(resDog.toLowerCase(), anyOf(contains('chó cắn'), contains('dại'), contains('xà phòng')));

      // 7. "bị hóc không nuốt được" -> Hóc dị vật (Choking)
      final resChoke = service.resolveMedicalQuery('bị hóc không nuốt được');
      expect(resChoke.toLowerCase(), anyOf(contains('hóc'), contains('heimlich'), contains('vỗ lưng')));
    });

    test('25. Tình huống thực tế: Miếng sắt rỉ quẹt vào chân chảy máu (Nguy cơ Uốn ván & Định vị đúng chân)', () {
      service.clearHistory();
      final res = service.resolveMedicalQuery('bạn tôi bị miếng sắt rỉ quẹt vào chân chảy máu');

      // 1. Phải cảnh báo UỐN VÁN (TETANUS) và tiêm SAT trong 24 giờ vì có sắt rỉ
      expect(res.toLowerCase(), contains('uốn ván'));
      expect(res.toLowerCase(), anyOf(contains('tiêm phòng'), contains('tiêm')));
      expect(res.toLowerCase(), anyOf(contains('sat'), contains('24 giờ')));

      // 2. Phải nhận diện ĐÚNG vị trí "CHÂN", kê cao chân, KHÔNG nói "nâng cao tay"
      expect(res.toLowerCase(), contains('chân'));
      expect(res.toLowerCase(), contains('kê cao chân'));
      expect(res.toLowerCase(), isNot(contains('nâng cao tay')));

      // 3. Phải có hướng dẫn cầm máu và xối rửa gỉ sắt
      expect(res.toLowerCase(), anyOf(contains('cầm máu'), contains('gạc')));
      expect(res.toLowerCase(), anyOf(contains('gỉ sắt'), contains('rửa')));
    });

    test('26. Chào hỏi & Gọi trợ lý tự nhiên: Câu thoại "bạn", "bạn ơi", "chào bác sĩ" phản hồi thấu cảm', () {
      service.clearHistory();

      // Trường hợp 1: Người dùng chỉ gọi "bạn"
      final res1 = service.resolveMedicalQuery('bạn');
      expect(res1, contains('Trợ lý Sơ cứu Cấp cứu ResQ-Aid'));
      expect(res1, contains('đang lắng nghe'));
      // Tuyệt đối không nhảy vào phân tích triệu chứng bệnh hoặc báo động đỏ
      expect(res1.contains('báo động đỏ'), isFalse);
      expect(res1.contains('hít thở sâu và đều đặn'), isFalse);

      // Trường hợp 2: Người dùng gọi "bác sĩ ơi"
      final res2 = service.resolveMedicalQuery('bác sĩ ơi');
      expect(res2, contains('Trợ lý Sơ cứu Cấp cứu ResQ-Aid'));
      expect(res2, contains('đang lắng nghe'));

      // Trường hợp 3: Người dùng gọi "alo"
      final res3 = service.resolveMedicalQuery('alo');
      expect(res3, contains('Trợ lý Sơ cứu Cấp cứu ResQ-Aid'));
      expect(res3, contains('đang lắng nghe'));
    });

    test('27. Xử lý phủ định thông minh: "không chảy máu", "chưa ngất", "không đau ngực", "không buồn nôn"', () {
      service.clearHistory();

      // Phủ định chảy máu
      final resBleed = service.resolveMedicalQuery('chân bị va chạm trầy xước nhưng không chảy máu');
      expect(resBleed.toLowerCase(), isNot(contains('chảy máu xối xả')));

      // Phủ định đau ngực
      final resHeart = service.resolveMedicalQuery('tôi hơi mệt nhưng không đau ngực');
      expect(resHeart.toLowerCase(), isNot(contains('nhồi máu cơ tim cấp')));

      // Phủ định buồn nôn không được kích hoạt topic nôn ói
      final resNausea = service.resolveMedicalQuery('tôi đau đầu nhưng không buồn nôn');
      expect(resNausea.toLowerCase(), isNot(contains('xử trí nôn ói')));
    });

    test('28. Multi-turn Clarification: Lượt 1 "bạn tôi đánh tôi tôi thấy mình bị đau đầu" + Lượt 2 "không buồn nôn toán xung quanh đầu"', () {
      service.clearHistory();

      // Lượt 1: Bị đánh đau đầu -> AI hỏi làm rõ cờ đỏ
      final turn1 = service.resolveMedicalQuery('bạn tôi đánh tôi tôi thấy mình bị đau đầu');
      expect(turn1, contains('sét đánh'));
      expect(turn1, contains('buồn nôn'));

      // Lượt 2: Người dùng trả lời không buồn nôn, đau tỏa xung quanh đầu
      // AI phải liên kết với cú đánh ở Lượt 1 và xử trí chấn thương đầu kín
      final turn2 = service.resolveMedicalQuery('không buồn nôn toán xung quanh đầu');
      expect(turn2, contains('chấn thương đầu kín'));
      expect(turn2, contains('Chườm lạnh'));
      expect(turn2, contains('TUYỆT ĐỐI KHÔNG dùng Aspirin'));
      expect(turn2, contains('24-48 GIỜ'));
      expect(turn2.toLowerCase(), isNot(contains('xử trí nôn ói')));
    });

    test('29. Multi-turn Đau đầu: Lượt 1 "tôi bị đau đầu" + Lượt 2 "tôi mô tả đau lớn" -> Cảnh báo cờ đỏ thần kinh, KHÔNG nhảy sang nhồi máu cơ tim', () {
      service.clearHistory();
      final turn1 = service.resolveMedicalQuery('tôi bị đau đầu');
      expect(turn1, contains('sét đánh'));
      expect(turn1, contains('buồn nôn'));

      final turn2 = service.resolveMedicalQuery('tôi mô tả đau lớn');
      expect(turn2, contains('CỜ ĐỎ THẦN KINH'));
      expect(turn2, contains('đau đầu dữ dội'));
      expect(turn2, contains('115'));
      expect(turn2, contains('TUYỆT ĐỐI KHÔNG tự ý uống Aspirin'));
      expect(turn2.toLowerCase(), isNot(contains('nhồi máu cơ tim')));
      expect(turn2.toLowerCase(), isNot(contains('fowler')));
    });

    test('30. Multi-turn Đau đầu: Lượt 1 "tôi bị đau đầu" + Lượt 2 "đau lớn" -> Cảnh báo nguy hiểm, KHÔNG hỏi lại "Bạn bị đau ở vùng nào"', () {
      service.clearHistory();
      final turn1 = service.resolveMedicalQuery('tôi bị đau đầu');
      expect(turn1, contains('sét đánh'));

      final turn2 = service.resolveMedicalQuery('đau lớn');
      expect(turn2, contains('CỜ ĐỎ THẦN KINH'));
      expect(turn2, contains('115'));
      expect(turn2.toLowerCase(), isNot(contains('bạn đang bị đau ở vùng nào cụ thể')));
    });

    test('31. Multi-turn Đau đầu: Lượt 1 "tôi bị đau đầu" + Lượt 2 "đau từ từ thôi" -> Xử trí đau đầu căng thẳng / Migraine thông thường', () {
      service.clearHistory();
      final turn1 = service.resolveMedicalQuery('tôi bị đau đầu');
      expect(turn1, contains('sét đánh'));

      final turn2 = service.resolveMedicalQuery('đau từ từ thôi');
      expect(turn2, contains('ĐAU ĐẦU CĂNG THẲNG / MIGRAINE THÔNG THƯỜNG'));
      expect(turn2, contains('Nằm nghỉ ngơi ở nơi yên tĩnh'));
      expect(turn2, contains('Paracetamol 500mg'));
      expect(turn2.toLowerCase(), isNot(contains('ngã từ độ cao')));
    });

    test('32. Multi-turn Đau đầu: Lượt 1 "tôi bị đau đầu" + Lượt 2 "bị bạn đánh va chạm u đầu" -> Tự động chuyển sang Chấn thương đầu kín', () {
      service.clearHistory();
      final turn1 = service.resolveMedicalQuery('tôi bị đau đầu');
      expect(turn1, contains('sét đánh'));

      final turn2 = service.resolveMedicalQuery('bị bạn đánh va chạm u đầu');
      expect(turn2, contains('chấn thương đầu kín'));
      expect(turn2, contains('Chườm lạnh'));
      expect(turn2, contains('24-48 GIỜ'));
    });

    test('33. Multi-turn Đau ngực: Lượt 1 "tôi bị đau ngực" + Lượt 2 "đè nặng bóp nghẹt khó thở" -> Cấp cứu nhồi máu cơ tim tư thế Fowler', () {
      service.clearHistory();
      final turn1 = service.resolveMedicalQuery('tôi bị đau ngực');
      expect(turn1, contains('đè nặng bóp nghẹt'));

      final turn2 = service.resolveMedicalQuery('đè nặng bóp nghẹt khó thở');
      expect(turn2, contains('nhồi máu cơ tim'));
      expect(turn2, contains('Fowler'));
      expect(turn2, contains('115'));
    });

    test('34. Multi-turn Đau ngực: Lượt 1 "tôi bị đau ngực" + Lượt 2 "chỉ nhói khi hít thở sâu và ấn vào sườn" -> Xử trí đau dây thần kinh liên sườn / cơ ngực', () {
      service.clearHistory();
      final turn1 = service.resolveMedicalQuery('tôi bị đau ngực');
      expect(turn1, contains('đè nặng bóp nghẹt'));

      final turn2 = service.resolveMedicalQuery('chỉ nhói khi hít thở sâu và ấn vào sườn');
      expect(turn2, contains('ĐAU THÀNH NGỰC / ĐAU DÂY THẦN KINH LIÊN SƯỜN'));
      expect(turn2, contains('hít thở nông đều'));
      expect(turn2.toLowerCase(), isNot(contains('fowler')));
    });

    test('35. Multi-turn Dị ứng: Lượt 1 "tôi bị dị ứng" + Lượt 2 "sưng phù môi mắt khó thở" -> Cấp cứu Sốc phản vệ tiêm EpiPen', () {
      service.clearHistory();
      final turn1 = service.resolveMedicalQuery('tôi bị dị ứng');
      expect(turn1, contains('sưng phù môi'));

      final turn2 = service.resolveMedicalQuery('sưng phù môi mắt khó thở');
      expect(turn2, contains('SỐC PHẢN VỆ NGUY KỊCH'));
      expect(turn2, contains('EpiPen'));
      expect(turn2, contains('115'));
    });

    test('36. Multi-turn Sốt trẻ em: Lượt 1 "con tôi bị sốt" + Lượt 2 "bé đang bị co giật" -> Cấp cứu sốt cao co giật cấm nhét thìa', () {
      service.clearHistory();
      final turn1 = service.resolveMedicalQuery('con tôi bị sốt');
      expect(turn1, contains('co giật'));

      final turn2 = service.resolveMedicalQuery('bé đang bị co giật');
      expect(turn2, contains('SỐT CAO CO GIẬT'));
      expect(turn2, contains('CẤM nhét'));
      expect(turn2, contains('hậu môn'));
    });

    test('37. Out-of-Domain: Tình huống trên núi không có thuốc -> Phản hồi hướng dẫn cứu nạn 112, KHÔNG đoán bừa "Dừng ép tim ngay!"', () {
      service.clearHistory();
      final answer = service.resolveMedicalQuery('Hiện giờ tôi đang ở trên núi không có thuốc bây giờ phải làm sao');
      expect(answer.toLowerCase(), isNot(contains('dừng ép tim')));
      expect(answer.toLowerCase(), isNot(contains('cpr')));
      expect(answer, contains('TRÊN NÚI'));
      expect(answer, contains('Cứu nạn 112'));
    });

    test('38. Đa triệu chứng đồng thời "tôi bị té ngã đau đầu chảy máu" -> Xử lý CẢ HAI (Cầm máu + Chấn thương đầu)', () {
      service.clearHistory();
      final answer = service.resolveMedicalQuery('tôi bị té ngã đau đầu chảy máu');
      expect(answer.toLowerCase(), anyOf(contains('cầm máu'), contains('chảy máu'), contains('ấn chặt trực tiếp')));
      expect(answer.toLowerCase(), anyOf(contains('đầu'), contains('chấn thương đầu'), contains('chườm lạnh')));
    });

    test('39. Safety Router can thiệp cắt ngang giữa đối thoại: Đang hỏi làm rõ đau đầu mà người dùng báo "bạn ấy ngừng thở rồi" -> Ngắt ngay sang CPR khẩn cấp', () {
      service.clearHistory();
      // Lượt 1: Báo đau đầu -> AI hỏi làm rõ cờ đỏ
      final turn1 = service.resolveMedicalQuery('tôi bị đau đầu');
      expect(turn1, contains('sét đánh'));

      // Lượt 2: Tình trạng chuyển biến nguy kịch ngừng thở -> Safety Router phải chiếm quyền ngay lập tức
      final turn2 = service.resolveMedicalQuery('bạn ấy ngừng thở rồi');
      expect(turn2.toLowerCase(), anyOf(contains('ngưng thở'), contains('ngừng thở')));
      expect(turn2, contains('ép tim'));
      expect(turn2, contains('115'));
      // Tuyệt đối không tiếp tục hỏi đau đầu
      expect(turn2.toLowerCase(), isNot(contains('cơn đau đầu')));
    });

    test('40. Tình huống thực tế: "bạn Tôi bị ngã nhịp tim rơi vào khoảng 150" -> CẤM ÉP TIM, đánh giá sốc chấn thương & gọi 115', () {
      service.clearHistory();
      final answer = service.resolveMedicalQuery('bạn Tôi bị ngã nhịp tim rơi vào khoảng 150');
      expect(answer, contains('TUYỆT ĐỐI KHÔNG ĐƯỢC ÉP TIM'));
      expect(answer, contains('Tachycardia'));
      expect(answer, contains('SỐC MẤT MÁU KÍN'));
      expect(answer, contains('115'));
      // Tuyệt đối không bị nhầm sang đổi người ép tim
      expect(answer, isNot(contains('Đổi người ép tim')));
    });

    test('41. Tình huống: Nhịp tim nhanh đơn thuần 150 BPM -> CẤM ép tim, thở sâu 4-2-6, gọi 115 nếu đau ngực', () {
      service.clearHistory();
      final answer = service.resolveMedicalQuery('nhịp tim 150');
      expect(answer, contains('TUYỆT ĐỐI KHÔNG ÉP TIM'));
      expect(answer, contains('Tachycardia'));
      expect(answer, contains('THỞ SÂU VÀ CHẬM'));
    });

    test('42. Tình huống: Chảy máu cam -> Bóp cánh mũi, cúi đầu ra trước, CẤM ngửa đầu', () {
      service.clearHistory();
      final answer = service.resolveMedicalQuery('tôi bị chảy máu cam');
      expect(answer, contains('HƠI CÚI ĐẦU NHẸ RA PHÍA TRƯỚC'));
      expect(answer, contains('TUYỆT ĐỐI CẤM NGỬA ĐẦU RA SAU'));
      expect(answer, contains('BÓP CHẶT CÁNH MŨI'));
    });

    test('43. Tình huống: Hóa chất bắn vào mắt -> Xối rửa 15-20 phút từ trong ra ngoài, CẤM dụi mắt', () {
      service.clearHistory();
      final answer = service.resolveMedicalQuery('bị hóa chất vào mắt');
      expect(answer, contains('XỐI RỬA MẮT NGAY LẬP TỨC 15-20 PHÚT'));
      expect(answer, contains('TUYỆT ĐỐI CẤM DỤI MẮT'));
    });

    test('44. Tình huống: Sứa biển cắn -> Rửa giấm ăn hoặc nước biển, CẤM nước ngọt', () {
      service.clearHistory();
      final answer = service.resolveMedicalQuery('tôi bị sứa cắn rát quá');
      expect(answer, contains('RỬA BẰNG GIẤM ĂN HOẶC NƯỚC BIỂN'));
      expect(answer, contains('TUYỆT ĐỐI CẤM RỬA BẰNG NƯỚC NGỌT'));
    });

    test('45. Tình huống: Sốt xuất huyết Dengue -> Cảnh báo nguy hiểm, Paracetamol, CẤM Aspirin Ibuprofen', () {
      service.clearHistory();
      final answer = service.resolveMedicalQuery('nghi bị sốt xuất huyết');
      expect(answer, contains('PARACETAMOL'));
      expect(answer, contains('TUYỆT ĐỐI CẤM dùng Aspirin, Ibuprofen'));
      expect(answer, contains('DẤU HIỆU CẢNH BÁO NGUY HIỂM'));
    });

    test('46. Tình huống: Ngạt khói đám cháy & Ngộ độc khí CO -> Bò thấp, thoáng khí, thở oxy', () {
      service.clearHistory();
      final answer = service.resolveMedicalQuery('bị ngạt khói đám cháy');
      expect(answer, contains('THOÁT RA NƠI THOÁNG KHÍ'));
      expect(answer, contains('bò thấp'));
    });

    testWidgets('10. Widget đối thoại VoiceDialogueWidget render mượt mà và tương tác nút', (tester) async {
      service.clearHistory();
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VoiceDialogueWidget(
              contextHint: 'CPR Test',
              suggestedPrompts: [
                'Nạn nhân tỉnh rồi',
                'Mỏi tay quá',
              ],
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('ĐỐI THOẠI 2 CHIỀU RẢNH TAY (VOICE AI)'), findsOneWidget);
      expect(find.text('Nạn nhân tỉnh rồi'), findsOneWidget);
      expect(find.text('Mỏi tay quá'), findsOneWidget);

      // Chạm vào nút gợi ý câu hỏi để kích hoạt đối thoại bằng giọng nói
      await tester.tap(find.text('Nạn nhân tỉnh rồi'));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Bác sĩ AI ResQ-Aid:'), findsOneWidget);

      service.clearHistory();
    });
  });
}
