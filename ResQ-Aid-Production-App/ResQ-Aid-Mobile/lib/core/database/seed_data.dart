import 'dart:convert';

class SeedProtocols {
  static final List<Map<String, dynamic>> items = [
    {
      'protocol_code': 'PROTO_CARDIAC_ARREST',
      'title': 'Hồi sức Tim phổi Cấp cứu (CPR 110 BPM)',
      'version': 2,
      'approved_by': 'Quyết định 3385/QĐ-BYT & AHA/ERC 2025',
      'status': 'PUBLISHED',
      'content': {
        'target': 'Người lớn & Trẻ em (> 1 tuổi)',
        'quick_summary': 'Ép tim liên tục nhịp độ 110 BPM, sâu 5-6 cm giữa ngực để duy trì tưới máu não.',
        'steps': [
          {
            'step': 1,
            'title': 'Đảm bảo an toàn hiện trường',
            'instruction': 'Quan sát điện hở, nguy cơ sập, cháy nổ, giao thông. Chỉ tiếp cận khi hiện trường an toàn cho bạn.',
            'warning': 'Không tiếp cận nếu hiện trường có nguy cơ rò điện hoặc khí độc.'
          },
          {
            'step': 2,
            'title': 'Kiểm tra phản ứng & Gọi 115',
            'instruction': 'Vỗ mạnh hai vai, gọi to "Anh/Chị có sao không?". Nhờ người gọi 115, tìm máy AED và bật loa ngoài điện thoại.',
            'warning': 'Nếu ở một mình: bật loa ngoài gọi 115 ngay trong lúc ép tim.'
          },
          {
            'step': 3,
            'title': 'Tư thế ép tim chuẩn AHA',
            'instruction': 'Đặt gót bàn tay vào 1/2 dưới xương ức. Đan tay kia lên trên. Khóa thẳng khuỷu tay 90°. Ép sâu 5-6 cm.',
            'warning': 'Để lồng ngực nở hoàn toàn sau mỗi lần ép. Nhịp độ chuẩn 110 lần/phút.'
          },
          {
            'step': 4,
            'title': 'Ép tim liên tục (Hands-only CPR)',
            'instruction': 'Duy trì ép tim liên tục không ngừng quá 10 giây. Đổi người ép mỗi 2 phút để giữ lực ép đủ sâu.',
            'warning': 'Với người đã huấn luyện hoặc ngạt nước: phối hợp 30 lần ép : 2 lần thổi ngạt.'
          }
        ],
        'contraindications': [
          'Không dừng ép tim quá 10 giây trong suốt quá trình cấp cứu.',
          'Không ép lệch sang vùng xương sườn hoặc mũi ức dạ dày.'
        ]
      }
    },
    {
      'protocol_code': 'PROTO_AED',
      'title': 'Sử dụng Máy khử rung tim Ngoài lồng ngực (AED)',
      'version': 2,
      'approved_by': 'Chuẩn ERC 2025 & Hội Cấp cứu Việt Nam',
      'status': 'PUBLISHED',
      'content': {
        'target': 'Nạn nhân ngừng tuần hoàn đột ngột',
        'quick_summary': 'Bật máy AED, dán 2 bản cực theo hình vẽ, tránh xa khi máy phân tích nhịp và phóng điện.',
        'steps': [
          {
            'step': 1,
            'title': 'Mở máy AED & Nghe khẩu lệnh',
            'instruction': 'Bật nút nguồn AED (hoặc mở nắp). Máy sẽ tự phát giọng nói hướng dẫn từng bước.',
            'warning': 'Vẫn duy trì ép tim trong lúc người khác mở máy và chuẩn bị dán bản cực.'
          },
          {
            'step': 2,
            'title': 'Bộc lộ ngực & Dán 2 bản cực',
            'instruction': 'Lau khô ngực nếu ướt. Dán bản cực 1 dưới xương đòn phải, bản cực 2 ở mạng sườn trái dưới nách.',
            'warning': 'Tránh dán đè lên máy tạo nhịp dưới da hoặc miếng dán thuốc.'
          },
          {
            'step': 3,
            'title': 'Tránh xa khi máy phân tích nhịp',
            'instruction': 'Hô to "Tránh xa nạn nhân!". Không ai được chạm vào nạn nhân khi máy đang phân tích nhịp tim.',
            'warning': 'Rung giật do chạm vào người có thể làm máy phân tích sai nhịp tim.'
          },
          {
            'step': 4,
            'title': 'Bấm nút phóng điện (Shock) nếu có chỉ định',
            'instruction': 'Nếu máy báo "Cần sốc điện", đảm bảo mọi người đã lùi ra xa, sau đó bấm nút SỐC nhấp nháy.',
            'warning': 'Ngay sau khi phóng điện, tiếp tục ép tim CPR 110 BPM ngay lập tức.'
          }
        ],
        'contraindications': [
          'Không để bất kỳ ai chạm vào nạn nhân khi máy AED đang phân tích hoặc phóng điện.',
          'Không dùng máy AED trên vũng nước đọng lớn (lau khô hoặc kéo nạn nhân vào chỗ khô).'
        ]
      }
    },
    {
      'protocol_code': 'PROTO_CHOKING',
      'title': 'Sơ cứu Mắc dị vật đường thở (Heimlich)',
      'version': 2,
      'approved_by': 'Quyết định 3385/QĐ-BYT',
      'status': 'PUBLISHED',
      'content': {
        'target': 'Người lớn & Trẻ em',
        'quick_summary': 'Tống dị vật ra khỏi khí quản bằng phản xạ ho hoặc thủ thuật Heimlich.',
        'steps': [
          {
            'step': 1,
            'title': 'Nhận biết dấu hiệu nghẹn',
            'instruction': 'Hỏi to: "Bạn có nghẹn không?". Nếu nạn nhân ho to, nói được -> khuyến khích ho mạnh, KHÔNG can thiệp.',
            'warning': 'Nếu nạn nhân không nói được, ôm cổ, mặt tím tái -> lập tức can thiệp ngay.'
          },
          {
            'step': 2,
            'title': '5 cú vỗ lưng',
            'instruction': 'Đứng chếch phía sau, dùng gót bàn tay vỗ mạnh 5 lần vào giữa hai xương bả vai hướng lên phía trước.',
            'warning': null
          },
          {
            'step': 3,
            'title': 'Thủ thuật Heimlich (5 lần ép bụng)',
            'instruction': 'Vòng tay ra trước bụng, đặt nắm đấm ở giữa rốn và mũi ức, giật mạnh theo hướng VÀO TRONG và LÊN TRÊN.',
            'warning': 'Không ép vào xương ức hay sườn. Với trẻ sơ sinh < 1 tuổi: Dùng 2 ngón tay ấn ngực, không ép bụng.'
          },
          {
            'step': 4,
            'title': 'Xử lý khi nạn nhân bất tỉnh',
            'instruction': 'Nếu nạn nhân ngã gục, bất tỉnh và ngừng thở -> đặt nằm ngửa, bấm nút CPR trên app để ép tim 110 BPM ngay.',
            'warning': 'Tuyệt đối không dùng tay móc họng mù quáng.'
          }
        ],
        'contraindications': [
          'Không vỗ lưng khi nạn nhân đang ho mạnh thành tiếng.',
          'Không ép bụng phụ nữ mang thai hoặc trẻ sơ sinh dưới 1 tuổi (dùng ấn ngực).'
        ]
      }
    },
    {
      'protocol_code': 'PROTO_DROWNING',
      'title': 'Sơ cứu Nạn nhân Đuối nước',
      'version': 2,
      'approved_by': 'Hiệp hội Cứu nạn Quốc tế & AHA 2025',
      'status': 'PUBLISHED',
      'content': {
        'target': 'Mọi lứa tuổi',
        'quick_summary': 'Đưa nạn nhân lên bờ, thông khí khẩn cấp bằng 5 nhịp thổi ngạt trước khi ép tim.',
        'steps': [
          {
            'step': 1,
            'title': 'Đưa lên bờ an toàn',
            'instruction': 'Đảm bảo an toàn cho người cứu hộ. Dùng phao, sào dài. Đưa nạn nhân lên bờ khô ráo, thoáng mát.',
            'warning': 'Không nhảy xuống nước nếu bạn không biết bơi cứu hộ.'
          },
          {
            'step': 2,
            'title': 'Kiểm tra đường thở & làm sạch miệng',
            'instruction': 'Lay vai gọi to, ngửa đầu nâng cằm kiểm tra miệng có bùn đất, rong rêu thì lấy sạch.',
            'warning': 'Tuyệt đối KHÔNG xốc nước kiểu vác nạn nhân chạy quanh (làm trào ngược dịch vào phổi).'
          },
          {
            'step': 3,
            'title': '5 nhịp thổi ngạt đầu tiên',
            'instruction': 'Nếu nạn nhân không thở -> bịt mũi, hít sâu và thổi ngạt 5 lần liên tiếp để nở phổi và cung cấp oxy.',
            'warning': 'Mỗi nhịp thổi khoảng 1 giây, quan sát lồng ngực có phập phồng không.'
          },
          {
            'step': 4,
            'title': 'Ép tim kết hợp thổi ngạt (30:2)',
            'instruction': 'Sau 5 nhịp thổi, nếu vẫn chưa thở -> ép tim 30 nhịp (100-110 BPM) kết hợp 2 nhịp thổi ngạt.',
            'warning': 'Duy trì liên tục đến khi y tế 115 tiếp cận hoặc nạn nhân tự thở lại.'
          }
        ],
        'contraindications': [
          'Không cố xốc nước khỏi bụng hoặc phổi.',
          'Không ngừng ép tim quá 10 giây.'
        ]
      }
    },
    {
      'protocol_code': 'PROTO_STROKE',
      'title': 'Nhận diện & Sơ cứu Đột quỵ Não (Quy tắc F.A.S.T)',
      'version': 2,
      'approved_by': 'Hội Đột quỵ Việt Nam & AHA 2025',
      'status': 'PUBLISHED',
      'content': {
        'target': 'Người lớn & Người cao tuổi',
        'quick_summary': 'Nhận diện theo quy tắc F.A.S.T, ghi nhớ giờ khởi phát và gọi 115 trong "Cửa sổ vàng 4.5h".',
        'steps': [
          {
            'step': 1,
            'title': 'F - Face (Mặt méo, lệch nụ cười)',
            'instruction': 'Yêu cầu bệnh nhân cười hoặc nhe răng. Quan sát xem một bên miệng có bị xệ hoặc méo không.',
            'warning': null
          },
          {
            'step': 2,
            'title': 'A - Arm (Yếu liệt tay chân)',
            'instruction': 'Yêu cầu giơ 2 tay lên cao song song trong 10 giây. Xem 1 tay có bị trôi rơi xuống không.',
            'warning': null
          },
          {
            'step': 3,
            'title': 'S - Speech (Nói ngọng, ú ớ)',
            'instruction': 'Yêu cầu nhắc lại một câu đơn giản. Lắng nghe xem giọng có méo, ngọng, hoặc không nói được không.',
            'warning': null
          },
          {
            'step': 4,
            'title': 'T - Time (Giờ vàng & Gọi 115)',
            'instruction': 'Ghi lại chính xác giờ khởi phát triệu chứng. Đặt bệnh nhân nằm nghiêng an toàn đầu cao 30°.',
            'warning': 'TUYỆT ĐỐI KHÔNG cạo gió, chích máu đầu ngón tay, hoặc cho uống thuốc hạ áp/An Cung.'
          }
        ],
        'contraindications': [
          'CẤM chích nặn máu 10 đầu ngón tay hoặc dái tai.',
          'CẤM cho uống bất kỳ loại thuốc nào kể cả Aspirin hay An Cung khi chưa có phim chụp CT não.'
        ]
      }
    },
    {
      'protocol_code': 'PROTO_SEIZURE',
      'title': 'Sơ cứu Cơn Co giật & Động kinh',
      'version': 2,
      'approved_by': 'Quyết định 3385/QĐ-BYT',
      'status': 'PUBLISHED',
      'content': {
        'target': 'Mọi lứa tuổi',
        'quick_summary': 'Bảo vệ đầu chống va đập, nới lỏng cổ áo, đặt nằm nghiêng khi dứt cơn, cấm nhét vật cứng vào miệng.',
        'steps': [
          {
            'step': 1,
            'title': 'Dọn dẹp vật sắc nhọn quanh nạn nhân',
            'instruction': 'Gạt bỏ bàn ghế, đồ vật sắc nhọn. Đặt khăn mềm hoặc áo dưới đầu để tránh chấn thương sọ não.',
            'warning': 'Không đè chặt hoặc giữ chặt tay chân nạn nhân (gây gãy xương hoặc rách cơ).'
          },
          {
            'step': 2,
            'title': 'Bảo vệ đường thở',
            'instruction': 'Nới lỏng cúc áo, cà vạt quanh cổ. Ghi nhớ thời gian cơn co giật kéo dài.',
            'warning': 'TUYỆT ĐỐI KHÔNG nhét khăn, đũa, ngón tay vào miệng nạn nhân.'
          },
          {
            'step': 3,
            'title': 'Tư thế nằm nghiêng an toàn',
            'instruction': 'Khi hết cơn co cứng -> đặt nạn nhân nằm nghiêng sang một bên để đờm nhớt chảy ra ngoài.',
            'warning': 'Không cho uống nước hoặc sữa khi nạn nhân chưa tỉnh táo hoàn toàn.'
          },
          {
            'step': 4,
            'title': 'Gọi 115 khi co giật kéo dài',
            'instruction': 'Gọi 115 ngay nếu cơn co giật kéo dài trên 5 phút, hoặc có liên tiếp các cơn mà không tỉnh lại.',
            'warning': null
          }
        ],
        'contraindications': [
          'CẤM nhét bất kỳ vật gì vào miệng người đang co giật (nguy cơ gãy răng làm tắc nghẽn đường thở).',
          'CẤM ghì đè ép chặt cơ thể nạn nhân.'
        ]
      }
    },
    {
      'protocol_code': 'PROTO_BURNS',
      'title': 'Sơ cứu Vết Bỏng (Nhiệt, Nước sôi, Hóa chất)',
      'version': 2,
      'approved_by': 'Viện Bỏng Quốc gia & Bộ Y tế',
      'status': 'PUBLISHED',
      'content': {
        'target': 'Mọi lứa tuổi',
        'quick_summary': 'Hạ nhiệt vết bỏng bằng nước sạch mát trong 15-20 phút, che phủ vô khuẩn.',
        'steps': [
          {
            'step': 1,
            'title': 'Tách khỏi nguồn gây bỏng',
            'instruction': 'Dập lửa, ngắt nguồn nhiệt, hoặc cởi bỏ quần áo dính hóa chất/nước sôi nhẹ nhàng.',
            'warning': 'Nếu quần áo bị dính chặt vào da, KHÔNG cố giật ra mà cắt xung quanh.'
          },
          {
            'step': 2,
            'title': 'Ngâm xả nước mát 15-20 phút',
            'instruction': 'Để vết bỏng dưới vòi nước sạch chảy nhẹ nhiệt độ phòng (15-20°C) tối thiểu 15-20 phút.',
            'warning': 'TUYỆT ĐỐI KHÔNG dùng nước đá hoặc đá lạnh trực tiếp (gây co mạch, hoại tử mô).'
          },
          {
            'step': 3,
            'title': 'Che phủ vết thương vô trùng',
            'instruction': 'Bọc nhẹ nhàng vết bỏng bằng gạc vô trùng ẩm hoặc màng bọc thực phẩm sạch.',
            'warning': 'Không quấn quá chặt, không chọc vỡ các bọng nước phồng rộp.'
          },
          {
            'step': 4,
            'title': 'Giữ ấm và chuyển viện',
            'instruction': 'Ủ ấm toàn thân chống sốc nhiệt, cho uống từng ngụm nước ấm nếu tỉnh táo. Chuyển cấp cứu 115.',
            'warning': 'Cấm bôi mỡ trăn, kem đánh răng, nước mắm, trứng gà lên vết bỏng.'
          }
        ],
        'contraindications': [
          'Không chườm đá lạnh trực tiếp.',
          'Không chọc thủng bọng nước.',
          'Không bôi bất kỳ chất lạ nào lên vết bỏng hở.'
        ]
      }
    },
    {
      'protocol_code': 'PROTO_ELECTROCUTION',
      'title': 'Sơ cứu Nạn nhân Bị Điện giật',
      'version': 2,
      'approved_by': 'Quyết định 3385/QĐ-BYT',
      'status': 'PUBLISHED',
      'content': {
        'target': 'Mọi lứa tuổi',
        'quick_summary': 'Ngắt nguồn điện an toàn trước tiên, hồi sức CPR ngay nếu có rung thất/ngừng tim.',
        'steps': [
          {
            'step': 1,
            'title': 'Ngắt nguồn điện khẩn cấp',
            'instruction': 'Ngắt cầu dao, aptomat hoặc dùng gậy gỗ/nhựa khô gạt dây điện ra xa nạn nhân.',
            'warning': 'CỰC KỲ NGUY HIỂM: Tuyệt đối không chạm vào nạn nhân nếu chưa ngắt điện hoàn toàn.'
          },
          {
            'step': 2,
            'title': 'Đánh giá an toàn hiện trường',
            'instruction': 'Kiểm tra xem vùng xung quanh có ẩm ướt, còn điện rò rỉ không trước khi tiếp cận nạn nhân.',
            'warning': 'Không tiếp cận điện cao thế trong phạm vi dưới 10 mét.'
          },
          {
            'step': 3,
            'title': 'Kiểm tra tuần hoàn và hô hấp',
            'instruction': 'Điện giật thường gây rung thất làm ngừng tim đột ngột. Kiểm tra nhịp thở trong tối đa 10 giây.',
            'warning': null
          },
          {
            'step': 4,
            'title': 'CPR 110 BPM ngay lập tức',
            'instruction': 'Nếu bất tỉnh và ngừng thở -> bắt đầu ép tim ngay theo nhịp 110 BPM trên app và gọi 115.',
            'warning': 'Nếu có máy sốc điện AED gần đó, lấy và gắn bản cực ngay.'
          }
        ],
        'contraindications': [
          'Không chạm tay trần vào người nạn nhân khi nguồn điện còn bật.',
          'Không dùng vật dẫn điện (kim loại, cành cây ẩm) để gạt dây điện.'
        ]
      }
    },
    {
      'protocol_code': 'PROTO_ANAPHYLAXIS',
      'title': 'Sơ cứu Sốc phản vệ & Dị ứng Nặng',
      'version': 2,
      'approved_by': 'Thông tư 51/2017/TT-BYT',
      'status': 'PUBLISHED',
      'content': {
        'target': 'Mọi lứa tuổi',
        'quick_summary': 'Đặt nạn nhân nằm ngửa kê cao chân, tiêm bút Epinephrine (nếu có) và gọi 115 khẩn cấp.',
        'steps': [
          {
            'step': 1,
            'title': 'Nhận diện dấu hiệu nguy kịch',
            'instruction': 'Nổi mề đay toàn thân kết hợp khó thở, thở rít, khàn tiếng, sưng môi mắt, chóng mặt tụt huyết áp.',
            'warning': 'Sốc phản vệ diễn tiến cực nhanh gây ngạt thở tử vong trong vài phút.'
          },
          {
            'step': 2,
            'title': 'Tiêm Epipen/Adrenaline (Nếu có sẵn)',
            'instruction': 'Cầm chắc bút tiêm tự động, ấn vuông góc vào mặt ngoài 1/3 giữa đùi. Giữ chặt 3 - 5 giây.',
            'warning': 'Không chần chừ tiêm nếu nạn nhân đã có chỉ định của bác sĩ từ trước.'
          },
          {
            'step': 3,
            'title': 'Tư thế cấp cứu chống sốc',
            'instruction': 'Đặt nạn nhân nằm ngửa, kê chân cao khoảng 30 cm. Nếu khó thở nhiều, cho ngồi tựa nhẹ.',
            'warning': 'KHÔNG cho nạn nhân đứng dậy hoặc đi lại (có thể gây ngừng tim đột ngột do hạ huyết áp).'
          },
          {
            'step': 4,
            'title': 'Sẵn sàng hồi sức CPR',
            'instruction': 'Theo dõi sát nhịp thở. Nếu ngừng thở hoặc mất mạch -> lập tức khởi động CPR 110 BPM.',
            'warning': 'Gọi ngay 115 báo tình trạng "Nghi ngờ sốc phản vệ khẩn cấp".'
          }
        ],
        'contraindications': [
          'Không cho nạn nhân đứng lên hoặc đi bộ.',
          'Không cho uống nước nếu nạn nhân đang nôn mửa hoặc lơ mơ.'
        ]
      }
    },
    {
      'protocol_code': 'PROTO_TRAUMA',
      'title': 'Sơ cứu Chấn thương Chảy máu & Gãy xương',
      'version': 2,
      'approved_by': 'Phác đồ Ngoại viện ATLS & Bộ Y tế',
      'status': 'PUBLISHED',
      'content': {
        'target': 'Mọi lứa tuổi',
        'quick_summary': 'Cầm máu trực tiếp bằng băng ép, cố định bất động chi gãy và cột sống cổ.',
        'steps': [
          {
            'step': 1,
            'title': 'Ép trực tiếp cầm máu',
            'instruction': 'Dùng gạc sạch ép chặt trực tiếp lên vị trí vết thương chảy máu. Giữ liên tục tối thiểu 5-10 phút.',
            'warning': 'Nếu máu thấm qua gạc, đặt thêm lớp gạc mới lên trên, KHÔNG gỡ lớp cũ ra.'
          },
          {
            'step': 2,
            'title': 'Cố định bất động chi gãy',
            'instruction': 'Dùng nẹp cứng (hoặc bìa các-tông, thanh gỗ) lót đệm vải và cố định qua 2 khớp liền kề của xương gãy.',
            'warning': 'Tuyệt đối không cố nắn chỉnh đầu xương bị lệch hoặc thụt vào trong.'
          },
          {
            'step': 3,
            'title': 'Bảo vệ cột sống cổ',
            'instruction': 'Nếu nạn nhân bị tai nạn giao thông, té ngã từ trên cao -> giữ thẳng đầu và cổ, tránh xoay lắc.',
            'warning': 'Không di chuyển nạn nhân trừ khi hiện trường cháy nổ nguy hiểm sắp xảy ra.'
          },
          {
            'step': 4,
            'title': 'Theo dõi sốc và chờ 115',
            'instruction': 'Ủ ấm, nâng cao chân nếu không gãy xương chi dưới. Giữ nạn nhân bình tĩnh.',
            'warning': 'Không cho nạn nhân ăn uống phòng trường hợp cần phẫu thuật cấp cứu tại viện.'
          }
        ],
        'contraindications': [
          'Không tự ý nắn xương gãy tại hiện trường.',
          'Không rút các dị vật nhọn cắm sâu trong cơ thể (chỉ băng cố định quanh dị vật).'
        ]
      }
    },
    {
      'protocol_code': 'PROTO_CUT_BLEEDING',
      'title': 'Sơ cứu Vết Đứt Tay, Rách Da & Chảy Máu Ngoại Biên',
      'version': 2,
      'approved_by': 'Quyết định 3385/QĐ-BYT & Hội Chữ thập đỏ Quốc tế',
      'status': 'PUBLISHED',
      'content': {
        'target': 'Mọi lứa tuổi',
        'quick_summary': 'Đứt tay, vết cắt chảy máu: Ấn chặt gạc sạch 5-10 phút cầm máu, nâng cao chi hơn tim, không đổ cồn trực tiếp vào vết cắt sâu.',
        'steps': [
          {
            'step': 1,
            'title': 'Cầm máu trực tiếp liên tục',
            'instruction': 'Dùng miếng gạc vô trùng hoặc khăn sạch ấn chặt liên tục trực tiếp lên miệng vết đứt tay trong 5 đến 10 phút.',
            'warning': 'Tuyệt đối KHÔNG dỡ gạc ra xem giữa chừng vì sẽ làm rách cục máu đông non vừa hình thành.'
          },
          {
            'step': 2,
            'title': 'Nâng cao chi bị thương hơn tim',
            'instruction': 'Luôn giữ bàn tay hoặc chân bị thương cao hơn mức tim để giảm bớt áp lực dòng máu chảy đến vết thương.',
            'warning': null
          },
          {
            'step': 3,
            'title': 'Vệ sinh mép da an toàn',
            'instruction': 'Rửa nhẹ nhàng vùng da xung quanh vết cắt bằng nước sạch hoặc nước muối sinh lý 0.9%.',
            'warning': 'CẤM đổ cồn 90 độ hoặc oxy già trực tiếp vào vết rách sâu vì làm chết tế bào hạt mô non và phá hủy cục máu đông.'
          },
          {
            'step': 4,
            'title': 'Băng bó chèn ép vừa phải',
            'instruction': 'Nếu máu thấm đỏ đẫm gạc, đặt thêm lớp gạc mới đè lên trên và quấn băng thun cố định vừa phải. Đến trạm y tế khâu nếu vết rách sâu hở miệng > 1cm.',
            'warning': 'Bấm nút Quét Camera AI để đo diện tích và độ sâu mép rách vết thương.'
          }
        ],
        'contraindications': [
          'Không đổ cồn 90 độ hay oxy già trực tiếp vào lòng vết cắt sâu.',
          'Không đắp bột than, thuốc lào, lá cây chưa tiệt trùng lên miệng vết thương hở.'
        ]
      }
    },
    {
      'protocol_code': 'PROTO_MENTAL_CRISIS',
      'title': 'Hỗ trợ Cấp cứu Khủng hoảng Tâm thần & Rối loạn Thần kinh',
      'version': 2,
      'approved_by': 'Viện Sức khỏe Tâm thần Quốc gia & WHO',
      'status': 'PUBLISHED',
      'content': {
        'target': 'Người lớn, thanh thiếu niên',
        'quick_summary': 'Thần kinh, hoảng loạn cấp: Tạo không gian an toàn, kỹ thuật thở 4-4-4, tiếp đất 5-4-3-2-1, lắng nghe không phán xét và gọi 115 / 19009095.',
        'steps': [
          {
            'step': 1,
            'title': 'Đảm bảo không gian an toàn & bình tĩnh',
            'instruction': 'Đưa người bệnh vào không gian yên tĩnh, thoáng khí. Cất các vật sắc nhọn, dễ vỡ. Giữ khoảng cách an toàn nếu người bệnh đang kích động.',
            'warning': 'Không tranh cãi, quát tháo hay khiêu khích người đang trong cơn hoảng loạn hoặc ảo giác.'
          },
          {
            'step': 2,
            'title': 'Kỹ thuật thở điều hòa nhịp tim (Box Breathing 4-4-4)',
            'instruction': 'Hướng dẫn người bệnh hít sâu bằng mũi trong 4 giây, giữ hơi 4 giây, và thở ra thật chậm bằng miệng trong 4 giây để kích hoạt hệ phó giao cảm.',
            'warning': null
          },
          {
            'step': 3,
            'title': 'Kỹ thuật tiếp đất 5-4-3-2-1 cắt cơn hoảng loạn',
            'instruction': 'Nhắc người bệnh cùng gọi tên: 5 đồ vật nhìn thấy, 4 đồ vật chạm được, 3 âm thanh nghe thấy, 2 mùi hương cảm nhận, và uống 1 ngụm nước ấm.',
            'warning': null
          },
          {
            'step': 4,
            'title': 'Kết nối hỗ trợ y tế chuyên khoa khẩn cấp',
            'instruction': 'Nếu người bệnh có ý định tự hại bản thân, hoang tưởng kích động mạnh hoặc mất kiểm soát hành vi, hãy liên hệ ngay Tổng đài Quốc gia 19009095 hoặc gọi 115.',
            'warning': 'Luôn có người túc trực bên cạnh người bệnh trong suốt cơn khủng hoảng.'
          }
        ],
        'contraindications': [
          'CẤM trói ghì bạo lực nếu không có nhân viên y tế chuyên trách.',
          'CẤM để nạn nhân ở một mình bên cửa sổ tầng cao, ban công hoặc nơi có vật dụng nguy hiểm.'
        ]
      }
    },
    {
      'protocol_code': 'PROTO_HEART_ATTACK',
      'title': 'Sơ cứu Cơn Đau Thắt Ngực & Nhồi Máu Cơ Tim Cấp',
      'version': 2,
      'approved_by': 'Hội Tim mạch học Việt Nam & AHA 2025',
      'status': 'PUBLISHED',
      'content': {
        'target': 'Người lớn & Người cao tuổi',
        'quick_summary': 'Đau ngực dữ dội đè ép lan lên vai/hàm: Cho ngồi tựa 45°, nới lỏng áo, gọi 115 ngay và chuẩn bị ép tim nếu mất mạch.',
        'steps': [
          {
            'step': 1,
            'title': 'Nghỉ ngơi tuyệt đối ở tư thế Fowler',
            'instruction': 'Cho bệnh nhân ngồi tựa lưng góc 45° hoặc nửa nằm nửa ngồi, co nhẹ đầu gối. Tuyệt đối ngừng mọi hoạt động đi lại.',
            'warning': 'Không để bệnh nhân tự đi bộ hay gắng sức vì sẽ làm tăng diện tích hoại tử cơ tim.'
          },
          {
            'step': 2,
            'title': 'Nới lỏng y phục & thông thoáng khí',
            'instruction': 'Cởi bớt nút áo, nới lỏng thắt lưng, mở cửa sổ phòng cho thoáng khí. Trấn an giúp bệnh nhân bớt hoảng sợ.',
            'warning': null
          },
          {
            'step': 3,
            'title': 'Dùng thuốc cá nhân nếu có chỉ định bác sĩ',
            'instruction': 'Nếu bệnh nhân đã được bác sĩ tim mạch kê đơn từ trước: cho ngậm dưới lưỡi viên Nitroglycerin hoặc nhai 1 viên Aspirin 300mg.',
            'warning': 'Không dùng Nitroglycerin nếu huyết áp thấp hoặc đang chóng mặt hoa mắt.'
          },
          {
            'step': 4,
            'title': 'Gọi 115 khẩn cấp & Chuẩn bị CPR',
            'instruction': 'Báo cấp cứu 115 ca "Nghi ngờ nhồi máu cơ tim cấp". Theo dõi sát nhịp thở. Nếu bệnh nhân bất tỉnh ngưng thở -> ép tim 110 BPM ngay lập tức.',
            'warning': 'Mỗi phút trôi qua là một phần cơ tim bị hoại tử không thể phục hồi.'
          }
        ],
        'contraindications': [
          'CẤM cạo gió, giác hơi, chích lể ngón tay làm mất thời gian vàng tái tưới máu cơ tim.',
          'CẤM để bệnh nhân tự lái xe hoặc đi xe máy đến bệnh viện.'
        ]
      }
    },
    {
      'protocol_code': 'PROTO_POISONING',
      'title': 'Sơ cứu Ngộ Độc Thực Phẩm & Hóa Chất Đường Tiêu Hóa',
      'version': 2,
      'approved_by': 'Trung tâm Chống độc Bệnh viện Bạch Mai & Bộ Y tế',
      'status': 'PUBLISHED',
      'content': {
        'target': 'Mọi lứa tuổi',
        'quick_summary': 'Ngộ độc, uống nhầm hóa chất: Xác định chất độc, KHÔNG gây nôn nếu uống axit/bazơ ăn mòn, bù nước và giữ vỏ bao bì đi viện.',
        'steps': [
          {
            'step': 1,
            'title': 'Nhận diện chất độc & Kiểm tra tri giác',
            'instruction': 'Tìm kiếm chai lọ hóa chất, thuốc uống dở hoặc thức ăn ôi thiu nghi vấn. Kiểm tra nạn nhân còn tỉnh táo hay lơ mơ.',
            'warning': 'Nếu nạn nhân bất tỉnh hoặc co giật -> TUYỆT ĐỐI KHÔNG GÂY NÔN.'
          },
          {
            'step': 2,
            'title': 'Xử trí đúng theo bản chất chất độc',
            'instruction': 'Nếu là thực phẩm thông thường và còn tỉnh: cho uống nhiều nước ấm rồi móc họng kích thích nôn. Nếu là axit, nước tẩy bồn cầu, bazơ, xăng dầu: CẤM GÂY NÔN (axit trào ngược sẽ làm bỏng nát thực quản).',
            'warning': 'Tuyệt đối không uống nước chanh/giấm để trung hòa axit hoặc kiềm.'
          },
          {
            'step': 3,
            'title': 'Bù nước & Than hoạt tính nếu có',
            'instruction': 'Cho uống từng ngụm dung dịch Oresol hoặc nước ấm bù điện giải. Nếu có thuốc than hoạt tính trong tủ thuốc gia đình, cho uống theo liều hướng dẫn.',
            'warning': null
          },
          {
            'step': 4,
            'title': 'Bảo tồn mẫu vật & Chuyển cấp cứu 115',
            'instruction': 'Gom toàn bộ vỏ chai thuốc, nhãn mác hóa chất hoặc mẫu thức ăn đem theo cùng nạn nhân đến trung tâm chống độc.',
            'warning': 'Bác sĩ cần vỏ thuốc để xác định thuốc giải độc đặc hiệu (Antidote).'
          }
        ],
        'contraindications': [
          'CẤM gây nôn khi nạn nhân uống phải hóa chất ăn mòn, xăng dầu, thuốc trừ sâu paraquat.',
          'CẤM cho nạn nhân đang co giật hoặc hôn mê uống bất kỳ chất lỏng nào.'
        ]
      }
    },
    {
      'protocol_code': 'PROTO_SNAKE_BITE',
      'title': 'Sơ cứu Nạn nhân Bị Rắn Độc Cắn & Côn Trùng Đốt',
      'version': 2,
      'approved_by': 'Quyết định 3385/QĐ-BYT & WHO Guidelines',
      'status': 'PUBLISHED',
      'content': {
        'target': 'Mọi lứa tuổi',
        'quick_summary': 'Rắn độc cắn, ong đốt: Bất động chi thấp hơn tim, cởi trang sức, cấm rạch rọc hút nọc hay garo thắt chặt, chuyển cấp cứu tiêm huyết thanh.',
        'steps': [
          {
            'step': 1,
            'title': 'Rời khỏi phạm vi tấn công an toàn',
            'instruction': 'Đưa nạn nhân ra xa con rắn. Nhắc nạn nhân ngồi yên bất động hoàn toàn. Cố gắng ghi nhớ hình dáng, màu sắc hoặc chụp ảnh con rắn nếu an toàn.',
            'warning': 'Vận động mạnh làm tim đập nhanh và nọc độc phát tán vào tuần hoàn nhanh gấp nhiều lần.'
          },
          {
            'step': 2,
            'title': 'Tháo bỏ trang sức & Bất động chi',
            'instruction': 'Tháo nhẫn, đồng hồ, vòng tay trước khi vùng bị cắn sưng nề hoại tử. Dùng nẹp cố định chi và luôn giữ vị trí vết cắn THẤP HƠN tim.',
            'warning': 'TUYỆT ĐỐI KHÔNG garo thắt nghẽn mạch máu (gây tắc dòng máu làm hoại tử cụt chi).'
          },
          {
            'step': 3,
            'title': 'Vệ sinh nhẹ nhàng vết thương',
            'instruction': 'Rửa nhẹ vết cắn bằng nước sạch và xà phòng loãng. Băng ép nhẹ nhàng bằng gạc sạch vô trùng.',
            'warning': 'CẤM rạch rọc chữ thập, CẤM dùng miệng hút nọc, CẤM đắp lá cây hay than thuốc dân gian.'
          },
          {
            'step': 4,
            'title': 'Chuyển gấp đến bệnh viện có huyết thanh kháng nọc',
            'instruction': 'Gọi 115 hoặc dùng xe cá nhân chở nạn nhân ở tư thế nằm bất động đến bệnh viện gần nhất có huyết thanh kháng nọc độc.',
            'warning': 'Nếu xuất hiện sụp mí mắt, khó thở, chảy máu chân răng -> báo ngay cho nhân viên y tế.'
          }
        ],
        'contraindications': [
          'CẤM rạch da, giác hút hoặc dùng miệng hút nọc.',
          'CẤM garo mạch máu kiểu cổ điển.',
          'CẤM đắp lá thuốc, bùn đất lên vết rắn cắn.'
        ]
      }
    },
    {
      'protocol_code': 'PROTO_HEAT_STROKE',
      'title': 'Sơ cứu Say Nắng, Say Nóng & Sốc Nhiệt Cấp (Heat Stroke)',
      'version': 2,
      'approved_by': 'Bộ Y tế & Hội Y học Lao động Việt Nam',
      'status': 'PUBLISHED',
      'content': {
        'target': 'Mọi lứa tuổi',
        'quick_summary': 'Say nắng, sốc nhiệt: Đưa vào bóng mát, cởi bớt áo, chườm nước mát vùng cổ/nách/bẹn và quạt thông gió hạ nhiệt khẩn cấp.',
        'steps': [
          {
            'step': 1,
            'title': 'Di chuyển ngay vào nơi râm mát',
            'instruction': 'Đưa nạn nhân rời khỏi ánh nắng trực tiếp vào phòng điều hòa mát, bóng cây râm hoặc nơi thoáng gió.',
            'warning': 'Nhiệt độ cơ thể > 40°C gây tổn thương não và suy đa tạng không thể hồi phục.'
          },
          {
            'step': 2,
            'title': 'Cởi bớt quần áo & Nới lỏng thắt lưng',
            'instruction': 'Cởi bỏ áo khoác ngoài, nới rộng thắt lưng, tất, giày để bề mặt da tiếp xúc tối đa với luồng không khí mát.',
            'warning': null
          },
          {
            'step': 3,
            'title': 'Chườm mát hạ nhiệt chủ động',
            'instruction': 'Đặt khăn ướt mát lên trán, hai bên cổ, hai hõm nách và hai bên bẹn (nơi có các mạch máu lớn chạy nông dưới da). Dùng quạt thổi nhẹ.',
            'warning': 'Không ngâm cả người nạn nhân vào bồn nước đá lạnh vì gây co mạch ngoại vi cản trở thoát nhiệt.'
          },
          {
            'step': 4,
            'title': 'Bù nước điện giải & Chuyển viện',
            'instruction': 'Nếu còn tỉnh táo: cho uống từng ngụm nhỏ nước mát pha Oresol hoặc nước khoáng. Nếu hôn mê lơ mơ, sốt cao co giật -> chuyển ngay 115.',
            'warning': 'Không dùng thuốc hạ sốt Paracetamol vì thuốc không có tác dụng với sốc nhiệt do môi trường.'
          }
        ],
        'contraindications': [
          'Không cho uống nước đá quá lạnh đột ngột khi đang kiệt sức.',
          'Không tự ý truyền dịch tại nhà nếu không có nhân viên y tế.'
        ]
      }
    },
    {
      'protocol_code': 'PROTO_ASTHMA',
      'title': 'Sơ cứu Cơn Hen Phế Quản Cấp (Hen Suyễn) & Khó Thở',
      'version': 2,
      'approved_by': 'Hội Hô hấp Việt Nam & GINA 2024',
      'status': 'PUBLISHED',
      'content': {
        'target': 'Mọi lứa tuổi',
        'quick_summary': 'Khó thở, thở rít, lên cơn hen: Ngồi cúi nhẹ ra trước, dùng bình xịt định liều Salbutamol/Ventolin và gọi 115 nếu tím tái.',
        'steps': [
          {
            'step': 1,
            'title': 'Tư thế ngồi cúi nhẹ ra trước',
            'instruction': 'Cho bệnh nhân ngồi thẳng trên ghế, hai tay chống nhẹ lên đầu gối hoặc mặt bàn để lồng ngực và cơ hô hấp phụ giãn nở tốt nhất.',
            'warning': 'TUYỆT ĐỐI KHÔNG để bệnh nhân nằm ngửa vì sẽ làm tăng cảm giác ngạt thở.'
          },
          {
            'step': 2,
            'title': 'Sử dụng bình xịt cắt cơn cấp cứu',
            'instruction': 'Lấy bình xịt Ventolin/Salbutamol của bệnh nhân, lắc đều, xịt 2 đến 4 nhát hít sâu qua buồng đệm (hoặc ngậm trực tiếp). Lặp lại sau 10-15 phút nếu chưa cắt cơn.',
            'warning': null
          },
          {
            'step': 3,
            'title': 'Thông thoáng không khí xung quanh',
            'instruction': 'Mở cửa sổ cho gió lưu thông, đưa bệnh nhân tránh xa khói thuốc lá, phấn hoa, lông thú cưng, bụi bẩn hoặc mùi hương nồng.',
            'warning': null
          },
          {
            'step': 4,
            'title': 'Gọi 115 khi có dấu hiệu nguy kịch',
            'instruction': 'Nếu bệnh nhân nói ngắt quãng từng từ, môi và đầu ngón tay tím tái, thuốc xịt không còn tác dụng -> gọi ngay 115 cấp cứu suy hô hấp.',
            'warning': 'Sẵn sàng tư thế CPR nếu bệnh nhân kiệt sức ngưng thở.'
          }
        ],
        'contraindications': [
          'CẤM bắt bệnh nhân nằm ngửa.',
          'CẤM dùng thuốc an thần hay giảm đau nhóm Opioid trong cơn hen cấp.'
        ]
      }
    },
    {
      'protocol_code': 'PROTO_HYPOGLYCEMIA',
      'title': 'Xử trí Cấp cứu Tụt Đường Huyết (Hạ Đường Huyết)',
      'version': 2,
      'approved_by': 'Hội Đái tháo đường & Nội tiết Việt Nam',
      'status': 'PUBLISHED',
      'content': {
        'target': 'Người bệnh tiểu đường & người nhịn ăn',
        'quick_summary': 'Run tay, đói lả, vã mồ hôi lạnh: Quy tắc 15-15, uống ngay 15g đường hấp thu nhanh (1/2 cốc nước đường hoặc 3-4 viên kẹo), nghỉ 15 phút.',
        'steps': [
          {
            'step': 1,
            'title': 'Nhận diện triệu chứng tụt đường huyết',
            'instruction': 'Bệnh nhân cảm thấy đói cồn cào, run rẩy tay chân, vã mồ hôi lạnh, tim đập nhanh hồi hộp, hoa mắt choáng váng.',
            'warning': 'Hạ đường huyết kéo dài gây hôn mê tổn thương não không phục hồi.'
          },
          {
            'step': 2,
            'title': 'Bổ sung ngay 15g Carbohydrate hấp thu nhanh (Quy tắc 15)',
            'instruction': 'Nếu còn tỉnh táo: Cho uống 1/2 cốc nước đường ấm, hoặc 1/2 lon nước ngọt có đường (không dùng loại ăn kiêng/Zero), hoặc ăn 3-4 viên kẹo ngọt.',
            'warning': 'Nếu bệnh nhân lơ mơ, hôn mê -> TUYỆT ĐỐI KHÔNG ĐỔ NƯỚC ĐƯỜNG VÀO MIỆNG (gây sặc vào phổi).'
          },
          {
            'step': 3,
            'title': 'Nghỉ ngơi 15 phút & Đo lại đường huyết',
            'instruction': 'Để người bệnh ngồi nghỉ yên tĩnh 15 phút. Dùng máy đo đường huyết cá nhân kiểm tra lại xem chỉ số đã lên > 4.0 mmol/L (70 mg/dL) chưa.',
            'warning': 'Nếu sau 15 phút vẫn chưa tỉnh táo, lặp lại thêm một liều 15g đường.'
          },
          {
            'step': 4,
            'title': 'Ăn nhẹ bữa phụ duy trì ổn định',
            'instruction': 'Khi người bệnh đã tỉnh táo hoàn toàn, cho ăn thêm một lát bánh mì, một bát cháo hoặc bánh quy để giữ đường huyết không bị tụt lại.',
            'warning': 'Nếu bệnh nhân hôn mê bất tỉnh -> tiêm Glucagon nếu có hoặc gọi 115 đưa đi cấp cứu ngay.'
          }
        ],
        'contraindications': [
          'CẤM nhét thức ăn hay đổ chất lỏng vào miệng người bệnh đang bất tỉnh.',
          'Không dùng các loại đồ ngọt chứa nhiều chất béo (socola, sữa đặc) trong lúc cấp cứu vì mỡ làm chậm hấp thu đường.'
        ]
      }
    },
    {
      'protocol_code': 'PROTO_HEAD_INJURY',
      'title': 'Sơ cứu Chấn Thương Sọ Não & Chấn Động Đầu',
      'version': 2,
      'approved_by': 'Hội Phẫu thuật Thần kinh Việt Nam & ATLS',
      'status': 'PUBLISHED',
      'content': {
        'target': 'Mọi lứa tuổi',
        'quick_summary': 'Đập đầu, chảy máu đầu: Cố định thẳng trục đầu cổ, băng nhẹ vết rách da đầu, theo dõi nôn vọt và chuyển viện chụp CT Scanner.',
        'steps': [
          {
            'step': 1,
            'title': 'Cố định thẳng trục đầu và cột sống cổ',
            'instruction': 'Giữ đầu nạn nhân thẳng hàng với thân mình, không quay lắc đầu cổ. Chèn hai túi cát hoặc hai chiếc áo cuộn chặt hai bên tai.',
            'warning': 'Luôn giả định có chấn thương cột sống cổ đi kèm cho đến khi được loại trừ.'
          },
          {
            'step': 2,
            'title': 'Băng nhẹ nhàng cầm máu vết rách da đầu',
            'instruction': 'Dùng gạc sạch băng ép nhẹ lên vết thương rách da đầu để cầm máu. Nếu sờ thấy hộp sọ bị lún hoặc có dị vật cắm vào, chỉ băng xung quanh chứ không ấn mạnh.',
            'warning': 'Tuyệt đối KHÔNG cố rút dị vật nhọn cắm sâu vào hộp sọ.'
          },
          {
            'step': 3,
            'title': 'Theo dõi các dấu hiệu báo động đỏ',
            'instruction': 'Quan sát các dấu hiệu nguy kịch: Bệnh nhân nôn vọt nhiều lần, đồng tử hai mắt to nhỏ không đều, lơ mơ ú ớ, chảy máu hoặc dịch trong qua mũi/lỗ tai.',
            'warning': null
          },
          {
            'step': 4,
            'title': 'Chuyển cấp cứu đến bệnh viện có chuyên khoa Ngoại thần kinh',
            'instruction': 'Gọi 115 đưa nạn nhân đi chụp cắt lớp vi tính (CT Scanner) sọ não. Theo dõi sát tri giác trong 48 giờ đầu.',
            'warning': 'CẤM cho uống thuốc giảm đau mạnh hoặc thuốc an thần vì làm che lấp triệu chứng tri giác.'
          }
        ],
        'contraindications': [
          'CẤM rung lắc hoặc cho nạn nhân ngồi dậy đi lại.',
          'CẤM bịt chặt lỗ tai hay lỗ mũi khi thấy dịch trong hoặc máu chảy ra (làm tăng áp lực nội sọ).'
        ]
      }
    },
    {
      'protocol_code': 'PROTO_NOSEBLEED',
      'title': 'Sơ cứu Chảy Máu Cam (Xuất Huyết Mũi)',
      'version': 2,
      'approved_by': 'Hội Tai Mũi Họng Việt Nam',
      'status': 'PUBLISHED',
      'content': {
        'target': 'Mọi lứa tuổi',
        'quick_summary': 'Chảy máu cam: Ngồi thẳng cúi nhẹ đầu về phía trước, bóp chặt hai cánh mũi trong 10-15 phút, cấm ngửa đầu ra sau.',
        'steps': [
          {
            'step': 1,
            'title': 'Ngồi thẳng và cúi nhẹ đầu về phía trước',
            'instruction': 'Cho nạn nhân ngồi thẳng lưng trên ghế, đầu hơi cúi về phía trước để máu chảy ra ngoài cửa mũi. Nhổ máu trong miệng ra chứ không nuốt.',
            'warning': 'TUYỆT ĐỐI KHÔNG ngửa đầu ra sau (làm máu chảy ngược vào họng gây nôn ói, sặc vào đường thở).'
          },
          {
            'step': 2,
            'title': 'Bóp chặt hai cánh mũi trong 10 đến 15 phút',
            'instruction': 'Dùng ngón tay cái và ngón tay trỏ bóp chặt phần mềm của hai cánh mũi áp sát vào vách ngăn mũi. Thở đều bằng miệng.',
            'warning': 'Giữ liên tục tối thiểu 10 phút, không thả tay ra ngó nghiêng giữa chừng.'
          },
          {
            'step': 3,
            'title': 'Chườm mát vùng sống mũi và trán',
            'instruction': 'Đặt một khăn mát hoặc túi nước đá bọc vải lên gốc sống mũi để hỗ trợ co các mao mạch niêm mạc mũi.',
            'warning': null
          },
          {
            'step': 4,
            'title': 'Đến cơ sở y tế nếu máu không cầm sau 20 phút',
            'instruction': 'Nếu sau 2 lần bóp mũi 15 phút mà máu vẫn chảy đỏ tươi, hoặc chảy máu cam sau va đập mạnh vùng mặt, hãy đến bệnh viện khám cầm máu chuyên khoa.',
            'warning': 'Sau khi cầm máu, không xì mũi mạnh hoặc ngoáy mũi trong vòng 24 giờ.'
          }
        ],
        'contraindications': [
          'CẤM ngửa đầu ra sau khi bị chảy máu cam.',
          'CẤM nhét giấy vệ sinh, bông gòn khô hoặc các loại lá cây vụn vào lỗ mũi (gây nhiễm trùng niêm mạc).'
        ]
      }
    }
  ];

  static String getJsonString(Map<String, dynamic> content) {
    return jsonEncode(content);
  }
}
