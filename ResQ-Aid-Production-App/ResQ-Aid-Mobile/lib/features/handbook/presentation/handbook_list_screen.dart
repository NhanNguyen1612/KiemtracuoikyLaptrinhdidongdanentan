import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/theme/app_theme.dart';
import 'protocol_detail_screen.dart';

class HandbookListScreen extends ConsumerStatefulWidget {
  const HandbookListScreen({super.key});

  @override
  ConsumerState<HandbookListScreen> createState() => _HandbookListScreenState();
}

class _HandbookListScreenState extends ConsumerState<HandbookListScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'ALL';
  int _loadTimeMs = 0;

  IconData _getIconForProtocol(String code) {
    switch (code) {
      case 'PROTO_CARDIAC_ARREST':
        return Icons.favorite_rounded;
      case 'PROTO_AED':
        return Icons.bolt_rounded;
      case 'PROTO_CHOKING':
        return Icons.record_voice_over_rounded;
      case 'PROTO_DROWNING':
        return Icons.waves_rounded;
      case 'PROTO_BURNS':
        return Icons.local_fire_department_rounded;
      case 'PROTO_ELECTROCUTION':
        return Icons.offline_bolt_rounded;
      case 'PROTO_ANAPHYLAXIS':
        return Icons.healing_rounded;
      case 'PROTO_STROKE':
        return Icons.psychology_rounded;
      case 'PROTO_SEIZURE':
        return Icons.airline_seat_flat_rounded;
      case 'PROTO_TRAUMA':
        return Icons.medical_services_rounded;
      case 'PROTO_CUT_BLEEDING':
        return Icons.content_cut_rounded;
      case 'PROTO_MENTAL_CRISIS':
        return Icons.spa_rounded;
      case 'PROTO_HEART_ATTACK':
        return Icons.monitor_heart_rounded;
      case 'PROTO_POISONING':
        return Icons.warning_amber_rounded;
      case 'PROTO_SNAKE_BITE':
        return Icons.pest_control_rounded;
      case 'PROTO_HEAT_STROKE':
        return Icons.wb_sunny_rounded;
      case 'PROTO_ASTHMA':
        return Icons.air_rounded;
      case 'PROTO_HYPOGLYCEMIA':
        return Icons.water_drop_rounded;
      case 'PROTO_HEAD_INJURY':
        return Icons.personal_injury_rounded;
      case 'PROTO_NOSEBLEED':
        return Icons.bloodtype_rounded;
      default:
        return Icons.health_and_safety_rounded;
    }
  }

  Color _getColorForProtocol(String code) {
    switch (code) {
      case 'PROTO_CARDIAC_ARREST':
        return const Color(0xFFDC2626);
      case 'PROTO_AED':
        return const Color(0xFFD97706);
      case 'PROTO_CHOKING':
        return const Color(0xFFD97706);
      case 'PROTO_DROWNING':
        return const Color(0xFF0284C7);
      case 'PROTO_BURNS':
        return const Color(0xFFEA580C);
      case 'PROTO_ELECTROCUTION':
        return const Color(0xFFB45309);
      case 'PROTO_ANAPHYLAXIS':
        return const Color(0xFFE11D48);
      case 'PROTO_STROKE':
        return const Color(0xFF7C3AED);
      case 'PROTO_SEIZURE':
        return const Color(0xFF4F46E5);
      case 'PROTO_TRAUMA':
        return const Color(0xFF059669);
      case 'PROTO_CUT_BLEEDING':
        return const Color(0xFFE11D48);
      case 'PROTO_MENTAL_CRISIS':
        return const Color(0xFF8B5CF6);
      case 'PROTO_HEART_ATTACK':
        return const Color(0xFFDC2626);
      case 'PROTO_POISONING':
        return const Color(0xFFD97706);
      case 'PROTO_SNAKE_BITE':
        return const Color(0xFF16A34A);
      case 'PROTO_HEAT_STROKE':
        return const Color(0xFFEA580C);
      case 'PROTO_ASTHMA':
        return const Color(0xFF0284C7);
      case 'PROTO_HYPOGLYCEMIA':
        return const Color(0xFFCA8A04);
      case 'PROTO_HEAD_INJURY':
        return const Color(0xFFBE123C);
      case 'PROTO_NOSEBLEED':
        return const Color(0xFFE11D48);
      default:
        return AppTheme.medicalBlue;
    }
  }

  String _getPriorityBadge(String code) {
    switch (code) {
      case 'PROTO_CARDIAC_ARREST':
      case 'PROTO_AED':
      case 'PROTO_CHOKING':
      case 'PROTO_ANAPHYLAXIS':
      case 'PROTO_HEART_ATTACK':
      case 'PROTO_HEAD_INJURY':
        return 'P0 • TỐI KHẨN';
      case 'PROTO_DROWNING':
      case 'PROTO_ELECTROCUTION':
      case 'PROTO_STROKE':
      case 'PROTO_SEIZURE':
      case 'PROTO_POISONING':
      case 'PROTO_SNAKE_BITE':
      case 'PROTO_HEAT_STROKE':
      case 'PROTO_ASTHMA':
        return 'P1 • NGUY KỊCH';
      case 'PROTO_BURNS':
      case 'PROTO_FRACTURE':
      case 'PROTO_TRAUMA':
      case 'PROTO_CUT_BLEEDING':
      case 'PROTO_MENTAL_CRISIS':
      case 'PROTO_HYPOGLYCEMIA':
      case 'PROTO_NOSEBLEED':
      default:
        return 'P2 • KHẨN CẤP';
    }
  }

  Color _getPriorityColor(String code) {
    switch (code) {
      case 'PROTO_CARDIAC_ARREST':
      case 'PROTO_AED':
      case 'PROTO_CHOKING':
      case 'PROTO_ANAPHYLAXIS':
      case 'PROTO_HEART_ATTACK':
      case 'PROTO_HEAD_INJURY':
        return const Color(0xFFDC2626);
      case 'PROTO_DROWNING':
      case 'PROTO_ELECTROCUTION':
      case 'PROTO_STROKE':
      case 'PROTO_SEIZURE':
      case 'PROTO_POISONING':
      case 'PROTO_SNAKE_BITE':
      case 'PROTO_HEAT_STROKE':
      case 'PROTO_ASTHMA':
        return const Color(0xFFD97706);
      case 'PROTO_BURNS':
      case 'PROTO_FRACTURE':
      case 'PROTO_TRAUMA':
      case 'PROTO_CUT_BLEEDING':
      case 'PROTO_MENTAL_CRISIS':
      case 'PROTO_HYPOGLYCEMIA':
      case 'PROTO_NOSEBLEED':
      default:
        return const Color(0xFF0284C7);
    }
  }

  bool _matchesCategory(String code) {
    if (_selectedCategory == 'ALL') return true;
    if (_selectedCategory == 'CARDIO_AIRWAY') {
      return code == 'PROTO_CARDIAC_ARREST' ||
          code == 'PROTO_AED' ||
          code == 'PROTO_CHOKING' ||
          code == 'PROTO_DROWNING' ||
          code == 'PROTO_HEART_ATTACK' ||
          code == 'PROTO_ASTHMA';
    }
    if (_selectedCategory == 'ACCIDENT') {
      return code == 'PROTO_ELECTROCUTION' ||
          code == 'PROTO_TRAUMA' ||
          code == 'PROTO_FRACTURE' ||
          code == 'PROTO_CUT_BLEEDING' ||
          code == 'PROTO_HEAD_INJURY' ||
          code == 'PROTO_SNAKE_BITE' ||
          code == 'PROTO_BURNS' ||
          code == 'PROTO_NOSEBLEED';
    }
    if (_selectedCategory == 'BURNS_ALLERGY') {
      return code == 'PROTO_BURNS' ||
          code == 'PROTO_ANAPHYLAXIS' ||
          code == 'PROTO_STROKE' ||
          code == 'PROTO_SEIZURE' ||
          code == 'PROTO_MENTAL_CRISIS' ||
          code == 'PROTO_POISONING' ||
          code == 'PROTO_HEAT_STROKE' ||
          code == 'PROTO_HYPOGLYCEMIA';
    }
    return true;
  }

  String _removeDiacritics(String str) {
    const withDia = 'áàảãạăắằẳẵặâấầẩẫậéèẻẽẹêếềểễệíìỉĩịóòỏõọôốồổỗộơớờởỡợúùủũụưứừửữựýỳỷỹỵđ';
    const withoutDia = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';
    var result = str.toLowerCase();
    for (var i = 0; i < withDia.length; i++) {
      result = result.replaceAll(withDia[i], withoutDia[i]);
    }
    return result;
  }

  Future<List<ProtocolEntry>> _fetchProtocolsWithTiming(AppDatabase db) async {
    final sw = Stopwatch()..start();
    final items = await db.getAllProtocols();
    sw.stop();
    _loadTimeMs = sw.elapsedMilliseconds;
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('CẨM NANG SƠ CỨU NGOẠI TUYẾN'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0.5,
      ),
      body: Column(
        children: [
          // Search & Filter Header Container
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              children: [
                TextField(
                  onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Tìm kiếm phác đồ (CPR, AED, co giật, bỏng, đuối nước...)...',
                    hintStyle: const TextStyle(fontFamily: 'Roboto', fontSize: 13, color: Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 20),
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('Tất cả', 'ALL'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Tim mạch & Hô hấp', 'CARDIO_AIRWAY'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Tai nạn & Chấn thương', 'ACCIDENT'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Đột quỵ, Co giật, Bỏng', 'BURNS_ALLERGY'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Offline Performance Benchmark Indicator
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: const Color(0xFFEFF6FF),
            child: Row(
              children: [
                const Icon(Icons.offline_bolt_rounded, color: Color(0xFF0284C7), size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Sẵn sàng ngoại tuyến • Chuẩn AHA & Bộ Y tế',
                    style: const TextStyle(fontFamily: 'Roboto', color: Color(0xFF0369A1), fontSize: 11, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'ĐÃ DUYỆT',
                    style: TextStyle(fontFamily: 'Roboto', color: Color(0xFF15803D), fontSize: 9.5, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),

          // List of Protocols
          Expanded(
            child: FutureBuilder<List<ProtocolEntry>>(
              future: _fetchProtocolsWithTiming(db),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final protocols = (snapshot.data ?? []).where((p) {
                  final cleanQuery = _searchQuery.trim().toLowerCase();
                  final cleanQueryNoDia = _removeDiacritics(cleanQuery);

                  final titleNoDia = _removeDiacritics(p.title);
                  final contentNoDia = _removeDiacritics(p.contentJson);

                  final matchesSearch = cleanQuery.isEmpty ||
                      p.title.toLowerCase().contains(cleanQuery) ||
                      titleNoDia.contains(cleanQueryNoDia) ||
                      p.protocolCode.toLowerCase().contains(cleanQuery) ||
                      p.contentJson.toLowerCase().contains(cleanQuery) ||
                      contentNoDia.contains(cleanQueryNoDia);

                  // When user types in search query, search globally across all protocols regardless of category chip
                  final matchesCat = cleanQuery.isNotEmpty || _matchesCategory(p.protocolCode);
                  return matchesSearch && matchesCat;
                }).toList();

                if (protocols.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off_rounded, size: 56, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          const Text(
                            'Không tìm thấy phác đồ phù hợp',
                            style: TextStyle(fontFamily: 'Roboto', fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: protocols.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = protocols[index];
                    final color = _getColorForProtocol(item.protocolCode);
                    final icon = _getIconForProtocol(item.protocolCode);
                    final priorityBadge = _getPriorityBadge(item.protocolCode);
                    final priorityColor = _getPriorityColor(item.protocolCode);

                    Map<String, dynamic> parsed = {};
                    try {
                      parsed = jsonDecode(item.contentJson) as Map<String, dynamic>;
                    } catch (_) {}

                    final summary = parsed['quick_summary'] ?? 'Hướng dẫn sơ cứu khẩn cấp từng bước.';

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(6),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ProtocolDetailScreen(protocol: item),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(14.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: color.withAlpha(20),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: color.withAlpha(50)),
                                  ),
                                  child: Icon(icon, color: color, size: 22),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: priorityColor.withAlpha(20),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              priorityBadge,
                                              style: TextStyle(
                                                fontFamily: 'Roboto',
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.w800,
                                                color: priorityColor,
                                              ),
                                            ),
                                          ),
                                          const Spacer(),
                                          const Text(
                                            'v2.0 • Đã duyệt',
                                            style: TextStyle(fontFamily: 'Roboto', fontSize: 10, color: Color(0xFF16A34A), fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        item.title,
                                        style: const TextStyle(
                                          fontFamily: 'Roboto',
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        summary,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontFamily: 'Roboto', fontSize: 11.5, color: Color(0xFF64748B), height: 1.3),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFFCBD5E1), size: 14),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String code) {
    final isSelected = _selectedCategory == code;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = code),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }
}
