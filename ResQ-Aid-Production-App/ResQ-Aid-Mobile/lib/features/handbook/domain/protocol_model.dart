import 'dart:convert';

class ProtocolStep {
  final int step;
  final String title;
  final String instruction;
  final String? warning;

  ProtocolStep({
    required this.step,
    required this.title,
    required this.instruction,
    this.warning,
  });

  factory ProtocolStep.fromJson(Map<String, dynamic> json) => ProtocolStep(
    step: json['step'] as int,
    title: json['title'] as String,
    instruction: json['instruction'] as String,
    warning: json['warning'] as String?,
  );
}

class ProtocolDetail {
  final String target;
  final String quickSummary;
  final List<ProtocolStep> steps;
  final List<String> contraindications;

  ProtocolDetail({
    required this.target,
    required this.quickSummary,
    required this.steps,
    required this.contraindications,
  });

  factory ProtocolDetail.fromJsonString(String jsonStr) {
    final Map<String, dynamic> map = jsonDecode(jsonStr) as Map<String, dynamic>;
    final stepsList = (map['steps'] as List)
        .map((e) => ProtocolStep.fromJson(e as Map<String, dynamic>))
        .toList();
    final contraList = (map['contraindications'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    return ProtocolDetail(
      target: map['target'] as String? ?? 'Mọi lứa tuổi',
      quickSummary: map['quick_summary'] as String? ?? '',
      steps: stepsList,
      contraindications: contraList,
    );
  }
}
