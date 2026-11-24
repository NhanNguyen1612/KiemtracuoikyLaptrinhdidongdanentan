import 'package:shared_preferences/shared_preferences.dart';

class DemoModeService {
  static const String _keyIsDemo = 'resq_aid_is_demo_mode';
  static const String _keyDemoPhone = 'resq_aid_demo_phone_number';

  // Số mặc định trong Chế độ Demo (Tránh gọi thật vào tổng đài 115 khi chấm thi)
  static const String defaultDemoPhone = '0384589660';
  static const String realEmergencyPhone = '115';

  static Future<bool> isDemoMode() async {
    final prefs = await SharedPreferences.getInstance();
    // Mặc định luôn là TRUE để bảo vệ sinh viên và giảng viên khỏi bị phạt cước gọi 115 thật
    return prefs.getBool(_keyIsDemo) ?? true;
  }

  static Future<void> setDemoMode(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsDemo, enabled);
  }

  static Future<String> getEmergencyPhone() async {
    final isDemo = await isDemoMode();
    if (!isDemo) return realEmergencyPhone;

    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyDemoPhone) ?? defaultDemoPhone;
  }

  static Future<void> setDemoPhone(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDemoPhone, phone);
  }
}
