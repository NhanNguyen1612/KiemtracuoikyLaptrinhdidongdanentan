import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'neural_tensor_runtime.dart';

class ClinicalProtocolNode {
  final int index;
  final String id;
  final String topic;
  final int urgency;
  final int comorbidRank;
  final bool isClarification;
  final String? clarificationTag;
  final bool isFacilityLookup;
  final String initialText;
  final String detailedText;
  final String? legVariantText;

  const ClinicalProtocolNode({
    required this.index,
    required this.id,
    required this.topic,
    required this.urgency,
    required this.comorbidRank,
    required this.isClarification,
    this.clarificationTag,
    required this.isFacilityLookup,
    required this.initialText,
    required this.detailedText,
    this.legVariantText,
  });

  factory ClinicalProtocolNode.fromJson(int idx, Map<String, dynamic> json) {
    return ClinicalProtocolNode(
      index: idx,
      id: json['id'] as String,
      topic: json['topic'] as String? ?? 'general',
      urgency: (json['urgency'] as num?)?.toInt() ?? 2,
      comorbidRank: (json['comorbidRank'] as num?)?.toInt() ?? 5,
      isClarification: json['isClarification'] == true,
      clarificationTag: json['clarificationTag'] as String?,
      isFacilityLookup: json['isFacilityLookup'] == true,
      initialText: json['initial'] as String,
      detailedText: json['detailed'] as String,
      legVariantText: json['legVariant'] as String?,
    );
  }
}

class NeuralNlpPrediction {
  final Float32List embedding128d;
  final ClinicalProtocolNode topProtocol;
  final double topCosineSimilarity;
  final double topDocProbability;
  final double docEntropy;
  final List<ClinicalProtocolNode> comorbidProtocols;
  final int safetyClassIndex; // 0=NONE, 1=CARDIAC_P0, 2=ARTERIAL_P0, 3=CHOKING_P0, 4=SEIZURE_P1, 5=ANAPHYLAXIS_P1
  final double safetyConfidence;
  final bool isUnsafeFolkRemedy;
  final double unsafeRemedyProb;
  final int voiceCommandIndex; // 0=UNKNOWN, 1=START, 2=PAUSE, 3=RESUME, 4=SPEAKER, 5=HANDOVER
  final double voiceCommandProb;
  final int bodySlotIndex; // 0=GENERAL, 1=LEG_FOOT, 2=ARM_HAND, 3=HEAD_FACE
  final int discourseModeIndex; // 0=STANDALONE, 1=ASK_DETAIL, 2=ELABORATE_FOLLOWUP, 3=COMORBID
  final int latencyUs;

  const NeuralNlpPrediction({
    required this.embedding128d,
    required this.topProtocol,
    required this.topCosineSimilarity,
    required this.topDocProbability,
    required this.docEntropy,
    required this.comorbidProtocols,
    required this.safetyClassIndex,
    required this.safetyConfidence,
    required this.isUnsafeFolkRemedy,
    required this.unsafeRemedyProb,
    required this.voiceCommandIndex,
    required this.voiceCommandProb,
    required this.bodySlotIndex,
    required this.discourseModeIndex,
    required this.latencyUs,
  });
}

/// ĐỘNG CƠ NGÔN NGỮ Y KHOA THUẦN MẠNG NƠ-RON ON-DEVICE (MEDICAL NEURAL BI-ENCODER + VECTOR RAG)
/// Kiến trúc: Subword Character N-Gram Embedding -> Conv1D(k=3, Negation-Aware) -> Dual Pool
/// -> Dense Projection (128D L2 Unit Sphere) -> Vector RAG Cosine Search + 5 Multi-Task Neural Heads.
/// KHÔNG sử dụng chuỗi if-else bắt từ khóa thủ công.
class MedicalNeuralNlpEngine {
  static final MedicalNeuralNlpEngine instance = MedicalNeuralNlpEngine._();
  MedicalNeuralNlpEngine._();

  static const int hashBuckets = 3072;
  static const int seqLen = 20;
  static const int tokDim = 64;
  static const int convDim = 128;
  static const int embDim = 128;

  static const String _withDia = 'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
  static const String _withoutDia = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';
  static final RegExp _trimPunct = RegExp(r'''^[.,!?;:()\[\]"']+|[.,!?;:()\[\]"']+$''');
  static final RegExp _wsSplit = RegExp(r'\s+');

  BinaryWeightArchive? _weights;
  List<ClinicalProtocolNode> _protocols = [];
  bool _initialized = false;

  bool get isInitialized => _initialized;
  int get protocolCount => _protocols.length;

  /// Khởi tạo bất đồng bộ qua Flutter AssetBundle (dùng khi mở ứng dụng Android/iOS)
  Future<void> initialize() async {
    if (_initialized) return;
    try {
      final binData = await rootBundle.load('assets/models/medical_nlp_weights.bin');
      final kbStr = await rootBundle.loadString('assets/models/clinical_protocols_kb.json');
      _loadFromRaw(binData.buffer.asUint8List(), kbStr);
    } catch (_) {
      ensureInitializedSync();
    }
  }

  /// Khởi tạo đồng bộ tức thì cho các hàm đồng bộ và môi trường Unit Test
  void ensureInitializedSync() {
    if (_initialized) return;
    final candidateDirs = [
      'assets/models',
      'mobile/assets/models',
      '../mobile/assets/models',
    ];
    for (final dir in candidateDirs) {
      final binFile = File('$dir/medical_nlp_weights.bin');
      final kbFile = File('$dir/clinical_protocols_kb.json');
      if (binFile.existsSync() && kbFile.existsSync()) {
        final binBytes = binFile.readAsBytesSync();
        final kbStr = kbFile.readAsStringSync(encoding: utf8);
        _loadFromRaw(binBytes, kbStr);
        return;
      }
    }
    throw StateError('Không tìm thấy trọng số mạng nơ-ron medical_nlp_weights.bin');
  }

  void _loadFromRaw(Uint8List binBytes, String kbJsonStr) {
    _weights = BinaryWeightArchive.fromBytes(binBytes, 'RQNL');
    final rawList = jsonDecode(kbJsonStr) as List<dynamic>;
    _protocols = [
      for (int i = 0; i < rawList.length; i++)
        ClinicalProtocolNode.fromJson(i, rawList[i] as Map<String, dynamic>),
    ];
    _initialized = true;
    // Khởi động nóng bộ biên dịch JIT cho các toán tử Tensor Conv1D/MatMul (< 1ms từ lần gọi đầu tiên)
    infer('khởi động');
  }

  static String stripDiacritics(String input) {
    final sb = StringBuffer();
    final lower = input.toLowerCase();
    for (int i = 0; i < lower.length; i++) {
      final ch = lower[i];
      final idx = _withDia.indexOf(ch);
      sb.write(idx >= 0 ? _withoutDia[idx] : ch);
    }
    return sb.toString();
  }

  static int _fnv1a32(List<int> utf8Bytes) {
    int h = 0x811C9DC5;
    for (final b in utf8Bytes) {
      h ^= b;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h;
  }

  static List<int> _extractTokenBuckets(String rawWord) {
    final w = rawWord.replaceAll(_trimPunct, '').toLowerCase();
    if (w.isEmpty) return const [];
    final noDia = stripDiacritics(w);
    final feats = <String>['w:$w', 'd:$noDia'];
    final padded = '#$noDia#';
    if (padded.length >= 3) {
      for (int i = 0; i <= padded.length - 3; i++) {
        feats.add('g3:${padded.substring(i, i + 3)}');
      }
    }
    if (padded.length >= 4) {
      for (int i = 0; i <= padded.length - 4; i++) {
        feats.add('g4:${padded.substring(i, i + 4)}');
      }
    }
    return [
      for (final f in feats) _fnv1a32(utf8.encode(f)) % hashBuckets,
    ];
  }

  /// Thực thi suy luận chuỗi Mạng Nơ-ron (Sparse Subword Lookup -> Conv1D -> Pool -> Dense -> Vector RAG + 5 Heads)
  NeuralNlpPrediction infer(String rawText) {
    ensureInitializedSync();
    final sw = Stopwatch()..start();

    final t = _weights!.tensors;
    final logitScale = _weights!.temperature;
    final tokTable = t[0].data; // [3072 * 64]

    final cleanWords = rawText
        .trim()
        .toLowerCase()
        .split(_wsSplit)
        .where((w) => w.replaceAll(_trimPunct, '').isNotEmpty)
        .toList();

    final selectedWords = cleanWords.length > seqLen
        ? [...cleanWords.sublist(0, 12), ...cleanWords.sublist(cleanWords.length - (seqLen - 12))]
        : cleanWords;

    // 1. Sparse Subword & N-gram Embedding Bag Lookup -> [seqLen * tokDim]
    final seqEmb = Float32List(seqLen * tokDim);
    final validPositions = <int>[];

    for (int pos = 0; pos < selectedWords.length && pos < seqLen; pos++) {
      final buckets = _extractTokenBuckets(selectedWords[pos]);
      if (buckets.isNotEmpty) {
        validPositions.add(pos);
        final inv = 1.0 / buckets.length;
        final dstBase = pos * tokDim;
        for (final b in buckets) {
          final srcBase = b * tokDim;
          for (int d = 0; d < tokDim; d++) {
            seqEmb[dstBase + d] += tokTable[srcBase + d] * inv;
          }
        }
      }
    }

    // 2. Conv1D (k=3, padding=1, ReLU) nhận diện cửa sổ ngữ cảnh & phủ định
    final convOut = NeuralTensorRuntime.conv1dSameRelu(
      input: seqEmb,
      seqLen: seqLen,
      cIn: tokDim,
      weightsOki: t[1].data,
      bias: t[2].data,
      kSize: 3,
      cOut: convDim,
    );

    // 3. Masked Mean Pool + Masked Max Pool -> [256]
    final pooled = Float32List(convDim * 2);
    if (validPositions.isNotEmpty) {
      final invLen = 1.0 / validPositions.length;
      for (int c = 0; c < convDim; c++) {
        double sum = 0.0;
        double maxV = double.negativeInfinity;
        for (final pos in validPositions) {
          final v = convOut[pos * convDim + c];
          sum += v;
          if (v > maxV) maxV = v;
        }
        pooled[c] = sum * invLen;
        pooled[convDim + c] = maxV;
      }
    }

    // 4. Dense Projection -> L2 Normalized 128D Semantic Vector e
    final h1 = NeuralTensorRuntime.linear(
      input: pooled,
      weightsOutIn: t[3].data,
      bias: t[4].data,
      inDim: convDim * 2,
      outDim: embDim,
      relu: true,
    );
    final rawEmb128 = NeuralTensorRuntime.linear(
      input: h1,
      weightsOutIn: t[5].data,
      bias: t[6].data,
      inDim: embDim,
      outDim: embDim,
    );
    final unitEmb = NeuralTensorRuntime.l2Normalize(rawEmb128);

    // 5. Vector RAG Cosine Similarity Search over Protocol Matrix D [N_docs, 128]
    final numDocs = _protocols.length;
    final cosScores = NeuralTensorRuntime.cosineSimilaritySearch(
      unitQuery: unitEmb,
      unitDocMatrix: t[7].data,
      numDocs: numDocs,
      dim: embDim,
    );
    final docBias = t[8].data;
    final docLogits = Float32List(numDocs);
    for (int i = 0; i < numDocs; i++) {
      docLogits[i] = cosScores[i] * logitScale + docBias[i];
    }
    final docProbs = NeuralTensorRuntime.softmax(docLogits);
    final docEntropy = NeuralTensorRuntime.normalizedEntropy(docProbs);

    int bestDocIdx = 0;
    double bestProb = docProbs[0];
    for (int i = 1; i < numDocs; i++) {
      if (docProbs[i] > bestProb) {
        bestProb = docProbs[i];
        bestDocIdx = i;
      }
    }

    // Multi-label comorbid sigmoid check
    final comorbidList = <ClinicalProtocolNode>[];
    for (int i = 0; i < numDocs; i++) {
      final sig = NeuralTensorRuntime.sigmoid(docLogits[i]);
      if (sig >= 0.52 && !_protocols[i].isClarification && !_protocols[i].isFacilityLookup) {
        comorbidList.add(_protocols[i]);
      }
    }
    comorbidList.sort((a, b) => a.comorbidRank.compareTo(b.comorbidRank));

    // 6. Multi-Task Heads (Safety L0, Guardrail, Voice Command, Body Slot, Discourse Mode)
    final safLogits = NeuralTensorRuntime.linear(
      input: unitEmb,
      weightsOutIn: t[9].data,
      bias: t[10].data,
      inDim: embDim,
      outDim: 6,
    );
    final safProbs = NeuralTensorRuntime.softmax(safLogits);
    final safMax = _argmax(safProbs);

    final grdLogits = NeuralTensorRuntime.linear(
      input: unitEmb,
      weightsOutIn: t[11].data,
      bias: t[12].data,
      inDim: embDim,
      outDim: 2,
    );
    final grdProbs = NeuralTensorRuntime.softmax(grdLogits);

    final vcmLogits = NeuralTensorRuntime.linear(
      input: unitEmb,
      weightsOutIn: t[13].data,
      bias: t[14].data,
      inDim: embDim,
      outDim: 6,
    );
    final vcmProbs = NeuralTensorRuntime.softmax(vcmLogits);
    final vcmMax = _argmax(vcmProbs);

    final bodLogits = NeuralTensorRuntime.linear(
      input: unitEmb,
      weightsOutIn: t[15].data,
      bias: t[16].data,
      inDim: embDim,
      outDim: 4,
    );
    final bodMax = _argmax(NeuralTensorRuntime.softmax(bodLogits));

    final dscLogits = NeuralTensorRuntime.linear(
      input: unitEmb,
      weightsOutIn: t[17].data,
      bias: t[18].data,
      inDim: embDim,
      outDim: 4,
    );
    final dscMax = _argmax(NeuralTensorRuntime.softmax(dscLogits));

    sw.stop();

    return NeuralNlpPrediction(
      embedding128d: unitEmb,
      topProtocol: _protocols[bestDocIdx],
      topCosineSimilarity: cosScores[bestDocIdx],
      topDocProbability: bestProb,
      docEntropy: docEntropy,
      comorbidProtocols: comorbidList,
      safetyClassIndex: safMax.index,
      safetyConfidence: safMax.prob,
      isUnsafeFolkRemedy: grdProbs[1] > 0.55,
      unsafeRemedyProb: grdProbs[1],
      voiceCommandIndex: vcmMax.index,
      voiceCommandProb: vcmMax.prob,
      bodySlotIndex: bodMax.index,
      discourseModeIndex: dscMax.index,
      latencyUs: math.max(50, sw.elapsedMicroseconds),
    );
  }

  ClinicalProtocolNode? findProtocolById(String id) {
    ensureInitializedSync();
    for (final p in _protocols) {
      if (p.id == id) return p;
    }
    return null;
  }

  ClinicalProtocolNode? findProtocolByTopicName(String topicHint) {
    ensureInitializedSync();
    final lower = topicHint.toLowerCase();
    for (final p in _protocols) {
      if (p.topic.toLowerCase() == lower || p.id.toLowerCase().contains(lower)) {
        return p;
      }
    }
    return null;
  }

  static ({int index, double prob}) _argmax(Float32List probs) {
    int bestI = 0;
    double bestP = probs[0];
    for (int i = 1; i < probs.length; i++) {
      if (probs[i] > bestP) {
        bestP = probs[i];
        bestI = i;
      }
    }
    return (index: bestI, prob: bestP);
  }
}
