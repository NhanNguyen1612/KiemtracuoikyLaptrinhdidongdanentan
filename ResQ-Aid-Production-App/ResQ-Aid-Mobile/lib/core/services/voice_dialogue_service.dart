import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'tts_service.dart';
import 'medical_dialogue_brain.dart';
import 'medical_safety_router.dart';

/// Đại diện cho một lượt thoại trong phiên đối thoại y tế 2 chiều
class DialogueTurn {
  final bool isUser;
  final String text;
  final DateTime timestamp;

  const DialogueTurn({
    required this.isUser,
    required this.text,
    required this.timestamp,
  });
}

/// Dịch vụ đối thoại 2 chiều thông minh rảnh tay (Speech-to-Text & Text-to-Speech)
/// Thiết kế chuyên biệt cho cấp cứu: Ép tim CPR, quét camera vết thương, kiểm tra tư thế
class VoiceDialogueService {
  static final VoiceDialogueService _instance = VoiceDialogueService._internal();
  factory VoiceDialogueService() => _instance;
  VoiceDialogueService._internal();

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;
  bool _isAiSpeaking = false;
  bool _continuousLiveMode = false;
  Timer? _resumeTimer;
  Timer? _speechDebounceTimer;
  DateTime? _echoGuardUntil;
  String _currentTranscript = '';
  String _lastAiResponse = '';
  final List<DialogueTurn> _conversationHistory = [];

  // Listeners
  final List<VoidCallback> _listeners = [];

  bool get isListening => _isListening;
  bool get isAiSpeaking => _isAiSpeaking;
  bool get isInitialized => _isInitialized;
  bool get continuousLiveMode => _continuousLiveMode;
  set continuousLiveMode(bool val) {
    _continuousLiveMode = val;
    _notify();
  }
  String get currentTranscript => _currentTranscript;
  String get lastAiResponse => _lastAiResponse;
  List<DialogueTurn> get conversationHistory => List.unmodifiable(_conversationHistory);

  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  void _notify() {
    for (final l in _listeners) {
      l();
    }
  }

  /// Khởi tạo speech-to-text và TTS
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      _isInitialized = true;
      _notify();
      return true;
    }
    try {
      await TtsService.init();
      _isInitialized = await _speech.initialize(
        onError: (val) {
          debugPrint('STT Error: $val');
          _isListening = false;
          _notify();
        },
        onStatus: (status) {
          debugPrint('STT Status: $status');
          if (status == 'notListening' || status == 'done') {
            _isListening = false;
            _notify();
          }
        },
      ).timeout(const Duration(milliseconds: 1000), onTimeout: () => false);
    } catch (e) {
      debugPrint('VoiceDialogueService init exception: $e');
      _isInitialized = false;
    }
    _notify();
    return _isInitialized;
  }

  /// Dừng phát giọng nói AI lập tức (Interrupt AI)
  Future<void> stopAiSpeaking() async {
    TtsService.onCompletion = null;
    _resumeTimer?.cancel();
    _speechDebounceTimer?.cancel();
    _echoGuardUntil = null;
    _isAiSpeaking = false;
    await TtsService.stop();
    _notify();
  }

  /// Bắt đầu lắng nghe rảnh tay từ microphone (Barge-in: ngắt AI nếu AI đang nói)
  Future<void> startListening({String? contextHint}) async {
    // 1. TÍNH NĂNG NGẮT GIỌNG AI (BARGE-IN / INTERRUPT):
    // Nếu AI đang nói mà người dùng bắt đầu nói hoặc bấm nói -> Ngắt giọng AI ngay lập tức!
    if (_isAiSpeaking || TtsService.isSpeaking) {
      await stopAiSpeaking();
    }

    if (!_isInitialized) {
      await initialize();
    }

    _speechDebounceTimer?.cancel();
    _isListening = true;
    _currentTranscript = '';
    _notify();

    try {
      if (_speech.isAvailable) {
        await _speech.listen(
          onResult: (val) {
            // NẾU AI ĐANG NÓI HOẶC TTS ĐANG PHÁT HOẶC CHƯA HẾT THỜI GIAN BẢO VỆ CHỐNG VỌNG ÂM:
            // LẬP TỨC LOẠI BỎ, TUYỆT ĐỐI KHÔNG THU TIẾNG CỦA APP!
            if (_isAiSpeaking || TtsService.isSpeaking) {
              return;
            }
            if (_echoGuardUntil != null && DateTime.now().isBefore(_echoGuardUntil!)) {
              return;
            }

            _currentTranscript = val.recognizedWords;
            _notify();

            // Hủy bỏ bộ đếm im lặng cũ nếu người dùng đang tiếp tục nói
            _speechDebounceTimer?.cancel();

            // KHI NGƯỜI DÙNG DỨT LỜI (VAD - Voice Activity Detection):
            // Thay vì ngắt lời sớm, ta đệm 1.8 giây sau khi người dùng ngừng nói
            // để người dùng thở hoặc suy nghĩ nói trọn vẹn câu mà không bao giờ bị AI cướp lời.
            if (_currentTranscript.trim().isNotEmpty) {
              _speechDebounceTimer = Timer(const Duration(milliseconds: 1800), () {
                if (_isListening && _currentTranscript.trim().isNotEmpty && !_isAiSpeaking) {
                  processUserSpeech(_currentTranscript, contextHint: contextHint);
                }
              });
            }
          },
          listenMode: stt.ListenMode.dictation,
          localeId: 'vi_VN',
          listenFor: const Duration(seconds: 60),
          pauseFor: const Duration(seconds: 5), // 5 giây im lặng mới ngắt kết nối STT
          cancelOnError: false,
          partialResults: true,
        ).timeout(const Duration(milliseconds: 1000), onTimeout: () => false);
      }
    } catch (e) {
      debugPrint('Error starting STT listen: $e');
    }
  }

  /// Dừng lắng nghe
  Future<void> stopListening() async {
    _resumeTimer?.cancel();
    _speechDebounceTimer?.cancel();
    try {
      await _speech.stop();
    } catch (_) {}
    _isListening = false;
    _notify();
  }

  /// Xử lý câu nói của người dùng, suy luận câu trả lời và phát âm phản hồi (TTS)
  Future<String> processUserSpeech(String speechText, {String? contextHint}) async {
    final query = speechText.trim();
    if (query.isEmpty) return '';

    // BƯỚC 1: DỪNG MIC NGAY LẬP TỨC ĐỂ KHÔNG THU THÊM BẤT KỲ ÂM THANH NÀO
    _speechDebounceTimer?.cancel();
    _resumeTimer?.cancel();
    _isListening = false;
    try {
      await _speech.stop();
      // Chờ nhẹ 100ms để driver microphone giải phóng hoàn toàn, tránh tiếng loa ngoài lọt vào mic
      await Future.delayed(const Duration(milliseconds: 100));
    } catch (_) {}
    _notify();

    // BƯỚC 2: Lưu lượt thoại người dùng
    _conversationHistory.add(DialogueTurn(
      isUser: true,
      text: query,
      timestamp: DateTime.now(),
    ));
    _notify();

    // TẦNG 0: BỘ ĐỊNH TUYẾN AN TOÀN SINH TỬ TỨC THÌ (<10ms)
    // Quét cờ đỏ: Ngừng thở, bất tỉnh, máu phun xối xả, co giật, sốc phản vệ...
    final safetyCheck = MedicalSafetyRouter.evaluate(query);
    String answer;
    if (safetyCheck.isTriggered) {
      answer = '${safetyCheck.initialVoiceResponse}\n\n[HÀNH ĐỘNG KHẨN CẤP]: ${safetyCheck.criticalAction}';
    } else {
      // Xử lý phản hồi y tế chuẩn xác On-Device tức thì (<1ms) từ MedicalDialogueBrain
      answer = resolveMedicalQuery(query, contextHint: contextHint);
    }

    _lastAiResponse = answer;

    // Lưu lượt thoại AI
    _conversationHistory.add(DialogueTurn(
      isUser: false,
      text: answer,
      timestamp: DateTime.now(),
    ));

    // BƯỚC 3: PHÁT ÂM THANH QUA LOA VỚI BẢO VỆ CHỐNG VỌNG ÂM TUYỆT ĐỐI (NON-BLOCKING)
    _isAiSpeaking = true;
    _notify();

    // Callback xử lý khi TTS đọc xong (hoàn tất phát âm)
    void onTtsFinished() {
      if (!_isAiSpeaking && !TtsService.isSpeaking) return;
      _resumeTimer?.cancel();
      _isAiSpeaking = false;
      // Echo guard 1200ms sau khi tắt loa để âm vang trong phòng tan hết
      _echoGuardUntil = DateTime.now().add(const Duration(milliseconds: 1200));
      _notify();

      // BƯỚC 4: XỬ LÝ 2 CHẾ ĐỘ:
      // Chế độ 1: Bấm để ghi âm (_continuousLiveMode == false) -> MIC TẮT HẲN, KHÔNG BẬT LẠI!
      // Chế độ 2: Tự động rảnh tay (_continuousLiveMode == true) -> Đợi hết âm vang (1200ms) rồi mới mở mic!
      if (_continuousLiveMode && !_isListening && !Platform.environment.containsKey('FLUTTER_TEST')) {
        Timer(const Duration(milliseconds: 1200), () {
          if (_continuousLiveMode && !_isListening && !_isAiSpeaking && !TtsService.isSpeaking) {
            startListening(contextHint: contextHint);
          }
        });
      }
    }

    // Đăng ký sự kiện TTS hoàn thành thực tế từ FlutterTts native
    TtsService.onCompletion = onTtsFinished;

    // Kích hoạt phát âm bất đồng bộ (Non-blocking, không bao giờ deadlock Main Thread)
    TtsService.speak(answer);

    // Watchdog fallback: Nếu native TTS không phát sinh callback onCompletion, tính thời gian dự phòng
    final wordCount = answer.split(RegExp(r'\s+')).length;
    final int watchdogSeconds = (wordCount / 2.0).ceil().clamp(3, 35);
    _echoGuardUntil = DateTime.now().add(Duration(seconds: watchdogSeconds + 2));

    _resumeTimer?.cancel();
    _resumeTimer = Timer(Duration(seconds: watchdogSeconds), () {
      onTtsFinished();
    });

    return answer;
  }

  /// Giả lập hoặc kích hoạt câu hỏi bằng giọng nói (áp dụng cho nút bấm mẫu hoặc test không mic)
  Future<String> simulateSpokenInput(String voicePrompt, {String? contextHint}) async {
    _currentTranscript = voicePrompt;
    _notify();
    return await processUserSpeech(voicePrompt, contextHint: contextHint);
  }

  /// Động cơ suy luận y khoa phản hồi giọng nói đa tình huống thích ứng thông minh (Medical Dialogue Brain)
  String resolveMedicalQuery(String query, {String? contextHint}) {
    return MedicalDialogueBrain().processQuery(query, contextHint: contextHint);
  }

  void clearHistory() {
    _resumeTimer?.cancel();
    _speechDebounceTimer?.cancel();
    _isListening = false;
    _isAiSpeaking = false;
    _echoGuardUntil = null;
    MedicalDialogueBrain().reset();
    _conversationHistory.clear();
    _currentTranscript = '';
    _lastAiResponse = '';
    _notify();
  }

  /// Làm mới lịch sử và nạp ngay thông điệp hướng dẫn ban đầu chuẩn xác của ca chấn thương
  void resetWithInitialAiMessage(String initialMessage) {
    _resumeTimer?.cancel();
    _speechDebounceTimer?.cancel();
    MedicalDialogueBrain().reset();
    _conversationHistory.clear();
    _conversationHistory.add(DialogueTurn(
      isUser: false,
      text: initialMessage,
      timestamp: DateTime.now(),
    ));
    _currentTranscript = '';
    _lastAiResponse = initialMessage;
    _notify();
  }
}
