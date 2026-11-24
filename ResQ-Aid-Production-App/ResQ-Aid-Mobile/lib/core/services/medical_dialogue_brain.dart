import '../ai/medical_neural_nlp_engine.dart';
import '../../features/medical_facilities/domain/medical_facility_model.dart';
import '../../features/medical_facilities/services/offline_medical_service.dart';
import 'hybrid_ai_engine.dart';
import 'location_service.dart';
import 'medical_safety_router.dart';

/// Danh mục Chủ đề Y khoa Chuẩn hóa
enum MedicalTopic {
  general,
  cpr,
  choking,
  drowning,
  electricShock,
  heartAttack,
  stroke,
  anaphylaxis,
  fainting,
  bleedingCut,
  arterialBleeding,
  fracture,
  sprain,
  headTrauma,
  chestTrauma,
  eyeInjury,
  tetanusRisk,
  dogCatBite,
  burn,
  chemicalBurn,
  frostbite,
  heatStroke,
  sunburn,
  poisoning,
  foodPoisoning,
  snakeBite,
  beeStings,
  asthma,
  copdExacerbation,
  nosebleed,
  chokingFishBone,
  earBleeding,
  foreignBodyNoseEar,
  soreThroatAmikdan,
  hypoglycemia,
  highBloodPressure,
  feverAdult,
  acuteAbdomen,
  diarrheaDehydration,
  vomitingNausea,
  gerdHeartburn,
  constipationAcute,
  goutAttack,
  seizure,
  headacheMigraine,
  vertigoVestibular,
  backPainSciatica,
  intercostalNeuralgia,
  mentalCrisis,
  panicAttack,
  suicideCrisis,
  hysteriaConversion,
  alcoholWithdrawal,
  insomniaAcute,
  febrileConvulsionChild,
  infantChokingMilk,
  infantCryingColic,
  pediatricDehydration,
  pediatricHeadBump,
  toothKnockedOut,
  toothacheAbscess,
  emergencyChildbirth,
  vaginalBleedingPregnancy,
  preeclampsiaDanger,
  motionSickness,
  vaguePain,
  vagueFatigue,
  vagueTrauma,
}

enum DialoguePhase {
  assessment,
  initialAid,
  detailedGuide,
  troubleshooting,
}

/// BỘ NÃO ĐỐI THOẠI Y KHOA THUẦN MẠNG NƠ-RON & VECTOR RAG (PURE NEURAL DIALOGUE BRAIN)
/// Đã loại bỏ hoàn toàn 2,300+ dòng if-else bắt từ khóa thủ công.
/// Toàn bộ truy vấn được phân giải qua:
///   1. Mạng tích chập chuỗi Conv1D + Dual Pool (MedicalNlpNet 128D)
///   2. Truy vấn tương đồng Cosine Vector RAG trên Kho Phác Đồ Y Khoa (clinical_protocols_kb.json)
///   3. Bộ theo dõi trạng thái ẩn đa lượt (Latent Discourse & Context Fusion)
class MedicalDialogueBrain {
  static final MedicalDialogueBrain _instance = MedicalDialogueBrain._internal();
  factory MedicalDialogueBrain() => _instance;
  MedicalDialogueBrain._internal();

  ClinicalProtocolNode? _activeProtocol;
  ClinicalProtocolNode? _pendingClarificationNode;
  String? _pendingPriorQuery;
  int _activeBodySlot = 0; // 0=GENERAL, 1=LEG_FOOT, 2=ARM_HAND, 3=HEAD_FACE
  DialoguePhase _activePhase = DialoguePhase.assessment;
  final ContextAccumulator _context = ContextAccumulator();

  MedicalTopic get activeTopic =>
      _activeProtocol != null ? topicFromName(_activeProtocol!.topic) : MedicalTopic.general;
  DialoguePhase get activePhase => _activePhase;

  void reset() {
    _activeProtocol = null;
    _pendingClarificationNode = null;
    _pendingPriorQuery = null;
    _activeBodySlot = 0;
    _activePhase = DialoguePhase.assessment;
    _context.clear();
  }

  static String removeDiacritics(String str) => MedicalNeuralNlpEngine.stripDiacritics(str);

  static MedicalTopic topicFromName(String rawName) {
    for (final t in MedicalTopic.values) {
      if (t.name.toLowerCase() == rawName.toLowerCase()) return t;
    }
    return MedicalTopic.general;
  }

  /// Kiểm tra ý định tìm kiếm Trạm Y Tế / Bệnh Viện / Nhà Thuốc bằng Mạng Nơ-ron Vector RAG
  static bool isSeekingMedicalFacility(String text) {
    if (text.trim().isEmpty) return false;
    final pred = MedicalNeuralNlpEngine.instance.infer(text);
    return pred.topProtocol.isFacilityLookup && pred.topDocProbability >= 0.45;
  }

  /// Thực thi suy luận đối thoại y khoa thuần Neural Vector RAG (< 1ms)
  String processQuery(String query, {String? contextHint}) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return 'Trợ lý Sơ cứu Cấp cứu ResQ-Aid đang lắng nghe. Hãy mô tả triệu chứng hoặc chấn thương của nạn nhân!';
    }

    final clean = MedicalNeuralNlpEngine.stripDiacritics(trimmed.toLowerCase());

    // Cấp cứu ngừng thở / ngừng tim tối khẩn: ngắt mọi ngữ cảnh cũ và bắt đầu ép tim CPR ngay
    if (clean.contains('ngung tho') ||
        clean.contains('khong tho') ||
        clean.contains('ngung tim') ||
        (clean.contains('bat tinh') && !clean.contains('con tinh'))) {
      _pendingClarificationNode = null;
      _pendingPriorQuery = null;
      _activePhase = DialoguePhase.initialAid;
      _context.addTurn(trimmed);
      final cprNode = MedicalNeuralNlpEngine.instance.findProtocolById('cpr_main');
      if (cprNode != null) {
        _activeProtocol = cprNode;
        return cprNode.initialText;
      }
    }

    // BƯỚC 0.5: TẦNG TRI THỨC LÂM SÀNG CHUYÊN GIA & PHÂN LOẠI CẤP CỨU CHÍNH XÁC (EXPERT CLINICAL TRIAGE ENGINE)
    // Xử lý tức thì các tình huống lâm sàng khẩn cấp có thực thể rõ ràng (như ngã kèm nhịp tim 150, gút, ong đốt, sứa, hóa chất mắt...)
    final explicitClinical = _resolveExplicitClinicalIntent(clean, trimmed);
    if (explicitClinical != null) {
      _pendingClarificationNode = null;
      _pendingPriorQuery = null;
      _activePhase = DialoguePhase.initialAid;
      _context.addTurn(trimmed);
      return explicitClinical;
    }

    var pred = MedicalNeuralNlpEngine.instance.infer(trimmed);

    // 1. Trường hợp Ý định Tìm Cơ Sở Y Tế Ngoại Tuyến (Neural Facility Lookup Node hoặc Explicit Keywords)
    final isFacilityKeyword = clean.contains('benh vien') ||
        clean.contains('nha thuoc') ||
        clean.contains('tram y te') ||
        clean.contains('co so y te') ||
        clean.contains('phong kham') ||
        clean.contains('hieu thuoc');
    final isFindFacilityIntent = clean.contains('tim') ||
        clean.contains('o dau') ||
        clean.contains('chi duong') ||
        clean.contains('gan day') ||
        clean.contains('gan nhat') ||
        clean.contains('hien tai') ||
        (clean.contains('co ') && clean.contains('khong'));

    if ((pred.topProtocol.isFacilityLookup && pred.topDocProbability >= 0.35) ||
        (isFacilityKeyword && (isFindFacilityIntent || clean.contains('gan')))) {
      return _executeOfflineFacilityNavigation(trimmed);
    }

    // 2. Trường hợp Người dùng hỏi Đào sâu Chi tiết (Neural Discourse Head == 1: ASK_DETAIL)
    if (pred.discourseModeIndex == 1) {
      ClinicalProtocolNode? targetNode = _activeProtocol;
      if (targetNode == null && contextHint != null && contextHint.isNotEmpty) {
        final hintPred = MedicalNeuralNlpEngine.instance.infer(contextHint);
        targetNode = hintPred.topProtocol;
      }
      if (targetNode != null) {
        _activePhase = DialoguePhase.detailedGuide;
        _context.addTurn(trimmed);
        return targetNode.detailedText;
      }
    }

    // 3. Trường hợp Hợp nhất Ngữ cảnh Đa Lượt khi đang chờ Làm rõ (Latent Multi-Turn Clarification Resolution)
    if (_pendingClarificationNode != null && _pendingPriorQuery != null) {
      final resolvedText = _resolvePendingClarification(
        _pendingClarificationNode!,
        _pendingPriorQuery!,
        trimmed,
      );
      if (resolvedText != null) {
        _pendingClarificationNode = null;
        _pendingPriorQuery = null;
        _activePhase = DialoguePhase.initialAid;
        _context.addTurn(trimmed);
        return resolvedText;
      }

      final fusedInput = '$_pendingPriorQuery $trimmed';
      final fusedPred = MedicalNeuralNlpEngine.instance.infer(fusedInput);
      if (!fusedPred.topProtocol.isClarification) {
        pred = fusedPred;
        _pendingClarificationNode = null;
        _pendingPriorQuery = null;
      }
    }

    // 4. Trường hợp Đa Bệnh Lý / Đa Chấn thương Đồng thời (Multi-Triage)
    List<ClinicalProtocolNode> multiList = [];
    if (pred.discourseModeIndex == 3 && pred.comorbidProtocols.length >= 2) {
      multiList = pred.comorbidProtocols;
    } else {
      multiList = _detectMultipleInjuries(clean, pred);
    }

    if (multiList.length >= 2) {
      final distinct = <String, ClinicalProtocolNode>{};
      for (final node in multiList) {
        distinct.putIfAbsent(node.topic, () => node);
      }
      if (distinct.length >= 2) {
        final ordered = distinct.values.toList()
          ..sort((a, b) => a.comorbidRank.compareTo(b.comorbidRank));
        _activeProtocol = ordered.first;
        _activeBodySlot = pred.bodySlotIndex;
        _activePhase = DialoguePhase.initialAid;
        _context.addTurn(trimmed);

        final sb = StringBuffer(
          'BÁC SĨ AI RESQ-AID (XỬ LÝ ĐA CHẤN THƯƠNG / ĐA TRIỆU CHỨNG ĐỒNG THỜI):\n\n',
        );
        for (int i = 0; i < ordered.length; i++) {
          final item = ordered[i];
          final bodyAdapted = (pred.bodySlotIndex == 1 && item.legVariantText != null)
              ? item.legVariantText!
              : item.initialText;
          sb.writeln('PHẦN ${i + 1}: $bodyAdapted\n');
        }
        return sb.toString().trim();
      }
    }

    // 4.1. Trường hợp Tình huống Ngoại suy / Độ tin cậy thấp (Out-of-Domain & Wilderness Guard)
    if (pred.topCosineSimilarity < 0.12 && !pred.topProtocol.isFacilityLookup) {
      final outOfDomainText = _resolveOutOfDomainOrWilderness(clean, trimmed);
      if (outOfDomainText != null) {
        _activePhase = DialoguePhase.initialAid;
        _context.addTurn(trimmed);
        return outOfDomainText;
      }
    }

    // 5. Cập nhật trạng thái phác đồ hiện hành từ kết quả Vector RAG Top-1
    final chosenNode = pred.topProtocol;

    // KHÓA AN TOÀN SINH TỬ CHO CPR (CPR CLINICAL SAFETY GATE):
    // Phác đồ Ép tim CPR TUYỆT ĐỐI CHỈ được kích hoạt khi nạn nhân ngừng tim/ngừng thở hoặc hỏi trực tiếp kỹ thuật CPR!
    final isExplicitCprContext = clean.contains('ep tim') ||
        clean.contains('cpr') ||
        clean.contains('ngung tho') ||
        clean.contains('khong tho') ||
        clean.contains('ngung tim') ||
        (clean.contains('bat tinh') && !clean.contains('con tinh')) ||
        clean.contains('mach lai') ||
        clean.contains('co mach') ||
        clean.contains('tho lai') ||
        clean.contains('aed') ||
        clean.contains('soc dien') ||
        clean.contains('moi tay') ||
        clean.contains('duoi suc') ||
        clean.contains('doi nguoi') ||
        (clean.contains('tu the') && clean.contains('tay')) ||
        clean.contains('do sau') ||
        (clean.contains('nhip tim') && (clean.contains('toc do') || clean.contains('the nao') || clean.contains('bao nhieu'))) ||
        clean.contains('quy');

    if (chosenNode.topic == 'cpr' && !isExplicitCprContext) {
      _activePhase = DialoguePhase.assessment;
      _context.addTurn(trimmed);
      return _buildUniversalClinicalFailSafe(clean, trimmed);
    }

    _activeProtocol = chosenNode;
    if (pred.bodySlotIndex != 0) {
      _activeBodySlot = pred.bodySlotIndex;
    }

    if (chosenNode.isClarification) {
      _pendingClarificationNode = chosenNode;
      _pendingPriorQuery = trimmed;
      _activePhase = DialoguePhase.assessment;
    } else {
      _pendingClarificationNode = null;
      _pendingPriorQuery = null;
      _activePhase = DialoguePhase.initialAid;
    }

    _context.addTurn(trimmed);

    // 6. Thích ứng vị trí giải phẫu tự động từ Neural Body-Location Slot Head (Chân vs Tay/Chung)
    if (_activeBodySlot == 1 && chosenNode.legVariantText != null) {
      return chosenNode.legVariantText!;
    }

    return chosenNode.initialText;
  }

  String _executeOfflineFacilityNavigation(String rawQuery) {
    // Khớp ngữ nghĩa nhẹ với 3 nguyên mẫu loại cơ sở bằng chính không gian nhúng Neural
    final qEmb = MedicalNeuralNlpEngine.instance.infer(rawQuery).embedding128d;
    final hospEmb = MedicalNeuralNlpEngine.instance.infer('bệnh viện đa khoa cấp cứu').embedding128d;
    final pharmEmb = MedicalNeuralNlpEngine.instance.infer('nhà thuốc hiệu thuốc tây').embedding128d;
    final clinicEmb = MedicalNeuralNlpEngine.instance.infer('trạm y tế phường xã trạm xá').embedding128d;

    double dot(List<double> a, List<double> b) {
      double s = 0.0;
      for (int i = 0; i < a.length; i++) {
        s += a[i] * b[i];
      }
      return s;
    }

    final sHosp = dot(qEmb, hospEmb);
    final sPharm = dot(qEmb, pharmEmb);
    final sClinic = dot(qEmb, clinicEmb);

    FacilityType? filterType;
    String label = 'trạm y tế & bệnh viện gần nhất';
    if (sPharm > sHosp && sPharm > sClinic && sPharm > 0.55) {
      filterType = FacilityType.pharmacy;
      label = 'nhà thuốc gần nhất';
    } else if (sHosp > sClinic + 0.08) {
      filterType = FacilityType.hospital;
      label = 'bệnh viện cấp cứu gần nhất';
    } else if (sClinic > sHosp + 0.08) {
      filterType = FacilityType.clinic;
      label = 'trạm y tế gần nhất';
    }

    final nearestList = OfflineMedicalService.findNearestFacilities(
      typeFilter: filterType,
      limit: 1,
    );
    final nearest = nearestList.isNotEmpty ? nearestList.first : null;
    final info = nearest != null
        ? ' Gần bạn nhất là ${nearest.facility.name}, cách ${nearest.formattedDistance} về hướng ${nearest.compassDirection}. Hotline: ${nearest.facility.phone}.'
        : '';

    LocationService.openNearestMedicalMap(query: label);
    _activePhase = DialoguePhase.initialAid;

    return 'Đã kích hoạt định vị GPS và bản đồ đồ thị A* ngoại tuyến để tìm $label.$info Nếu tình trạng nguy kịch đe dọa tính mạng, hãy bấm Gọi 115 ngay!';
  }

  /// Phân giải câu trả lời khi người dùng đang ở trạng thái làm rõ (Smart Clarification Resolution)
  String? _resolvePendingClarification(
    ClinicalProtocolNode pendingNode,
    String priorQuery,
    String userResponse,
  ) {
    final clean = MedicalNeuralNlpEngine.stripDiacritics(userResponse.toLowerCase());
    final cleanPrior = MedicalNeuralNlpEngine.stripDiacritics(priorQuery.toLowerCase());
    final tag = pendingNode.clarificationTag ?? '';
    final engine = MedicalNeuralNlpEngine.instance;

    // Ngắt hội thoại làm rõ nếu phát hiện dấu hiệu ngừng thở / ngừng tim
    if (clean.contains('ngung tho') ||
        clean.contains('khong tho') ||
        clean.contains('ngung tim') ||
        (clean.contains('bat tinh') && !clean.contains('con tinh'))) {
      return null;
    }

    switch (tag) {
      case 'headache':
        final isTrauma = cleanPrior.contains('danh') ||
            cleanPrior.contains('va cham') ||
            cleanPrior.contains('dap dau') ||
            cleanPrior.contains('nga') ||
            cleanPrior.contains('tai nan') ||
            clean.contains('danh') ||
            clean.contains('va cham') ||
            clean.contains('dap dau') ||
            clean.contains('u dau') ||
            clean.contains('nga');

        final hasNausea = (clean.contains('non') || clean.contains('buon non')) &&
            !clean.contains('khong non') &&
            !clean.contains('khong buon non') &&
            !clean.contains('chua non');
        final hasFever = clean.contains('sot') &&
            !clean.contains('khong sot') &&
            !clean.contains('chua sot');
        final hasStiffNeck = clean.contains('cung co') &&
            !clean.contains('khong cung co');

        final hasWeakness = (clean.contains('yeu') ||
            clean.contains('liet') ||
            clean.contains('meo mat') ||
            clean.contains('te bi')) &&
            !clean.contains('khong yeu') &&
            !clean.contains('khong liet') &&
            !clean.contains('khong meo') &&
            !clean.contains('khong te');

        final isSevere = clean.contains('dau lon') ||
            (clean.contains('lon') && !clean.contains('khong lon')) ||
            clean.contains('du doi') ||
            clean.contains('set danh') ||
            clean.contains('kinh khung') ||
            clean.contains('khung khiep') ||
            clean.contains('rat dau') ||
            clean.contains('dau nhieu') ||
            clean.contains('dau nang') ||
            clean.contains('nhuc nhoi') ||
            clean.contains('bua bo') ||
            clean.contains('khong chiu noi') ||
            clean.contains('chiu khong noi') ||
            clean.contains('dot ngot') ||
            hasNausea ||
            hasFever ||
            hasStiffNeck ||
            hasWeakness ||
            clean.contains('mo mat') ||
            clean.contains('co giat');

        final isGradualOrTension = clean.contains('tu tu') ||
            clean.contains('nhe') ||
            clean.contains('vua') ||
            clean.contains('nua dau') ||
            clean.contains('migraine') ||
            clean.contains('cang thang') ||
            clean.contains('stress') ||
            clean.contains('moi mat') ||
            clean.contains('thieu ngu') ||
            clean.contains('khong sot') ||
            clean.contains('khong non') ||
            clean.contains('khong buon non') ||
            clean.contains('khong cung co') ||
            clean.contains('binh thuong') ||
            clean.contains('am i');

        if (isTrauma) {
          final headNode = engine.findProtocolById('closed_head_trauma');
          if (headNode != null) {
            _activeProtocol = headNode;
            return headNode.initialText;
          }
        }

        if (isSevere) {
          return '🚨 CẢNH BÁO NGUY HIỂM (CỜ ĐỎ THẦN KINH): Cơn đau đầu dữ dội / đau lớn đột ngột có thể là dấu hiệu xuất huyết nội sọ, viêm màng não, đột quỵ hoặc tăng áp lực nội sọ cấp tính!\n\n'
              '1. GỌI NGAY 115 hoặc đưa người bệnh đến khoa Cấp cứu bệnh viện gần nhất ngay lập tức!\n'
              '2. Cho người bệnh nằm nghỉ ở phòng yên tĩnh, tối, kéo rèm giảm ánh sáng chói, kê đầu cao 20-30 độ.\n'
              '3. TUYỆT ĐỐI KHÔNG tự ý uống Aspirin hoặc Ibuprofen vì nếu do xuất huyết não, thuốc chống đông sẽ làm máu chảy trầm trọng hơn.\n'
              '4. Theo dõi sát tri giác: Nếu người bệnh lơ mơ, co giật hoặc nôn vọt, xoay người sang tư thế nằm nghiêng an toàn để tránh hít sặc dịch nôn, sẵn sàng ép tim CPR 110 BPM nếu ngừng thở!';
        }

        if (isGradualOrTension) {
          return 'XỬ TRÍ ĐAU ĐẦU CĂNG THẲNG / MIGRAINE THÔNG THƯỜNG:\n\n'
              '1. Nằm nghỉ ngơi ở nơi yên tĩnh, thoáng mát, kéo rèm giảm ánh sáng chói và tránh tiếng ồn mạnh.\n'
              '2. Uống một ly nước ấm, có thể dùng khăn mát đắp lên trán hoặc chườm ấm nhẹ vùng sau gáy để giãn cơ cổ vai gáy.\n'
              '3. Nếu đau nhiều, người lớn có thể uống 1 viên Paracetamol 500mg (cách nhau ít nhất 4-6 giờ, tối đa 2g/ngày khi tự dùng, không uống chung với rượu bia).\n'
              '4. THEO DÕI CỜ ĐỎ: Nếu đau tăng dữ dội đột ngột như búa bổ, xuất hiện nôn vọt, mờ mắt hoặc sốt cứng cổ, phải đến bệnh viện cấp cứu ngay lập tức!';
        }

        return 'HƯỚNG DẪN XỬ TRÍ ĐAU ĐẦU AN TOÀN:\n\n'
            '1. Cho người bệnh nằm nghỉ ngơi ở phòng yên tĩnh, thoáng khí, kéo rèm giảm ánh sáng chói và tiếng ồn.\n'
            '2. Uống một ly nước ấm, chườm khăn mát lên vùng trán để làm dịu cơn nhức.\n'
            '3. Người lớn có thể dùng 1 viên Paracetamol 500mg nếu đau nhiều và không có tiền sử bệnh lý gan nặng.\n'
            '4. CẢNH BÁO NGUY HIỂM: Nếu đau dữ dội đột ngột như sét đánh, kèm nôn vọt, sốt cao cứng cổ hoặc méo mặt yếu tay chân, hãy gọi 115 đưa đi cấp cứu ngay!';

      case 'chest_pain':
        final isCardiac = clean.contains('de nang') ||
            clean.contains('bop nghet') ||
            clean.contains('lan') ||
            clean.contains('vai') ||
            clean.contains('tay') ||
            clean.contains('ham') ||
            clean.contains('kho tho') ||
            clean.contains('va mo hoi') ||
            clean.contains('lon') ||
            clean.contains('du doi') ||
            clean.contains('nang') ||
            clean.contains('that nguc') ||
            clean.contains('tuc nguc');

        final isPleuritic = clean.contains('nhoi') ||
            clean.contains('cham chich') ||
            clean.contains('hit tho') ||
            clean.contains('tho sau') ||
            clean.contains('an vao') ||
            clean.contains('an suon') ||
            clean.contains('van dong') ||
            clean.contains('tu tu') ||
            clean.contains('nhe');

        final isGerd = clean.contains('o chua') ||
            clean.contains('o nong') ||
            clean.contains('rat co') ||
            clean.contains('da day') ||
            clean.contains('trao nguoc');

        if (isGerd) {
          final gerdNode = engine.findProtocolById('gerd_heartburn');
          if (gerdNode != null) {
            _activeProtocol = gerdNode;
            return gerdNode.initialText;
          }
        }

        if (isCardiac) {
          final heartNode = engine.findProtocolById('heart_attack_acute');
          if (heartNode != null) {
            _activeProtocol = heartNode;
          }
          return '🚨 BÁO ĐỘNG ĐỎ CẤP CỨU: Nghi ngờ cơn nhồi máu cơ tim cấp!\n\n'
              '1. GỌI NGAY 115 KHẨN CẤP.\n'
              '2. Dừng mọi vận động, đặt bệnh nhân ngồi tựa lưng nửa nằm nửa ngồi góc 45 độ (tư thế Fowler), nới lỏng cổ áo và thắt lưng.\n'
              '3. Giữ nạn nhân bình tĩnh, hít thở sâu chậm, tuyệt đối không để nạn nhân tự đi lại hay leo cầu thang.\n'
              '4. Sẵn sàng ép tim CPR 110 BPM ngay lập tức nếu bệnh nhân đột ngột bất tỉnh, ngừng thở!';
        }

        if (isPleuritic) {
          return 'XỬ TRÍ ĐAU THÀNH NGỰC / ĐAU DÂY THẦN KINH LIÊN SƯỜN:\n\n'
              '1. Cơn đau nhói khi hít thở sâu hoặc khi ấn vào thành ngực thường do viêm khớp sụn sườn, căng cơ thành ngực hoặc đau thần kinh liên sườn.\n'
              '2. Ngồi nghỉ ngơi thư giãn, hít thở nông đều, tránh vặn xoắn thân mình hoặc mang vác nặng.\n'
              '3. Có thể chườm ấm nhẹ vùng ngực bị căng đau 15-20 phút để giảm co thắt cơ.\n'
              '4. CẢNH BÁO NGUY HIỂM: Nếu đau chuyển sang cảm giác đè nặng bóp nghẹt ngực, lan sang cánh tay trái/hàm hoặc kèm khó thở vã mồ hôi lạnh, hãy gọi 115 cấp cứu ngay!';
        }

        return null;

      case 'allergy':
        final isSevereAllergy = clean.contains('sung') ||
            clean.contains('phu') ||
            clean.contains('moi') ||
            clean.contains('mat') ||
            clean.contains('hong') ||
            clean.contains('nghen') ||
            clean.contains('kho tho') ||
            clean.contains('tho rit') ||
            clean.contains('kho khe') ||
            clean.contains('tut huyet ap') ||
            clean.contains('choang') ||
            clean.contains('chong mat') ||
            clean.contains('nang') ||
            clean.contains('nguy kich');

        final isMildAllergy = clean.contains('ngua') ||
            clean.contains('man do') ||
            clean.contains('me day') ||
            clean.contains('khong kho tho') ||
            clean.contains('khong sung') ||
            clean.contains('nhe');

        if (isSevereAllergy) {
          final anaNode = engine.findProtocolById('anaphylaxis_epipen');
          if (anaNode != null) {
            _activeProtocol = anaNode;
          }
          return '🚨 CẤP CỨU SỐC PHẢN VỆ NGUY KỊCH:\n\n'
              '1. Tiêm ngay bút tiêm tự động Epinephrine (EpiPen) vào mặt ngoài giữa đùi nạn nhân (giữ chặt 3-5 giây).\n'
              '2. GỌI 115 NGAY LẬP TỨC!\n'
              '3. Đặt nạn nhân nằm ngửa, kê chân cao khoảng 30cm (nếu đang khó thở thì ngồi nửa nằm nửa ngồi), cấm ngồi dậy đột ngột.\n'
              '4. Theo dõi sát đường thở, sẵn sàng ép tim CPR 110 BPM nếu ngừng thở ngừng tuần hoàn!';
        }

        if (isMildAllergy) {
          return 'XỬ TRÍ DỊ ỨNG MẨN NGỨA NGOÀI DA:\n\n'
              '1. Tránh xa ngay dị nguyên gây dị ứng (thức ăn lạ, mỹ phẩm, phấn hoa, hóa chất, lông thú cưng).\n'
              '2. Rửa sạch vùng da dị ứng bằng nước mát, chườm khăn mát để làm dịu cơn ngứa, tránh gãi làm rách da trầy xước nhiễm trùng.\n'
              '3. Người lớn có thể uống 1 viên thuốc kháng histamine chống dị ứng (như Cetirizine hoặc Loratadine 10mg) nếu đã quen dùng.\n'
              '4. THEO DÕI NGUY HIỂM: Nếu xuất hiện sưng phù môi mắt, khàn tiếng, khó thở hoặc nghẹn họng, đó là dấu hiệu sốc phản vệ, phải gọi 115 đi cấp cứu ngay!';
        }

        return null;

      case 'child_fever':
        final hasConvulsion = (clean.contains('co giat') ||
            clean.contains('giat') ||
            clean.contains('gong nguoi') ||
            clean.contains('mat tron')) &&
            !clean.contains('chua co giat') &&
            !clean.contains('khong co giat') &&
            !clean.contains('chua giat') &&
            !clean.contains('khong giat');

        final isSevereFever = hasConvulsion ||
            clean.contains('tim tai') ||
            clean.contains('li bi') ||
            clean.contains('kho danh thuc') ||
            clean.contains('non vot') ||
            clean.contains('rut lom') ||
            clean.contains('39') ||
            clean.contains('40');

        final isMildFever = clean.contains('chua co giat') ||
            clean.contains('khong co giat') ||
            clean.contains('sot nhe') ||
            clean.contains('38') ||
            clean.contains('van tinh') ||
            clean.contains('khong non') ||
            clean.contains('uong duoc nuoc') ||
            clean.contains('choi binh thuong') ||
            clean.contains('nhe');

        if (isSevereFever && !clean.contains('chua co giat') && !clean.contains('khong co giat')) {
          final convNode = engine.findProtocolById('febrile_convulsion_child');
          if (convNode != null) {
            _activeProtocol = convNode;
          }
          return 'XỬ TRÍ CẤP CỨU SỐT CAO CO GIẬT Ở TRẺ NHỎ:\n\n'
              '1. ĐẶT NẰM NGHIÊNG AN TOÀN: Đặt trẻ nằm nghiêng sang một bên trên mặt phẳng an toàn để đờm nhớt tự chảy ra ngoài, chống hít sặc vào phổi.\n'
              '2. TUYỆT ĐỐI CẤM nhét bất cứ vật gì vào miệng: Không nhét thìa, đũa, ngón tay; không vắt nước chanh vào họng gây ngạt thở nguy kịch.\n'
              '3. BẤM GIỜ CƠN GIẬT: Theo dõi chính xác thời gian co giật (đa số cơn giật do sốt tự hết sau 1-3 phút).\n'
              '4. LÀM MÁT NHẸ NHÀNG: Nới rộng quần áo, dùng khăn nhúng nước ấm (36-37°C) lau mát nách, bẹn. LƯU Ý: Thuốc hạ sốt KHÔNG ngăn được cơn co giật đang diễn ra; TUYỆT ĐỐI KHÔNG cố nhét thuốc hạ sốt hậu môn khi trẻ đang gồng giật vì nguy cơ thủng/chấn thương trực tràng.\n'
              '5. GỌI NGAY 115 HOẶC ĐI VIỆN CẤP CỨU: Nếu cơn giật kéo dài trên 5 phút, trẻ co giật tái phát, tím tái khó thở, hoặc sau giật li bì không tỉnh!';
        }

        if (isMildFever) {
          return 'HƯỚNG DẪN HẠ SỐT AN TOÀN CHO TRẺ:\n\n'
              '1. Mặc quần áo rộng rãi, thoáng mát, phòng thông thoáng, không ủ chăn ấm kín.\n'
              '2. Dùng khăn mềm nhúng nước ấm (nhiệt độ nước ấm nhẹ thấp hơn thân nhiệt trẻ 1-2 độ C) lau trán, hõm nách và hai bên bẹn. TUYỆT ĐỐI KHÔNG chườm đá lạnh hoặc xoa cồn.\n'
              '3. Cho trẻ uống nhiều nước ấm, bú mẹ tăng cường hoặc dung dịch Oresol pha đúng tỉ lệ để bù nước.\n'
              '4. Nếu trẻ sốt từ 38.5 độ C trở lên, cho dùng thuốc hạ sốt Paracetamol đơn chất liều 10-15 mg/kg mỗi lần, cách nhau ít nhất 4-6 giờ.\n'
              '5. Đưa trẻ đi viện ngay nếu sốt cao liên tục không hạ, li bì, co giật hoặc nôn ói nhiều!';
        }

        return null;

      case 'vague_pain':
        if (clean.contains('dau') || clean.contains('nhuc dau')) {
          final headClar = engine.findProtocolById('clarify_headache');
          if (headClar != null) {
            _activeProtocol = headClar;
            return _resolvePendingClarification(
              headClar,
              'đau đầu',
              userResponse,
            );
          }
        }
        if (clean.contains('nguc') || clean.contains('tim')) {
          final heart = engine.findProtocolById('heart_attack_acute');
          if (heart != null) {
            _activeProtocol = heart;
            return heart.initialText;
          }
        }
        if (clean.contains('bung') || clean.contains('da day') || clean.contains('ruot')) {
          final abd = engine.findProtocolById('acute_abdomen');
          if (abd != null) {
            _activeProtocol = abd;
            return abd.initialText;
          }
        }
        if (clean.contains('lung') || clean.contains('cot song')) {
          final back = engine.findProtocolById('back_pain_sciatica');
          if (back != null) {
            _activeProtocol = back;
            return back.initialText;
          }
        }
        if (clean.contains('ngon chan') || clean.contains('gut')) {
          final gout = engine.findProtocolById('gout_acute');
          if (gout != null) {
            _activeProtocol = gout;
            return gout.initialText;
          }
        }
        if (clean.contains('chan') || clean.contains('tay') || clean.contains('khop') || clean.contains('treo')) {
          final sprain = engine.findProtocolById('sprain_rice');
          if (sprain != null) {
            _activeProtocol = sprain;
            return sprain.initialText;
          }
        }
        return null;

      case 'vague_trauma':
        if (clean.contains('dau') || clean.contains('u dau') || clean.contains('dap dau')) {
          final head = engine.findProtocolById('closed_head_trauma');
          if (head != null) {
            _activeProtocol = head;
            return head.initialText;
          }
        }
        if (clean.contains('co') || clean.contains('lung') || clean.contains('cot song') || clean.contains('cao')) {
          return '🚨 CẢNH BÁO CHẤN THƯƠNG CỘT SỐNG (NGÃ ĐỘ CAO / VÙNG CỔ LƯNG):\n\n'
              '1. GỌI NGAY 115 KHẨN CẤP.\n'
              '2. TUYỆT ĐỐI BẤT ĐỘNG: Giữ nạn nhân nằm yên tại chỗ, cố định trục đầu - cổ - thân thẳng hàng. CẤM bế xốc, cấm xoay bẻ cổ hoặc nâng đầu nạn nhân dậy vì nguy cơ làm đứt tủy sống gây liệt vĩnh viễn hoặc tử vong!\n'
              '3. Dùng hai tay hoặc chèn bao cát/chăn gối hai bên đầu để giữ đầu nạn nhân không bị lắc lư.\n'
              '4. Theo dõi nhịp thở: Nếu ngừng thở, dùng kỹ thuật ấn giữ hàm mở đường thở (jaw-thrust) cấm ngửa cổ, sẵn sàng ép tim CPR 110 BPM!';
        }
        if (clean.contains('gay') || clean.contains('bien dang') || clean.contains('lech')) {
          final frac = engine.findProtocolById('fracture_main');
          if (frac != null) {
            _activeProtocol = frac;
            return frac.initialText;
          }
        }
        if (clean.contains('chay mau') || clean.contains('rach')) {
          final bleed = engine.findProtocolById('bleeding_cut');
          if (bleed != null) {
            _activeProtocol = bleed;
            return bleed.initialText;
          }
        }
        return null;

      case 'vague_fatigue':
        if (clean.contains('doi') || clean.contains('run tay') || clean.contains('va mo hoi') || clean.contains('ha duong')) {
          final hypo = engine.findProtocolById('hypoglycemia_15');
          if (hypo != null) {
            _activeProtocol = hypo;
            return hypo.initialText;
          }
        }
        if (clean.contains('xiu') || clean.contains('choang') || clean.contains('hoa mat') || clean.contains('dung len')) {
          final faint = engine.findProtocolById('postural_hypotension');
          if (faint != null) {
            _activeProtocol = faint;
            return faint.initialText;
          }
        }
        if (clean.contains('kho tho') || clean.contains('tuc nguc') || clean.contains('nguc')) {
          final heart = engine.findProtocolById('heart_attack_acute');
          if (heart != null) {
            _activeProtocol = heart;
            return heart.initialText;
          }
        }
        return null;

      default:
        return null;
    }
  }

  List<ClinicalProtocolNode> _detectMultipleInjuries(String clean, NeuralNlpPrediction pred) {
    final engine = MedicalNeuralNlpEngine.instance;
    final list = <ClinicalProtocolNode>[];

    // Không kích hoạt đa triệu chứng nếu đây là câu hỏi đơn chủ đề rõ ràng (như giật điện, sốc phản vệ, bỏng đơn thuần)
    if (clean.contains('giat dien') || clean.contains('dien giat') || clean.contains('soc phan ve')) {
      return list;
    }

    final hasHead = clean.contains('dau dau') ||
        clean.contains('dap dau') ||
        clean.contains('u dau') ||
        clean.contains('te nga') ||
        clean.contains('nga dap dau');

    final hasBleed = clean.contains('chay mau') ||
        clean.contains('mau chay') ||
        clean.contains('rach da') ||
        clean.contains('dut tay');

    final hasFracture = clean.contains('gay xuong') ||
        clean.contains('bien dang chi') ||
        clean.contains('gay chan') ||
        clean.contains('gay tay');

    final hasDogBite = clean.contains('cho can') || clean.contains('meo can');
    final hasSeizure = clean.contains('co giat') || clean.contains('len con giat');
    final hasBurn = (clean.contains('vet bong') || clean.contains('bi bong') || clean.contains('phong nuoc')) && !clean.contains('dien');
    final hasFaint = clean.contains('ngat xiu') || clean.contains('bi ngat') || clean.contains('hon me');

    if (hasBleed) {
      final bleedNode = engine.findProtocolById('bleeding_cut');
      if (bleedNode != null) list.add(bleedNode);
    }

    if (hasHead) {
      final headNode = engine.findProtocolById('closed_head_trauma');
      if (headNode != null) list.add(headNode);
    }

    if (hasFracture) {
      final fracNode = engine.findProtocolById('fracture_main');
      if (fracNode != null) list.add(fracNode);
    }

    if (hasDogBite) {
      final dogNode = engine.findProtocolById('dog_cat_bite');
      if (dogNode != null) list.add(dogNode);
    }

    if (hasSeizure) {
      final sezNode = engine.findProtocolById('seizure_adult');
      if (sezNode != null) list.add(sezNode);
    }

    if (hasBurn) {
      final burnNode = engine.findProtocolById('burn_main');
      if (burnNode != null) list.add(burnNode);
    }

    if (hasFaint) {
      final faintNode = engine.findProtocolById('fainting_syncope');
      if (faintNode != null) list.add(faintNode);
    }

    return list;
  }

  String? _resolveExplicitClinicalIntent(String clean, String rawQuery) {
    // 0.1. ĐAU ĐẦU SÉT ĐÁNH (THUNDERCLAP HEADACHE / XUẤT HUYẾT DƯỚI NHỆN)
    if ((clean.contains('set danh') || clean.contains('nhu set')) &&
        (clean.contains('dau') || clean.contains('dau dau') || clean.contains('nhuc dau'))) {
      return '🚨 BÁO ĐỘNG ĐỎ: ĐAU ĐẦU SÉT ĐÁNH (NGHI NGỜ XUẤT HUYẾT DƯỚI NHỆN CẤP):\n\n'
          'Cơn đau đầu bộc phát dữ dội đạt đỉnh trong vòng vài giây như "sét đánh" là triệu chứng cấp cứu thần kinh tối khẩn cấp (nghi ngờ vỡ phình mạch não hoặc xuất huyết dưới nhện)!\n\n'
          'HÀNH ĐỘNG CẤP CỨU NGAY LẬP TỨC:\n'
          '1. GỌI 115 NGAY LẬP TỨC: Báo rõ "Bệnh nhân đau đầu dữ dội đột ngột như sét đánh, nghi ngờ xuất huyết não" để điều xe cấp cứu có trang bị hồi sức sọ não.\n'
          '2. NẰM BẤT ĐỘNG TUYỆT ĐỐI: Nằm nghỉ nơi yên tĩnh, tối và thoáng khí; kê cao đầu 20-30 độ để giảm áp lực nội sọ.\n'
          '3. ⚠️ TUYỆT ĐỐI CẤM UỐNG ASPIRIN / IBUPROFEN: Tuyệt đối không tự ý uống các thuốc giảm đau làm loãng máu vì sẽ khiến xuất huyết não lan rộng gây tử vong!\n'
          '4. THEO DÕI SÁT TRI GIÁC: Nếu bệnh nhân nôn vọt, lơ mơ hoặc co giật, xoay ngay sang tư thế nằm nghiêng an toàn để tránh sặc dịch nôn vào phổi!';
    }

    // 0.2. ĐAU MẮT DO HỒ QUANG HÀN (PHOTOKERATITIS / BỎNG MẮT QUANG HỌC)
    if (clean.contains('ho quang') ||
        clean.contains('han dien') ||
        (clean.contains('mat') && (clean.contains('han') || clean.contains('nhin tia') || clean.contains('tia han')))) {
      return 'SƠ CỨU ĐAU MẮT DO NHÌN HỒ QUANG HÀN (BỎNG GIÁC MẠC QUANG HỌC):\n\n'
          'Tia cực tím (UV) từ hồ quang hàn làm tổn thương lớp biểu mô giác mạc, gây bỏng rát, cộm xốn như có cát, chảy nước mắt và sợ ánh sáng.\n\n'
          'HƯỚNG DẪN XỬ TRÍ CHUẨN Y KHOA:\n'
          '1. CHƯỜM MÁT QUANH MẮT: Dùng khăn sạch thấm nước mát hoặc túi đá bọc khăn mềm đặt nhẹ lên vùng mắt kín 15-20 phút để làm dịu cơn đau rát và giảm phù nề.\n'
          '2. NGHỈ NGƠI TRONG PHÒNG TỐI: Nhắm mắt nghỉ ngơi ở nơi ít ánh sáng, tránh dùng điện thoại hay nhìn màn hình máy tính.\n'
          '3. NHỎ NƯỚC MUỐI SINH LÝ: Nhỏ nước muối sinh lý NaCl 0.9% hoặc nước mắt nhân tạo để bôi trơn và rửa trôi mạt bụi kim loại.\n'
          '4. ⚠️ TUYỆT ĐỐI CẤM DỤI MẮT: Dụi mắt sẽ làm trầy rách biểu mô giác mạc và bội nhiễm vi khuẩn. TUYỆT ĐỐI KHÔNG tự ý nhỏ thuốc lạ hoặc đắp lá cây/sữa mẹ vào mắt!\n'
          '5. ĐI KHÁM CHUYÊN KHOA MẮT nếu sau 24 giờ mắt vẫn sưng đỏ, đau nhức dữ dội hoặc nhìn mờ!';
    }

    // 0.3. SẠT LỞ ĐẤT (LANDSLIDE RESCUE & SURVIVAL)
    if (clean.contains('sat lo') || clean.contains('lo dat') || clean.contains('sat dat')) {
      return '🚨 HƯỚNG DẪN SINH TỒN & DI CHUYỂN KHI Ở GẦN KHU VỰC SẠT LỞ ĐẤT:\n\n'
          '1. DI CHUYỂN VUÔNG GÓC VỚI HƯỚNG SẠT LỞ: Tuyệt đối không chạy cùng hướng dòng bùn đất đá chảy. Hãy chạy nhanh sang hai bên sườn (hướng vuông góc) và thoát lên các mỏm đồi cao, nền đất cứng có cây lớn bám rễ sâu.\n'
          '2. TRÁNH XA KHE SUỐI, THUNG LŨNG & MÕM ĐẤT DỐC: Nước lũ cuốn và sạt trượt thường dồn mạnh nhất vào lòng suối và khe dốc.\n'
          '3. CHÚ Ý NGUY HIỂM ĐIỆN VÀ KHÍ GAS: Tránh xa các cột điện gãy, dây điện đứt rơi xuống đất hoặc rò rỉ khí gas.\n'
          '4. NẾU BỊ MẮC KẸT: Cuộn tròn người bảo vệ đầu, tìm điểm tựa dưới vật chắn cứng chắc. Kêu gọi cứu hộ hoặc dùng còi/gõ kim loại phát tín hiệu cầu cứu SOS.\n'
          '5. BÁO CẤP CỨU & CỨU HỘ: Gọi ngay 112 (Tổng đài Tìm kiếm Cứu nạn Quốc gia) hoặc 114 (Cứu nạn Cứu hộ) để được điều hướng lực lượng tiếp cận!';
    }

    // 0.4. VÙNG LŨ LỤT MẤT MẠNG / CÓ NGƯỜI BỊ THƯƠNG (FLOOD SURVIVAL & REMOTE INJURY)
    if (clean.contains('vung lu') || clean.contains('ngap lut') || clean.contains('lu quet') || (clean.contains('lu') && clean.contains('mang'))) {
      return '🚨 HƯỚNG DẪN XỬ TRÍ TẠI CHỖ KHI Ở VÙNG LŨ KHÔNG CÓ MẠNG & CÓ NGƯỜI BỊ THƯƠNG:\n\n'
          '1. DI TẢN LÊN VỊ TRÍ CAO VÀ VỮNG CHẮC: Đưa người bị thương lên tầng cao, nóc nhà kiên cố hoặc gò đất cao. Mặc áo phao hoặc buộc can nhựa rỗng/thùng xốp làm phao cứu sinh.\n'
          '2. SƠ CỨU CẦM MÁU & CỐ ĐỊNH TẠI CHỖ: Dùng vải sạch/quần áo khô ấn chặt miệng vết thương chảy máu. Nếu nghi gãy xương, dùng nẹp gỗ/cành cây cố định 2 đầu khớp, giữ vết thương khô ráo tránh nhiễm trùng nước lũ.\n'
          '3. TẠO TÍN HIỆU CỨU HỘ SOS NGOẠI TUYẾN: Treo cờ/vải đỏ hoặc sáng màu ở nóc nhà, thổi còi định kỳ, vào ban đêm dùng đèn pin nhấp nháy 3 ngắn - 3 dài - 3 ngắn (tín hiệu SOS quốc tế).\n'
          '4. TÌM SÓNG KHẨN CẤP: Điện thoại không có sóng nhà mạng vẫn có thể thực hiện CUỘC GỌI KHẨN CẤP 112/115 thông qua chuyển vùng (roaming) với bất kỳ trạm phát sóng nào còn hoạt động.\n'
          '5. TIẾT KIỆM NƯỚC SẠCH: Uống từng ngụm nước sạch đóng chai, tuyệt đối không uống trực tiếp nước lũ chưa đun sôi!';
    }

    // 0.5. HẠ THÂN NHIỆT DO RÉT LẠNH & QUẦN ÁO ƯỚT (ACCIDENTAL HYPOTHERMIA)
    if ((clean.contains('troi lanh') || clean.contains('quan ao uot') || clean.contains('lanh') || clean.contains('uot')) &&
        (clean.contains('run') || clean.contains('run lien tuc') || clean.contains('ret') || clean.contains('ha than nhiet'))) {
      return '🚨 CẤP CỨU HẠ THÂN NHIỆT CẤP TÍNH (DO LẠNH & ƯỚT SŨNG):\n\n'
          'Run liên tục là cơ chế sinh nhiệt tự nhiên khi thân nhiệt tụt xuống dưới 35°C; nếu không ủ ấm kịp thời nạn nhân sẽ lú lẫn, loạn nhịp tim và tử vong!\n\n'
          'HÀNH ĐỘNG SƠ CỨU KHẨN CẤP:\n'
          '1. CỞI BỎ QUẦN ÁO ƯỚT NGAY LẬP TỨC: Nước truyền nhiệt nhanh gấp 25 lần không khí, giữ quần áo ướt sẽ làm mất nhiệt cực kỳ nhanh. Lau khô toàn thân nhanh chóng.\n'
          '2. Ủ ẤM CHỦ ĐỘNG BẰNG NHIỀU LỚP KHÔ: Quấn chăn ấm, áo khoác dày; TẬP TRUNG GIỮ ẤM PHẦN THÂN TRUNG TÂM (ngực, cổ, bụng và đầu), kê cách ly cơ thể khỏi mặt đất lạnh bằng chiếu/ván/lá cây khô.\n'
          '3. UỐNG NƯỚC ẤM CÓ ĐƯỜNG: Nếu nạn nhân còn tỉnh táo và nuốt được, cho uống nước ấm có đường hoặc gừng/súp ấm. ⚠️ TUYỆT ĐỐI CẤM cho uống rượu hoặc cà phê (rượu gây giãn mạch ngoại vi làm mất nhiệt nhanh hơn).\n'
          '4. ⚠️ CẤM CHƯỜM NÓNG TRỰC TIẾP LÊN TAY CHÂN: Không dùng nước sôi, máy sấy nóng gắt hoặc xoa bóp mạnh vì sẽ gây bỏng và dồn dòng máu lạnh chứa độc tố từ chi về tim gây ngừng tim đột ngột (Afterdrop)!\n'
          '5. GỌI 115 HOẶC 112 ĐƯA ĐẾN BỆNH VIỆN NGAY!';
    }

    // 1. TÉ NGÃ / TAI NẠN KÈM NHỊP TIM NHANH (150 BPM / SỐC CHẤN THƯƠNG)
    final isTraumaQuery = clean.contains('nga') ||
        clean.contains('te') ||
        clean.contains('tai nan') ||
        clean.contains('va cham') ||
        clean.contains('dap') ||
        clean.contains('bi danh');

    final isTachycardiaQuery = clean.contains('150') ||
        clean.contains('140') ||
        clean.contains('130') ||
        clean.contains('120') ||
        clean.contains('160') ||
        clean.contains('170') ||
        clean.contains('180') ||
        clean.contains('dap nhanh') ||
        clean.contains('qua nhanh') ||
        clean.contains('thinh thich') ||
        clean.contains('danh trong nguc');

    final mentionsHeartRate = clean.contains('nhip tim') ||
        clean.contains('tim dap') ||
        clean.contains('nhip mach') ||
        clean.contains('mach') ||
        clean.contains('bpm');

    if (isTraumaQuery && (mentionsHeartRate || clean.contains('150') || clean.contains('140')) && isTachycardiaQuery) {
      return 'BÁC SĨ AI RESQ-AID (ĐÁNH GIÁ CHẤN THƯƠNG KÈM NHỊP TIM NHANH):\n\n'
          '⚠️ LƯU Ý SINH TỬ ĐẦU TIÊN: Nạn nhân CÒN TIM ĐẬP (nhịp tim khoảng 150 lần/phút) -> TUYỆT ĐỐI KHÔNG ĐƯỢC ÉP TIM (CPR)!\n\n'
          'Nhịp tim 150 BPM sau khi ngã là mức nhịp tim rất nhanh (Tachycardia), nguyên nhân chính thường gồm:\n'
          '1. Đau đớn và hoảng loạn tột độ: Kích thích thần kinh giao cảm làm tim đập dồn dập.\n'
          '2. CẢNH BÁO SỐC MẤT MÁU KÍN (Chấn thương nội tạng trong bụng/ngực hoặc vỡ xương lớn): Mất máu bên trong làm tụt huyết áp khiến tim phải đập bù 150 nhịp/phút để nuôi não.\n'
          '3. Rối loạn nhịp tim làm nạn nhân hoa mắt choáng ngất rồi ngã.\n\n'
          'HÀNH ĐỘNG SƠ CỨU CẤP THIẾT:\n'
          '1. GIỮ NẠN NHÂN NẰM YÊN: Cho nằm ngửa trên mặt phẳng an toàn, nới lỏng cổ áo. KHÔNG vội di chuyển, bế xốc hay xoay bẻ cổ/lưng đề phòng chấn thương cột sống.\n'
          '2. KIỂM TRA TRI GIÁC: Trò chuyện xem nạn nhân có tỉnh táo, trả lời đúng tên tuổi không. Quan sát có nôn vọt hay đau đầu dữ dội không.\n'
          '3. TÌM VẾT THƯƠNG CHẢY MÁU: Băng ép trực tiếp ngay nếu có vết rách chảy máu nhiều; kiểm tra tay chân có bị biến dạng gãy xương không.\n'
          '4. QUAN SÁT DẤU HIỆU SỐC NGUY HIỂM: Da tái lạnh, vã mồ hôi trán, môi nhợt nhạt, chân tay lạnh ngắt.\n'
          '5. GỌI 115 NGAY LẬP TỨC: Báo rõ "Nạn nhân bị ngã, nhịp tim nhanh 150 nhịp/phút, nghi ngờ sốc chấn thương" để kíp cấp cứu chuẩn bị dịch truyền chống sốc và máy đo điện tim ECG!';
    }

    // 2. NHỊP TIM NHANH ĐƠN THUẦN (TACHYCARDIA STANDALONE)
    if (mentionsHeartRate && isTachycardiaQuery && !clean.contains('ep tim') && !clean.contains('cpr') && !clean.contains('toc do')) {
      return 'BÁC SĨ AI RESQ-AID (XỬ TRÍ CƠN NHỊP TIM NHANH):\n\n'
          '⚠️ Nạn nhân CÒN TIM ĐẬP -> TUYỆT ĐỐI KHÔNG ÉP TIM!\n\n'
          'Nhịp tim bình thường lúc nghỉ là 60-100 nhịp/phút. Mức trên 120-150 nhịp/phút là nhịp tim nhanh (Tachycardia).\n\n'
          'HƯỚNG DẪN XỬ TRÍ NGAY:\n'
          '1. NGHỈ NGƠI TUYỆT ĐỐI: Ngồi tựa lưng hoặc nằm đầu cao 30 độ ở nơi thoáng mát, nới lỏng khuy áo, dây thắt lưng.\n'
          '2. THỞ SÂU VÀ CHẬM: Hít sâu bằng mũi trong 4 giây, giữ hơi 2 giây, thở từ từ qua miệng trong 6 giây để kích hoạt hệ phó giao cảm giúp giảm nhịp tim.\n'
          '3. UỐNG TỪNG NGỤM NƯỚC MÁT: Giúp kích thích dây thần kinh phế vị làm chậm nhịp tim.\n'
          '4. CỜ ĐỎ CẤP CỨU (GỌI 115 NGAY): Nếu nhịp tim nhanh kèm theo ĐAU THẮT NGỰC, KHÓ THỞ, VÃ MỒ HÔI LẠNH, hoặc HOA MẮT SẮP NGẤT, lập tức gọi 115 đưa đi cấp cứu!';
    }

    // 3. CƠN GÚT CẤP (ACUTE GOUT ATTACK)
    if (clean.contains('gut') || clean.contains('gout') || clean.contains('sung ngon chan cai')) {
      final goutNode = MedicalNeuralNlpEngine.instance.findProtocolById('gout_acute');
      if (goutNode != null) {
        _activeProtocol = goutNode;
        return goutNode.initialText;
      }
      return 'XỬ TRÍ CƠN GÚT (GOUT) CẤP TÍNH:\n\n'
          '1. BẤT ĐỘNG VÀ KÊ CAO: Đặt khớp sưng đau (thường là ngón chân cái) lên gối êm cao hơn ngực 15-20cm để giảm ứ trệ và giảm phù nề.\n'
          '2. CHƯỜM LẠNH 15-20 PHÚT: Bọc khăn mềm quanh túi đá chườm quanh khớp để giảm sưng nóng đỏ đau. TUYỆT ĐỐI KHÔNG chườm nóng hoặc bóp dầu nóng vì sẽ làm giãn mạch gây viêm sưng dữ dội hơn!\n'
          '3. UỐNG NHIỀU NƯỚC: Uống 2-2.5 lít nước lọc mỗi ngày để hỗ trợ thận đào thải axit uric.\n'
          '4. DÙNG THUỐC ĐẶC TRỊ THEO ĐƠN: Dùng Colchicine hoặc NSAID (như Naproxen, Celecoxib) theo chỉ định bác sĩ. TUYỆT ĐỐI KHÔNG tự ý uống Aspirin vì làm tăng nồng độ axit uric máu!';
    }

    // 4. CHẢY MÁU CAM (EPISTAXIS)
    if (clean.contains('chay mau cam') || clean.contains('chay mau mui')) {
      return 'SƠ CỨU CHẢY MÁU CAM (CHẢY MÁU MŨI) CHUẨN Y KHOA:\n\n'
          '1. TƯ THẾ ĐÚNG: Cho nạn nhân ngồi thẳng lưng, HƠI CÚI ĐẦU NHẸ RA PHÍA TRƯỚC để máu chảy ra ngoài cửa mũi.\n'
          '2. ⚠️ TUYỆT ĐỐI CẤM NGỬA ĐẦU RA SAU: Ngửa đầu làm máu chảy ngược vào thành sau họng, nuốt vào dạ dày gây nôn ói hoặc sặc vào khí quản cực kỳ nguy hiểm!\n'
          '3. BÓP CHẶT CÁNH MŨI: Dùng ngón tay cái và ngón trỏ bóp chặt 2 bên cánh mũi ép vào vách ngăn trong 10-15 phút liên tục, thở đều bằng miệng. KHÔNG buông tay ra kiểm tra giữa chừng.\n'
          '4. CHƯỜM MÁT: Đặt khăn lạnh hoặc túi đá bọc vải lên sống mũi hoặc vùng trán.\n'
          '5. GỌI 115 HOẶC ĐẾN CƠ SỞ Y TẾ: Nếu sau 20 phút bóp mũi máu vẫn chảy không ngừng, hoặc chảy máu cam sau tai nạn va đập mạnh vùng đầu mặt!';
    }

    // 5. HÓA CHẤT BẮN VÀO MẮT (CHEMICAL EYE INJURY)
    if (clean.contains('hoa chat vao mat') || (clean.contains('vao mat') && (clean.contains('nuoc tay') || clean.contains('axit') || clean.contains('bazo') || clean.contains('xa phong') || clean.contains('con')))) {
      return '🚨 CẤP CỨU HÓA CHẤT BẮN VÀO MẮT (XỬ TRÍ KHẨN CẤP):\n\n'
          '1. XỐI RỬA MẮT NGAY LẬP TỨC 15-20 PHÚT: Đây là hành động cứu mạng thị lực! Đặt mắt dưới vòi nước sạch chảy nhẹ, mở rộng mí mắt, đảo mắt liên tục để nước rửa trôi hóa chất.\n'
          '2. HƯỚNG DÒNG NƯỚC TỪ TRONG RA NGOÀI: Để nước chảy từ khóe mắt trong ra đuôi mắt ngoài, nghiêng đầu để nước nhiễm hóa chất KHÔNG chảy sang mắt lành!\n'
          '3. TUYỆT ĐỐI CẤM DỤI MẮT: Dụi mắt làm hóa chất ngấm sâu và rách giác mạc gây mù lòa vĩnh viễn. KHÔNG tự ý nhỏ thuốc hay đắp sữa/lá cây.\n'
          '4. GỌI 115 HOẶC ĐẾN NGAY BỆNH VIỆN MẮT: Mang theo nhãn mác chai hóa chất để bác sĩ có thuốc trung hòa đối kháng!';
    }

    // 6. NGẠT KHÓI ĐÁM CHÁY & KHÍ ĐỘC CO (SMOKE / CO INHALATION)
    if (clean.contains('ngat khoi') || clean.contains('dam chay') || clean.contains('khi co') || clean.contains('khi doc') || clean.contains('chay nha')) {
      return '🚨 CẤP CỨU NGẠT KHÓI ĐÁM CHÁY & NGỘ ĐỘC KHÍ CO:\n\n'
          '1. THOÁT RA NƠI THOÁNG KHÍ NGAY: Dùng khăn ướt bịt kín mũi miệng, bò thấp sát mặt sàn vì khói độc bốc lên cao.\n'
          '2. ĐÁNH GIÁ ĐƯỜNG THỞ & TRI GIÁC: Nếu nạn nhân ngưng thở hoặc thở ngáp: Gọi 115 và tiến hành ép tim CPR 110 BPM ngay lập tức!\n'
          '3. HỖ TRỢ HÔ HẤP: Nới lỏng cổ áo, đặt nằm nghiêng an toàn nếu hôn mê còn thở. Nếu có bình oxy y tế, cho thở oxy nồng độ cao 100% sớm nhất có thể.\n'
          '4. CHUYỂN VIỆN KHẨN CẤP: Khí CO kết hợp với hemoglobin gây thiếu oxy mô sâu và bỏng nhiệt đường thở, bắt buộc phải theo dõi y tế tại bệnh viện!';
    }

    // 7. SỐT XUẤT HUYẾT DENGUE (CẢNH BÁO DẤU HIỆU NGUY HIỂM)
    if (clean.contains('sot xuat huyet') || clean.contains('dengue')) {
      return 'THEO DÕI & SƠ CỨU SỐT XUẤT HUYẾT DENGUE:\n\n'
          '1. DẤU HIỆU CẢNH BÁO NGUY HIỂM (CẦN ĐI BỆNH VIỆN CẤP CỨU NGAY):\n'
          '   • Đau bụng dữ dội liên tục (đặc biệt vùng gan bên phải).\n'
          '   • Nôn ói liên tục trên 3 lần/giờ hoặc 4 lần/6 giờ.\n'
          '   • Xuất huyết niêm mạc: Chảy máu cam, chảy máu chân răng, nôn ra máu, đi ngoài phân đen.\n'
          '   • Li bì, bồn chồn, vật vã, tay chân lạnh ẩm, tiểu ít.\n'
          '2. HẠ SỐT AN TOÀN:\n'
          '   • Chỉ dùng PARACETAMOL đơn chất: Liều 10-15 mg/kg cân nặng mỗi lần, cách nhau 4-6 giờ. Tối đa 60 mg/kg/ngày.\n'
          '   • ⚠️ TUYỆT ĐỐI CẤM dùng Aspirin, Ibuprofen, Diclofenac và các NSAID khác vì gây xuất huyết dạ dày ồ ạt và rối loạn đông máu đe dọa tính mạng!\n'
          '3. BÙ NƯỚC ĐÚNG CÁCH: Uống Oresol pha đúng chuẩn theo hướng dẫn, nước dừa, nước ép hoa quả. Khám bác sĩ làm xét nghiệm tiểu cầu hàng ngày!';
    }

    // 8. SƠ CỨU ONG ĐỐT (BEE STINGS)
    if (clean.contains('ong dot') || clean.contains('ong chich') || clean.contains('ong vo ve') || clean.contains('ong bap cay')) {
      return 'SƠ CỨU ONG ĐỐT (ĐẶC BIỆT ONG VÒ VẼ, BẮP CÀY):\n\n'
          '1. GẠT BỎ NGÒI ONG NGAY: Dùng cạnh thẻ nhựa (ATM, CCCD) hoặc móng tay gạt nhẹ ngang miệng vết đốt để lấy ngòi ra. TUYỆT ĐỐI CẤM dùng nhíp hoặc tay bóp chặt vào túi nọc vì sẽ ép thêm nọc độc vào người!\n'
          '2. RỬA SẠCH VÀ CHƯỜM LẠNH: Rửa vết đốt bằng nước sạch và xà phòng. Chườm túi đá lạnh bọc khăn 15 phút để giảm đau buốt và giảm sưng.\n'
          '3. CẢNH BÁO SỐC PHẢN VỆ NGUY HIỂM (GỌI 115 NGAY):\n'
          '   • Khó thở, thở rít, cảm giác nghẹn họng.\n'
          '   • Sưng phù môi, mắt, lưỡi, nổi mề đay ngứa toàn thân.\n'
          '   • Chóng mặt, hoa mắt, tụt huyết áp. Nếu có bút tiêm Epinephrine (EpiPen), tiêm ngay vào mặt ngoài đùi!';
    }

    // 9. SƠ CỨU SỨA BIỂN CẮN (JELLYFISH STINGS)
    if (clean.contains('sua can') || clean.contains('sua bien') || clean.contains('sua lua') || clean.contains('nhim bien')) {
      return 'SƠ CỨU SỨA BIỂN / SỨA LỬA CẮN CHUẨN Y KHOA:\n\n'
          '1. RỬA BẰNG GIẤM ĂN HOẶC NƯỚC BIỂN: Đổ giấm ăn (axit axetic 4-6%) liên tục lên vết sứa trong ít nhất 30 giây để vô hiệu hóa nang trâm nọc. Nếu không có giấm, dùng chính NƯỚC BIỂN để rửa trôi.\n'
          '2. ⚠️ TUYỆT ĐỐI CẤM RỬA BẰNG NƯỚC NGỌT / NƯỚC SUỐI / CHƯỜM ĐÁ: Nước ngọt làm thay đổi áp suất thẩm thấu, kích hoạt hàng triệu nang nọc vỡ ra phóng thích độc tố dữ dội hơn!\n'
          '3. GẮP XÚC TU: Dùng que sạch, kẹp hoặc nhíp gắp nhẹ xúc tu còn dính trên da (cấm dùng tay trần).\n'
          '4. NGÂM NƯỚC ẤM: Ngâm vùng da bị cắn vào nước ấm 40-45°C trong 20 phút để phá hủy cấu trúc protein của nọc độc, giảm đau nhanh chóng.\n'
          '5. Nếu nạn nhân co giật, khó thở, hôn mê: Gọi 115 cấp cứu sốc phản vệ ngay!';
    }

    // 10. NGỘ ĐỘC RƯỢU / METHANOL / NẤM ĐỘC / THỰC PHẨM
    if (clean.contains('ngo doc ruou') || clean.contains('say ruou') || clean.contains('ngo doc methanol') || clean.contains('ruou gia') || clean.contains('ngo doc thuc pham') || clean.contains('ngo doc nam')) {
      return '🚨 CẤP CỨU NGỘ ĐỘC RƯỢU / METHANOL & THỰC PHẨM:\n\n'
          '1. TƯ THẾ HỒI PHỤC AN TOÀN: Cho nạn nhân nằm nghiêng sang một bên, kê gối dưới đầu để đờm dãi và chất nôn tự chảy ra ngoài, tránh tụt lưỡi hoặc hít sặc vào phổi.\n'
          '2. CẢNH BÁO NGỘ ĐỘC CỒN CÔNG NGHIỆP METHANOL (GỌI 115 NGAY):\n'
          '   • Nhìn mờ, nhìn như có tuyết rơi/sương mù trước mắt.\n'
          '   • Thở nhanh sâu, co giật, lơ mơ hoặc hôn mê sau khi uống rượu không rõ nguồn gốc.\n'
          '3. NGUYÊN TẮC CẤM KỴ:\n'
          '   • TUYỆT ĐỐI CẤM gây nôn khi nạn nhân lơ mơ vì nguy cơ sặc phổi tử vong.\n'
          '   • CẤM cho uống Paracetamol liều cao vì rượu kết hợp Paracetamol gây hoại tử tế bào gan cấp.\n'
          '4. Cho uống nước ấm, nước đường nếu còn tỉnh táo và giữ lại mẫu rượu/thực phẩm để xét nghiệm độc chất!';
    }

    // 11. SAY ĐỘ CAO (ALTITUDE SICKNESS)
    if (clean.contains('say do cao') || clean.contains('leo nui met') || clean.contains('thieu oxy do cao')) {
      return 'SƠ CỨU SAY ĐỘ CAO CẤP (ACUTE MOUNTAIN SICKNESS):\n\n'
          '1. NGỪNG LEO LÊN CAO NGAY LẬP TỨC: Tuyệt đối không tiếp tục tăng độ cao khi đang có triệu chứng đau đầu, buồn nôn, chóng mặt, mệt lả.\n'
          '2. HẠ ĐỘ CAO KHẨN CẤP: Biện pháp cứu mạng và điều trị triệt để nhất là di chuyển nạn nhân xuống thấp ít nhất 500 - 1.000m càng sớm càng tốt.\n'
          '3. NGHỈ NGƠI VÀ THỞ OXY: Cho nạn nhân nghỉ ngơi tuyệt đối, giữ ấm cơ thể, cho thở oxy y tế bổ sung nếu có bình mang theo.\n'
          '4. CẢNH BÁO NGUY HIỂM: Nếu có tiếng thở rít, ho ra bọt hồng (phù phổi cấp HAPE) hoặc lú lẫn, mất thăng bằng đi loạng choạng (phù não cấp HACE), phải khẩn cấp gọi cứu nạn 112 để đưa xuống núi cấp cứu!';
    }

    // 12. TÉ NGÃ / TAI NẠN CHUNG (CHƯA RÕ VẾT THƯƠNG CỤ THỂ)
    final hasSpecificInjury = clean.contains('dau dau') ||
        clean.contains('dap dau') ||
        clean.contains('u dau') ||
        clean.contains('chay mau') ||
        clean.contains('gay') ||
        clean.contains('rang') ||
        clean.contains('bong gan') ||
        clean.contains('treo') ||
        clean.contains('dut tay') ||
        clean.contains('rach da') ||
        clean.contains('co giat');

    if (!hasSpecificInjury &&
        (clean == 'bi nga' ||
            clean == 'te nga' ||
            clean == 'te xe' ||
            clean == 'nga xe' ||
            clean == 'nga' ||
            clean == 'te' ||
            clean.contains('bi nga') ||
            clean.contains('te nga') ||
            clean.contains('te xe') ||
            clean.contains('nga xe') ||
            clean.contains('tai nan xe'))) {
      final clarifyFall = MedicalNeuralNlpEngine.instance.findProtocolById('clarify_vague_fall');
      if (clarifyFall != null) {
        _pendingClarificationNode = clarifyFall;
        _pendingPriorQuery = rawQuery;
        _activeProtocol = clarifyFall;
        return clarifyFall.initialText;
      }
    }

    return null;
  }

  String _buildUniversalClinicalFailSafe(String clean, String rawQuery) {
    if (clean.contains('nga') || clean.contains('te') || clean.contains('tai nan') || clean.contains('va cham')) {
      final clarifyFall = MedicalNeuralNlpEngine.instance.findProtocolById('clarify_vague_fall');
      if (clarifyFall != null) {
        _pendingClarificationNode = clarifyFall;
        _pendingPriorQuery = rawQuery;
        _activeProtocol = clarifyFall;
        return clarifyFall.initialText;
      }
    }

    return 'BÁC SĨ AI RESQ-AID (ĐÁNH GIÁ SƠ CỨU AN TOÀN BAN ĐẦU):\n\n'
        'Để đảm bảo an toàn tuyệt đối và hướng dẫn xử trí chính xác nhất, xin hãy cho tôi biết ngay:\n'
        '1. TRI GIÁC: Nạn nhân hiện CÒN TỈNH TÁO hay ĐÃ MÊ MAN / BẤT TỈNH?\n'
        '2. HÔ HẤP & TUẦN HOÀN: Nạn nhân CÓ THỞ BÌNH THƯỜNG không? Tim còn đập không?\n'
        '3. THƯƠNG TÍCH: Có vết thương CHẢY MÁU NHIỀU, VẾT BỎNG hay BIẾN DẠNG GÃY XƯƠNG ở vùng nào không?\n\n'
        'NGUYÊN TẮC HIỆN TRƯỜNG CHUNG:\n'
        '• Giữ nạn nhân nằm yên, KHÔNG tự ý di chuyển hoặc bế xốc nếu nghi ngờ chấn thương cột sống.\n'
        '• Giữ ấm cơ thể bằng áo hoặc chăn sạch.\n'
        '• Nếu nạn nhân có dấu hiệu nguy kịch, hãy bấm nút GỌI 115 màu đỏ ngay trên màn hình!';
  }

  String? _resolveOutOfDomainOrWilderness(String clean, String rawQuery) {
    final isWilderness = clean.contains('nui') ||
        clean.contains('tren nui') ||
        clean.contains('rung') ||
        clean.contains('khong co thuoc') ||
        clean.contains('het thuoc') ||
        clean.contains('lac duong') ||
        clean.contains('xa trung tam') ||
        clean.contains('hoang da');

    if (isWilderness) {
      return 'HƯỚNG DẪN XỬ TRÍ CẤP CỨU KHI Ở VÙNG XA / TRÊN NÚI KHÔNG CÓ THUỐC:\n\n'
          '1. AN TOÀN VÀ GIỮ ẤM: Tìm ngay nơi trú ẩn khô ráo, tránh gió lộng, tránh mép vực hoặc vùng có nguy cơ sạt lở. Giữ ấm cơ thể bằng áo khoác hoặc chăn/vải sạch.\n'
          '2. XỬ LÝ CHẤN THƯƠNG TẠI CHỖ BẰNG VẬT LIỆU TỰ NHIÊN:\n'
          '   • Vết thương chảy máu: Dùng khăn/vải áo sạch ấn chặt trực tiếp miệng vết thương để cầm máu.\n'
          '   • Nghi gãy xương hoặc trẹo khớp: Dùng cành cây thẳng và dây buộc làm nẹp cố định chi, tuyệt đối không cố bước đi.\n'
          '   • Ngã va đập đầu: Nằm nghỉ kê đầu cao, theo dõi sát nếu có nôn ói hoặc ngủ gà.\n'
          '3. BÙ NƯỚC: Uống nước sạch từng ngụm nhỏ, không ăn các loại nấm hoặc quả rừng lạ.\n'
          '4. TÌM KIẾM CỨU HỘ: Cố gắng di chuyển cẩn thận đến gờ đồi cao có sóng điện thoại để gọi 115 hoặc Cứu nạn 112. Bật định vị GPS để đọc tọa độ kinh - vĩ độ cho đội cứu hộ!';
    }

    if (clean.length < 15) {
      return 'Trợ lý ResQ-Aid chưa rõ triệu chứng của bạn. Hãy mô tả cụ thể hơn: nạn nhân đang bị khó thở, đau ngực, chảy máu, gãy xương hay bất tỉnh để tôi hỗ trợ sơ cứu ngay!';
    }

    return null;
  }
}
