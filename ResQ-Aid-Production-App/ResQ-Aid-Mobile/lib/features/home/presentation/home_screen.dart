import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/services/demo_mode_service.dart';
import '../../../core/services/location_service.dart';
import '../../sos/presentation/emergency_sos_screen.dart';
import '../../handbook/presentation/handbook_list_screen.dart';
import '../../handbook/presentation/protocol_detail_screen.dart';
import '../../../core/database/app_database.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../dispatcher/presentation/dispatcher_console_screen.dart';
import '../../wound_scanner/presentation/wound_scanner_screen.dart';
import '../../voice_assistant/presentation/voice_live_screen.dart';
import '../../vitals/presentation/heart_rate_monitor_screen.dart';
import '../../medical_facilities/domain/medical_facility_model.dart';
import '../../medical_facilities/presentation/nearest_medical_facility_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentTabIndex = 0;
  String _emergencyPhone = DemoModeService.defaultDemoPhone;
  bool _isDemo = true;

  @override
  void initState() {
    super.initState();
    _loadDemoConfig();
  }

  Future<void> _loadDemoConfig() async {
    final phone = await DemoModeService.getEmergencyPhone();
    final isDemo = await DemoModeService.isDemoMode();
    if (mounted) {
      setState(() {
        _emergencyPhone = phone;
        _isDemo = isDemo;
      });
    }
  }

  Future<void> _makeEmergencyCall() async {
    final phone = await DemoModeService.getEmergencyPhone();
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openProtocolDetail(String code) async {
    final db = ref.read(databaseProvider);
    final proto = await db.getProtocolByCode(code);
    if (proto != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProtocolDetailScreen(protocol: proto),
        ),
      );
    } else if (mounted) {
      setState(() => _currentTabIndex = 2);
    }
  }

  Future<void> _sendBackupSms() async {
    final phone = await DemoModeService.getEmergencyPhone();
    final loc = await LocationService.getCurrentLocation();
    final lat = loc.lat.toStringAsFixed(6);
    final lng = loc.lng.toStringAsFixed(6);
    // Chuẩn URI tin nhắn SMS khác nhau giữa iOS ('&body=') và Android ('?body=')
    final sep = (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) ? '&' : '?';
    final smsUri = Uri.parse(
      'sms:$phone${sep}body=${Uri.encodeComponent('SOS! Cần cấp cứu khẩn cấp tại: https://maps.google.com/?q=$lat,$lng')}',
    );
    if (await canLaunchUrl(smsUri)) {
      await launchUrl(smsUri);
    }
  }

  void _showNearbyMedicalSheet(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: const Color(0xFF0F172A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withOpacity(0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF38BDF8)),
                      ),
                      child: const Icon(Icons.near_me_rounded, color: Color(0xFF38BDF8), size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TÌM CƠ SỞ Y TẾ GẦN NHẤT',
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                            ),
                          ),
                          Text(
                            'Hoạt động 100% Offline • Định vị La bàn & GPS',
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              color: Color(0xFF10B981),
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white54),
                      onPressed: () => Navigator.pop(sheetCtx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildMedicalOptionTile(
                  sheetCtx: sheetCtx,
                  icon: Icons.local_hospital_rounded,
                  iconColor: const Color(0xFFEF4444),
                  title: 'Bệnh viện & Cấp cứu 24/7',
                  subtitle: 'Bệnh viện đa khoa, phòng khám cấp cứu lớn gần nhất',
                  filter: FacilityType.hospital,
                  query: 'bệnh viện cấp cứu gần nhất',
                ),
                const SizedBox(height: 10),
                _buildMedicalOptionTile(
                  sheetCtx: sheetCtx,
                  icon: Icons.health_and_safety_rounded,
                  iconColor: const Color(0xFF10B981),
                  title: 'Trạm y tế & Trạm xá phường xã',
                  subtitle: 'Cơ sở sơ cấp cứu ban đầu, trung tâm y tế dự phòng',
                  filter: FacilityType.clinic,
                  query: 'trạm y tế gần nhất',
                ),
                const SizedBox(height: 10),
                _buildMedicalOptionTile(
                  sheetCtx: sheetCtx,
                  icon: Icons.medication_rounded,
                  iconColor: const Color(0xFFF59E0B),
                  title: 'Nhà thuốc & Hiệu thuốc tây',
                  subtitle: 'Mua bông băng, gạc tiệt trùng, nước sát khuẩn, nẹp',
                  filter: FacilityType.pharmacy,
                  query: 'nhà thuốc gần nhất',
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () {
                      Navigator.pop(sheetCtx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const NearestMedicalFacilityScreen()),
                      );
                    },
                    icon: const Icon(Icons.explore_rounded, size: 20),
                    label: const Text(
                      'TRA CỨU & DẪN ĐƯỜNG OFFLINE (KHÔNG CẦN 4G)',
                      style: TextStyle(fontFamily: 'Roboto', fontSize: 13, fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF38BDF8),
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () {
                      Navigator.pop(sheetCtx);
                      LocationService.openNearestMedicalMap(query: 'trạm y tế bệnh viện gần nhất');
                    },
                    icon: const Icon(Icons.map_rounded, size: 18),
                    label: const Text(
                      'Mở Google Maps (Nếu có Internet)',
                      style: TextStyle(fontFamily: 'Roboto', fontSize: 12.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMedicalOptionTile({
    required BuildContext sheetCtx,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required FacilityType? filter,
    required String query,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            Navigator.pop(sheetCtx);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => NearestMedicalFacilityScreen(initialFilter: filter),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontFamily: 'Roboto',
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontFamily: 'Roboto',
                          color: Color(0xFF94A3B8),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white38, size: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    final isDemo = _isDemo;
    final emergencyPhone = _emergencyPhone;

    Widget bodyContent;
    switch (_currentTabIndex) {
      case 1:
        bodyContent = const EmergencySosScreen();
        break;
      case 2:
        bodyContent = const HandbookListScreen();
        break;
      case 3:
        bodyContent = const SettingsScreen();
        break;
      default:
        bodyContent = _buildHomeContent(context, db, isDemo, emergencyPhone);
        break;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _currentTabIndex == 0
          ? AppBar(
              backgroundColor: Colors.white,
              elevation: 0.5,
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.emergency, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ResQ-Aid v2.0',
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            color: Color(0xFF0F172A),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Cấp cứu Tiền viện Đa nền tảng',
                          style: TextStyle(fontFamily: 'Roboto', fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0284C7), Color(0xFF6366F1)],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF38BDF8).withOpacity(0.4),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 16),
                  ),
                  tooltip: 'Trợ lý Hướng dẫn Sơ cứu (Live Voice)',
                  onPressed: () {
                    Navigator.push(
                      context,
                      PageRouteBuilder(
                        opaque: false,
                        pageBuilder: (_, __, ___) => const VoiceLiveScreen(),
                        transitionsBuilder: (_, animation, __, child) => FadeTransition(opacity: animation, child: child),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.dashboard_customize_outlined, color: Color(0xFF1E40AF)),
                  tooltip: 'Tổng đài Điều phối 115 (Web Console)',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const DispatcherConsoleScreen()),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.settings_outlined, color: Color(0xFF475569)),
                  tooltip: 'Cài đặt & Dữ liệu',
                  onPressed: () {
                    setState(() => _currentTabIndex = 3);
                  },
                ),
              ],
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTabIndex,
        onDestinationSelected: (idx) => setState(() => _currentTabIndex = idx),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Trang chủ'),
          NavigationDestination(icon: Icon(Icons.sos_outlined), selectedIcon: Icon(Icons.sos, color: Colors.red), label: 'Kích hoạt'),
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'Cẩm nang'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Cài đặt'),
        ],
      ),
      body: bodyContent,
    );
  }

  Widget _buildHomeContent(BuildContext context, AppDatabase db, bool isDemo, String emergencyPhone) {
    return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // NÚT 1: GỌI KHẨN CẤP 115 / DEMO PHONE
            Container(
              height: 72,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [Color(0xFFDC2626), Color(0xFFB91C1C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFDC2626).withAlpha(80),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _makeEmergencyCall,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(40),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.phone_in_talk_rounded, color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 14),
                        Flexible(
                          child: Text(
                            isDemo ? 'GỌI CẤP CỨU $emergencyPhone' : 'GỌI KHẨN CẤP 115',
                            style: const TextStyle(
                              fontFamily: 'Roboto',
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // NÚT 2: TÔI CẦN HƯỚNG DẪN / BẮT ĐẦU SƠ CỨU (GỬI P0 GPS VÀO STEPPER)
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: const Color(0xFF0F172A),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const EmergencySosScreen()),
                    );
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Icon(Icons.health_and_safety_rounded, color: Color(0xFF38BDF8), size: 30),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'TÔI CẦN HƯỚNG DẪN SƠ CỨU',
                                style: TextStyle(
                                  fontFamily: 'Roboto',
                                  color: Colors.white,
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Gửi tọa độ lên Dashboard & mở Stepper 3 bước',
                                style: TextStyle(fontFamily: 'Roboto', color: Color(0xFF94A3B8), fontSize: 11.5),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios_rounded, color: Colors.white54, size: 15),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Hàng công cụ khẩn cấp: Dự phòng SMS 115 & Tìm Trạm Y tế / Bệnh viện Google Maps
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _sendBackupSms,
                    icon: const Icon(Icons.sms_failed_rounded, size: 17, color: Color(0xFF475569)),
                    label: const Text(
                      'SMS 115 KÈM GPS',
                      style: TextStyle(fontFamily: 'Roboto', fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _showNearbyMedicalSheet(context),
                    icon: const Icon(Icons.near_me_rounded, size: 17, color: Colors.white),
                    label: const Text(
                      'TÌM TRẠM Y TẾ / VIỆN',
                      style: TextStyle(fontFamily: 'Roboto', fontSize: 11.5, fontWeight: FontWeight.w800, color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // CARD: BÁC SĨ AI TRỰC TUYẾN (GEMINI LIVE MODE)
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E1B4B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: const Color(0xFF818CF8), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withOpacity(0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    Navigator.push(
                      context,
                      PageRouteBuilder(
                        opaque: false,
                        pageBuilder: (_, __, ___) => const VoiceLiveScreen(),
                        transitionsBuilder: (_, animation, __, child) =>
                            FadeTransition(opacity: animation, child: child),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0284C7), Color(0xFF6366F1)],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF38BDF8).withOpacity(0.4),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'TRỢ LÝ HƯỚNG DẪN SƠ CỨU',
                                      style: TextStyle(
                                        fontFamily: 'Roboto',
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 13.5,
                                        letterSpacing: 0.3,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF6366F1).withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFF818CF8)),
                                    ),
                                    child: const Text(
                                      'OFFLINE',
                                      style: TextStyle(
                                        color: Color(0xFFA5B4FC),
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              const Text(
                                'Hướng dẫn sơ cứu rảnh tay 100% Offline • Hỗ trợ nút gọi 115',
                                style: TextStyle(
                                  fontFamily: 'Roboto',
                                  color: Color(0xFFCBD5E1),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF818CF8), size: 14),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // CARD: QUÉT VẾT THƯƠNG AI & PHÂN LOẠI CẤP CỨU (BỎNG, CHẢY MÁU, GÃY XƯƠNG)
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: const Color(0xFF0F172A),
                border: Border.all(color: const Color(0xFF38BDF8), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0284C7).withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const WoundScannerScreen()),
                    );
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0284C7).withOpacity(0.2),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF38BDF8)),
                          ),
                          child: const Icon(Icons.document_scanner_rounded, color: Color(0xFF38BDF8), size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      'Quét Vết Thương AI',
                                      style: TextStyle(
                                        fontFamily: 'Roboto',
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'TRIAGE VISION',
                                    style: TextStyle(
                                      fontFamily: 'Roboto',
                                      color: Color(0xFF38BDF8),
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Phân tích bỏng độ 1-2-3, vết rách động mạch, gãy hở chi & hướng dẫn sơ cứu tức thì',
                                style: TextStyle(fontFamily: 'Roboto', color: Color(0xFF94A3B8), fontSize: 11.5),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 14),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // CARD: ĐO NHỊP TIM THỰC TẾ & BẮT MẠCH CAMERA (PPG OPTICAL SENSOR)
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: const Color(0xFF0F172A),
                border: Border.all(color: const Color(0xFFF43F5E), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF43F5E).withOpacity(0.18),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const HeartRateMonitorScreen()),
                    );
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF43F5E).withOpacity(0.18),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFFB7185)),
                          ),
                          child: const Icon(Icons.monitor_heart_rounded, color: Color(0xFFFB7185), size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Flexible(
                                    child: Text(
                                      'Theo Dõi Nhịp Mạch (Tham Khảo)',
                                      maxLines: 1,
                                      style: TextStyle(
                                        fontFamily: 'Roboto',
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0x400284C7),
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: const Text(
                                      'PPG / TAP',
                                      style: TextStyle(
                                        fontFamily: 'Roboto',
                                        color: Color(0xFF38BDF8),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              const Text(
                                'Dành cho người tỉnh táo, nghỉ ngơi. Nếu bất tỉnh không thở hãy ép tim CPR ngay!',
                                style: TextStyle(fontFamily: 'Roboto', color: Color(0xFF94A3B8), fontSize: 11),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 14),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // SECTION TITLE: XỬ LÝ NHANH HIỆN TRƯỜNG
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'XỬ LÝ NHANH HIỆN TRƯỜNG',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF475569),
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    'Offline 100%',
                    style: TextStyle(fontFamily: 'Roboto', fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 6),

            // 4 BENTO QUICK ACCESS CARDS
            Row(
              children: [
                Expanded(
                  child: _buildQuickActionCard(
                    title: 'Hóc dị vật',
                    subtitle: 'Heimlich 5 vỗ 5 ép',
                    icon: Icons.record_voice_over_rounded,
                    color: const Color(0xFFD97706),
                    bgColor: const Color(0xFFFFFBEB),
                    onTap: () => _openProtocolDetail('PROTO_CHOKING'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildQuickActionCard(
                    title: 'Đuối nước',
                    subtitle: '5 thổi ngạt đầu tiên',
                    icon: Icons.waves_rounded,
                    color: const Color(0xFF0284C7),
                    bgColor: const Color(0xFFF0F9FF),
                    onTap: () => _openProtocolDetail('PROTO_DROWNING'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildQuickActionCard(
                    title: 'Điện giật',
                    subtitle: 'Tách nguồn an toàn',
                    icon: Icons.bolt_rounded,
                    color: const Color(0xFFB45309),
                    bgColor: const Color(0xFFFEF3C7),
                    onTap: () => _openProtocolDetail('PROTO_ELECTROCUTION'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildQuickActionCard(
                    title: 'Bỏng & Vết thương',
                    subtitle: 'Quét AI & Xả nước',
                    icon: Icons.local_fire_department_rounded,
                    color: const Color(0xFFE11D48),
                    bgColor: const Color(0xFFFFF1F2),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const WoundScannerScreen()),
                      );
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Legal Mandatory Disclaimer Banner
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'LƯU Ý PHÁP LÝ: ResQ-Aid là công cụ hỗ trợ sơ cứu, không thay thế cho dịch vụ cấp cứu y tế chuyên nghiệp 115.',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Roboto', fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
  }

  Widget _buildQuickActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontFamily: 'Roboto',
                          color: Color(0xFF0F172A),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          color: color.withAlpha(220),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
