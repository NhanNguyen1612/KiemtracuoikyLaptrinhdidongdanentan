import 'package:flutter/services.dart';
import '../../../../core/ai/medical_neural_nlp_engine.dart';

enum CprVoiceAction {
  start, // 1: Bắt đầu ép tim
  pause, // 2: Tạm dừng
  resume, // 3: Tiếp tục
  toggleSpeaker, // 4: Loa ngoài
  handover, // 5: Bàn giao y tế 115
  unknown, // 0: Ngoài khẩu lệnh điều khiển
}

class VoiceRecognitionResult {
  final String text;
  final double confidence;
  final CprVoiceAction action;
  final bool isExecuted;

  const VoiceRecognitionResult({
    required this.text,
    required this.confidence,
    required this.action,
    required this.isExecuted,
  });
}

/// Động cơ nhận diện Khẩu lệnh Rảnh tay CPR bằng Head Phân loại Mạng Nơ-ron (Zero if-else)
class VoiceCommandEngine {
  static const double confidenceThreshold = 0.75;

  static const List<CprVoiceAction> _indexToAction = [
    CprVoiceAction.unknown,
    CprVoiceAction.start,
    CprVoiceAction.pause,
    CprVoiceAction.resume,
    CprVoiceAction.toggleSpeaker,
    CprVoiceAction.handover,
  ];

  VoiceRecognitionResult processUtterance(String rawText, {double confidence = 0.85}) {
    final normalized = rawText.trim().toLowerCase();
    if (normalized.isEmpty) {
      return const VoiceRecognitionResult(
        text: '',
        confidence: 0.0,
        action: CprVoiceAction.unknown,
        isExecuted: false,
      );
    }

    final pred = MedicalNeuralNlpEngine.instance.infer(normalized);
    final CprVoiceAction action = (pred.voiceCommandIndex >= 1 &&
            pred.voiceCommandIndex < _indexToAction.length &&
            pred.voiceCommandProb >= 0.65)
        ? _indexToAction[pred.voiceCommandIndex]
        : CprVoiceAction.unknown;

    final effectiveConf = confidence < confidenceThreshold ? confidence : pred.voiceCommandProb * confidence / 0.85;
    final isExecuted = action != CprVoiceAction.unknown && confidence >= confidenceThreshold;

    if (isExecuted) {
      SystemSound.play(SystemSoundType.click);
      HapticFeedback.selectionClick();
    }

    return VoiceRecognitionResult(
      text: normalized,
      confidence: effectiveConf.clamp(0.0, 1.0),
      action: action,
      isExecuted: isExecuted,
    );
  }
}
