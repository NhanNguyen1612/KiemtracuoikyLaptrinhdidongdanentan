import 'dart:math';
import '../ai/medical_neural_nlp_engine.dart';
import 'medical_dialogue_brain.dart';

enum MatchTier {
  exact,
  fuzzySynonym,
  symptomMapping,
  clarification,
  fallback,
}

class HybridMatchResult {
  final MedicalTopic topic;
  final double confidence;
  final MatchTier tier;
  final List<String> matchedSymptoms;
  final String? suggestedExplanation;
  final String? clarificationQuestion;
  final String? clarificationType;

  const HybridMatchResult({
    required this.topic,
    required this.confidence,
    required this.tier,
    this.matchedSymptoms = const [],
    this.suggestedExplanation,
    this.clarificationQuestion,
    this.clarificationType,
  });
}

/// Tiện ích khoảng cách chuỗi toán học Levenshtein (phục vụ chuẩn đo lường biến dạng ký tự)
class FuzzyMatcher {
  static int levenshtein(String s, String t) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;

    List<int> v0 = List<int>.filled(t.length + 1, 0);
    List<int> v1 = List<int>.filled(t.length + 1, 0);

    for (int i = 0; i <= t.length; i++) {
      v0[i] = i;
    }

    for (int i = 0; i < s.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < t.length; j++) {
        final cost = (s[i] == t[j]) ? 0 : 1;
        v1[j + 1] = min(v1[j] + 1, min(v0[j + 1] + 1, v0[j] + cost));
      }
      for (int j = 0; j <= t.length; j++) {
        v0[j] = v1[j];
      }
    }
    return v1[t.length];
  }

  static double similarity(String s, String t) {
    final sClean = MedicalDialogueBrain.removeDiacritics(s.trim().toLowerCase());
    final tClean = MedicalDialogueBrain.removeDiacritics(t.trim().toLowerCase());
    if (sClean == tClean) return 1.0;
    final maxLen = max(sClean.length, tClean.length);
    if (maxLen == 0) return 1.0;
    return max(0.0, 1.0 - (levenshtein(sClean, tClean) / maxLen));
  }
}

/// Bộ nhớ Trạng thái Đối thoại Đa lượt (Latent Turn History)
class ContextAccumulator {
  final List<String> pastUserQueries = [];
  MedicalTopic? pendingTopic;
  String? pendingClarificationType;

  void addTurn(String query) {
    pastUserQueries.add(query);
  }

  String get mergedContext => pastUserQueries.join(' ');

  void clear() {
    pastUserQueries.clear();
    pendingTopic = null;
    pendingClarificationType = null;
  }
}

/// ĐỘNG CƠ SUY LUẬN TRIỆU CHỨNG THUẦN VECTOR RAG (THAY THẾ TOÀN BỘ SYMPTOM IF-ELSE RULES)
/// Ánh xạ trực tiếp câu hỏi sang không gian nhúng 128 chiều của MedicalNlpNet.
class HybridAiEngine {
  static final HybridAiEngine _instance = HybridAiEngine._internal();
  factory HybridAiEngine() => _instance;
  HybridAiEngine._internal();

  HybridMatchResult analyze(String query, {ContextAccumulator? context}) {
    final pred = MedicalNeuralNlpEngine.instance.infer(query);
    final node = pred.topProtocol;
    final topic = MedicalDialogueBrain.topicFromName(node.topic);

    if (node.isClarification) {
      return HybridMatchResult(
        topic: topic,
        confidence: pred.topDocProbability,
        tier: MatchTier.clarification,
        clarificationType: node.clarificationTag,
        clarificationQuestion: node.initialText,
      );
    }

    return HybridMatchResult(
      topic: topic,
      confidence: pred.topDocProbability,
      tier: pred.topCosineSimilarity > 0.72 ? MatchTier.exact : MatchTier.symptomMapping,
    );
  }
}
