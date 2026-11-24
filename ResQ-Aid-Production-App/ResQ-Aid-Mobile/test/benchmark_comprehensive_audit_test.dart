import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:resq_aid/core/services/voice_dialogue_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('RUN FULL USER BENCHMARK EVALUATION (7 GROUPS, 86+ QUERIES)', () async {
    final service = VoiceDialogueService();
    await service.initialize();

    final results = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'groups': <String, dynamic>{},
    };

    // Helper to evaluate a single query
    Map<String, dynamic> evalSingle(String query, {String? category}) {
      service.clearHistory();
      final answer = service.resolveMedicalQuery(query);
      return {
        'query': query,
        'category': category ?? '',
        'response': answer,
        'response_length': answer.length,
        'first_line': answer.split('\n').first,
      };
    }

    // Helper for multi-turn
    Map<String, dynamic> evalMultiTurn(String category, String initialQuery, String branchName, String followUpQuery) {
      service.clearHistory();
      final turn1 = service.resolveMedicalQuery(initialQuery);
      final turn2 = service.resolveMedicalQuery(followUpQuery);
      return {
        'category': category,
        'branch': branchName,
        'turn1_query': initialQuery,
        'turn1_response': turn1,
        'turn2_query': followUpQuery,
        'turn2_response': turn2,
      };
    }

    print('>>> RUNNING GROUP 1: Câu hỏi đơn — một triệu chứng hoặc sự cố...');
    final g1 = <Map<String, dynamic>>[];

    // Đau đầu và thần kinh
    final g1DauDau = [
      'Tôi đang bị nhức đầu, nên làm gì?',
      'Đầu tôi đau dữ dội đột ngột như sét đánh.',
      'Tôi bị đau đầu từ từ, không sốt và không nôn.',
      'Tôi đau đầu kèm sốt và cứng cổ.',
      'Tôi đau đầu, nói khó và yếu một bên tay.',
      'Tôi vừa té đập đầu, giờ thấy buồn ngủ.',
      'Tôi bị co giật, cần xử trí thế nào?',
      'Bạn tôi vừa ngất xỉu, giờ đã tỉnh lại.',
    ];
    for (final q in g1DauDau) {
      g1.add(evalSingle(q, category: 'Đau đầu và thần kinh'));
    }

    // Tim mạch và hô hấp
    final g1TimMach = [
      'Tôi bị đau tức ngực và khó thở.',
      'Tôi thấy đau ngực khi ấn vào một điểm.',
      'Bố tôi khó thở, môi tím tái.',
      'Người này bất tỉnh, không thở bình thường.',
      'Tôi bị hóc thức ăn, không nói được và không thở được.',
      'Em bé dưới một tuổi bị sặc sữa.',
      'Tôi vừa bị điện giật.',
    ];
    for (final q in g1TimMach) {
      g1.add(evalSingle(q, category: 'Tim mạch và hô hấp'));
    }

    // Chảy máu và chấn thương
    final g1ChayMau = [
      'Tay tôi bị đứt, chảy máu ít.',
      'Máu ở chân phun thành tia, tôi phải làm gì?',
      'Tôi bị ngã, cổ tay sưng và đau.',
      'Chân tôi có vẻ bị gãy sau khi té.',
      'Tôi bị bong gân cổ chân khi chơi thể thao.',
      'Tôi bị đinh rỉ đâm vào chân.',
      'Răng cửa của tôi vừa bị rơi ra.',
      'Tôi bị chó cắn vào tay.',
    ];
    for (final q in g1ChayMau) {
      g1.add(evalSingle(q, category: 'Chảy máu và chấn thương'));
    }

    // Bỏng và môi trường
    final g1Bong = [
      'Tôi bị bỏng nước sôi ở cánh tay.',
      'Vết bỏng nổi bọng nước, có nên chườm đá không?',
      'Tôi bị say nắng, chóng mặt và nóng ran.',
      'Có người vừa được đưa lên bờ sau khi đuối nước.',
      'Mắt tôi đau sau khi nhìn hồ quang hàn.',
      'Tôi bị rắn cắn ở chân.',
    ];
    for (final q in g1Bong) {
      g1.add(evalSingle(q, category: 'Bỏng và môi trường'));
    }

    // Dị ứng, ngộ độc và bệnh lý khác
    final g1DiUng = [
      'Tôi bị nổi mẩn ngứa sau khi ăn tôm.',
      'Tôi khó thở và sưng môi sau khi bị ong đốt.',
      'Tôi uống nhầm thuốc trừ sâu.',
      'Tôi lỡ uống phải nước tẩy rửa.',
      'Tôi bị kiến ba khoang làm rát da.',
      'Sâu róm chạm vào da tôi, giờ rất ngứa.',
      'Tôi bị đau bụng dữ dội.',
      'Tôi bị đau lưng sau khi bê vật nặng.',
      'Tôi bị gút cấp, ngón chân cái sưng đau.',
      'Huyết áp của tôi đo được 185.',
      'Tôi bị run tay, vã mồ hôi và có bệnh tiểu đường.',
      'Con tôi đang sốt cao.',
      'Trẻ nhỏ nhà tôi sốt và vừa co giật.',
      'Tôi bị ợ nóng sau khi ăn.',
    ];
    for (final q in g1DiUng) {
      g1.add(evalSingle(q, category: 'Dị ứng, ngộ độc và bệnh lý khác'));
    }

    // Sức khỏe tinh thần
    final g1TinhThan = [
      'Tôi đang lên cơn hoảng loạn, tim đập nhanh và khó thở.',
      'Tôi đang rất hoảng sợ, hãy hướng dẫn tôi bình tĩnh lại.',
      'Tôi cảm thấy khủng hoảng tinh thần và không biết phải làm gì.',
    ];
    for (final q in g1TinhThan) {
      g1.add(evalSingle(q, category: 'Sức khỏe tinh thần'));
    }
    results['groups']['group_1'] = g1;

    print('>>> RUNNING GROUP 2: Câu hỏi nhiều triệu chứng — kiểm tra Multi-Triage...');
    final g2Queries = [
      'Tôi bị té ngã, đau đầu và chảy máu ở trán.',
      'Tôi bị tai nạn xe máy, đau ngực và khó thở.',
      'Tôi bị đứt tay sâu, máu chảy nhiều và ngón tay tê.',
      'Tôi bị bỏng nước sôi, nổi bọng nước và rất đau.',
      'Tôi bị chó cắn, vết thương chảy máu và bàn tay sưng.',
      'Tôi bị ngã cầu thang, đau cổ, buồn nôn và chóng mặt.',
      'Tôi bị rắn cắn, chân sưng nhanh và chóng mặt.',
      'Tôi ăn hải sản xong nổi mẩn, sưng môi và khó thở.',
      'Trẻ sốt cao, co giật và sau cơn vẫn chưa tỉnh.',
      'Bạn tôi bị điện giật, bất tỉnh và có vết bỏng ở tay.',
      'Tôi bị đau bụng dữ dội, nôn liên tục và vã mồ hôi.',
      'Tôi bị ngất sau khi chạy ngoài trời nóng, giờ vẫn lú lẫn.',
    ];
    final g2 = <Map<String, dynamic>>[];
    for (final q in g2Queries) {
      g2.add(evalSingle(q, category: 'Multi-Triage'));
    }
    results['groups']['group_2'] = g2;

    print('>>> RUNNING GROUP 3: Câu hỏi làm rõ — kiểm tra hội thoại nhiều lượt...');
    final g3 = <Map<String, dynamic>>[];
    // Đau đầu
    g3.add(evalMultiTurn('Đau đầu', 'Tôi bị đau đầu, cần làm gì?', 'Nguy cơ cao', 'Đau bộc phát rất dữ dội, kèm cứng cổ và nôn.'));
    g3.add(evalMultiTurn('Đau đầu', 'Tôi bị đau đầu, cần làm gì?', 'Nhẹ hơn', 'Đau từ từ, không sốt, không nôn và không yếu liệt.'));

    // Đau ngực
    g3.add(evalMultiTurn('Đau ngực', 'Tôi đang bị đau ngực.', 'Nguy cơ cao', 'Đau như bị đè ép, khó thở và vã mồ hôi.'));
    g3.add(evalMultiTurn('Đau ngực', 'Tôi đang bị đau ngực.', 'Ít điển hình', 'Đau tăng lên khi ấn vào một điểm hoặc xoay người.'));

    // Dị ứng
    g3.add(evalMultiTurn('Dị ứng', 'Tôi bị dị ứng sau khi ăn.', 'Nguy cơ cao', 'Môi sưng, khó thở và choáng.'));
    g3.add(evalMultiTurn('Dị ứng', 'Tôi bị dị ứng sau khi ăn.', 'Nhẹ hơn', 'Chỉ nổi mẩn ngứa ngoài da, vẫn thở bình thường.'));

    // Trẻ sốt
    g3.add(evalMultiTurn('Trẻ sốt', 'Con tôi đang sốt cao.', 'Nguy cơ cao', 'Bé vừa co giật và hiện chưa tỉnh hẳn.'));
    g3.add(evalMultiTurn('Trẻ sốt', 'Con tôi đang sốt cao.', 'Nhẹ hơn', 'Bé vẫn tỉnh, uống được nước và chưa co giật.'));
    results['groups']['group_3'] = g3;

    print('>>> RUNNING GROUP 4: Cách nói dân gian, phương ngữ và viết tắt...');
    final g4Queries = [
      'Bạn tôi bị xỉu, giờ gọi không tỉnh.',
      'Con tôi ngộp nước, vừa được đưa lên bờ.',
      'Mẹ tôi bị điện đánh.',
      'Uống nhầm thuốc sâu rồi, giờ buồn nôn.',
      'Tôi bị phỏng nước sôi.',
      'Bị chó táp vào tay, có cần đi tiêm không?',
      'Ông tôi méo miệng, nói đớ và yếu tay.',
      'Nó bị sặc, không thở ra tiếng.',
      'Tôi đau đầu quá trời, chịu không nổi.',
      'Bị té xe, đầu u một cục với máu chảy tùm lum.',
    ];
    final g4 = <Map<String, dynamic>>[];
    for (final q in g4Queries) {
      g4.add(evalSingle(q, category: 'Dân gian & Phương ngữ'));
    }
    results['groups']['group_4'] = g4;

    print('>>> RUNNING GROUP 5: Câu phủ định và phân biệt mức độ...');
    final g5Queries = [
      'Tôi bị trầy xước nhưng không chảy máu.',
      'Vết thương chảy máu ít, không phun thành tia.',
      'Tôi đau đầu nhưng không sốt, không cứng cổ và không nôn.',
      'Tôi đau ngực nhưng không khó thở, không vã mồ hôi.',
      'Tôi bị dị ứng nhẹ, không sưng môi và vẫn thở bình thường.',
      'Tôi bị bỏng đỏ nhưng da không phồng rộp.',
      'Tôi bị ngã nhưng không đập đầu và không thấy chóng mặt.',
    ];
    final g5 = <Map<String, dynamic>>[];
    for (final q in g5Queries) {
      g5.add(evalSingle(q, category: 'Câu phủ định'));
    }
    results['groups']['group_5'] = g5;

    print('>>> RUNNING GROUP 6: Ngoài chuyên môn và cứu nạn vùng xa...');
    final g6Queries = [
      'Tôi đang ở trên núi, không có thuốc và điện thoại gần hết pin, phải làm sao?',
      'Tôi bị lạc trong rừng, trời sắp tối và không có sóng điện thoại.',
      'Bạn tôi bị gãy chân khi leo núi, đường xuống rất xa.',
      'Tôi đang ở gần khu vực sạt lở, nên di chuyển thế nào?',
      'Chúng tôi ở vùng lũ, có người bị thương và không gọi được mạng.',
      'Tôi đang ở ngoài trời lạnh, quần áo ướt và bắt đầu run liên tục.',
    ];
    final g6 = <Map<String, dynamic>>[];
    for (final q in g6Queries) {
      g6.add(evalSingle(q, category: 'Cứu nạn vùng xa'));
    }
    results['groups']['group_6'] = g6;

    print('>>> RUNNING GROUP 7: Tìm bệnh viện, nhà thuốc và trạm y tế...');
    final g7Queries = [
      'Tìm bệnh viện gần nhất.',
      'Nhà thuốc gần đây ở đâu?',
      'Chỉ đường đến trạm y tế phường gần nhất.',
      'Có bệnh viện nào gần vị trí hiện tại không?',
      'Tôi đang ở [địa danh giả lập], tìm cơ sở y tế gần đây.',
    ];
    final g7 = <Map<String, dynamic>>[];
    for (final q in g7Queries) {
      g7.add(evalSingle(q, category: 'Cơ sở y tế'));
    }
    results['groups']['group_7'] = g7;

    final outFile = File('benchmark_results.json');
    outFile.writeAsStringSync(jsonEncode(results));
    print('>>> BENCHMARK EVALUATION FINISHED! Saved to benchmark_results.json');
  });
}
