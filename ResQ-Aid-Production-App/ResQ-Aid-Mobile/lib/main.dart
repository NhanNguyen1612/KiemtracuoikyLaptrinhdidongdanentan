import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/ai/medical_neural_nlp_engine.dart';
import 'core/services/tflite_vision_service.dart';
import 'core/theme/app_theme.dart';
import 'features/home/presentation/home_screen.dart';
import 'features/voice_assistant/presentation/floating_voice_bubble.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Khởi tạo sẵn các động cơ Mạng Nơ-ron On-Device (MedicalNlpNet 128D + TraumaVisionNet CNN)
  await Future.wait([
    MedicalNeuralNlpEngine.instance.initialize(),
    TfliteVisionService().initialize(),
  ]);
  runApp(
    const ProviderScope(
      child: ResQAidApp(),
    ),
  );
}

class ResQAidApp extends StatelessWidget {
  const ResQAidApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      title: 'ResQ-Aid v2.0',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      home: const HomeScreen(),
      builder: (context, child) {
        return Stack(
          children: [
            if (child != null) child,
            const GlobalFloatingVoiceBubble(),
          ],
        );
      },
    );
  }
}
