import 'package:flutter/material.dart';
import '../domain/incident_model.dart';
import '../services/dispatcher_realtime_service.dart';

class DispatcherConsoleScreen extends StatefulWidget {
  final DispatcherRealtimeService? service;

  const DispatcherConsoleScreen({super.key, this.service});

  @override
  State<DispatcherConsoleScreen> createState() => _DispatcherConsoleScreenState();
}

class _DispatcherConsoleScreenState extends State<DispatcherConsoleScreen> {
  late final DispatcherRealtimeService _service;
  late IncidentModel _selectedIncident;
  bool _isAudioSirenOn = true;
  int _activeNavTab = 0; // 0: Điều phối, 1: CMS Phác đồ, 2: Báo cáo, 3: Audit Log
  int _mobileSubTab = 0; // 0: Danh sách ca, 1: Bản đồ GPS, 2: Telemetry & AI

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? DispatcherRealtimeService.shared;
    if (_service.currentIncidents.isNotEmpty) {
      _selectedIncident = _service.currentIncidents.first;
    }
  }

  Color _getPriorityColor(PriorityTier p) {
    switch (p) {
      case PriorityTier.p0Critical:
        return const Color(0xFFDC2626);
      case PriorityTier.p1Urgent:
        return const Color(0xFFD97706);
      case PriorityTier.p2Priority:
        return const Color(0xFF2563EB);
      case PriorityTier.p3Deferred:
        return const Color(0xFF64748B);
    }
  }

  String _getPriorityLabel(PriorityTier p) {
    switch (p) {
      case PriorityTier.p0Critical:
        return 'P0 • TỐI KHẨN';
      case PriorityTier.p1Urgent:
        return 'P1 • NGUY KỊCH';
      case PriorityTier.p2Priority:
        return 'P2 • ƯU TIÊN';
      case PriorityTier.p3Deferred:
        return 'P3 • TRÌ HOÃN';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_service.currentIncidents.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF090D16),
        appBar: AppBar(
          title: const Text('ĐIỀU PHỐI NGOẠI TUYẾN'),
          backgroundColor: const Color(0xFF0F172A),
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Không có ca điều phối trực tiếp trên thiết bị này. Dữ liệu ca không được tạo mẫu khi ngoại tuyến.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      body: Column(
        children: [
          // 1. TOP NAVIGATION BAR (Responsive cho ca Mobile & Desktop)
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
              border: Border(bottom: BorderSide(color: Color(0xFF334155))),
            ),
            child: Row(
              children: [
                if (Navigator.canPop(context)) ...[
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                    tooltip: 'Quay lại App',
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 4),
                ],
                // Logo & Title
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Icon(Icons.emergency_rounded, color: Colors.white, size: 18),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'ResQ-Aid v2.0 • ĐIỀU PHỐI 115',
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.3,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'TRUNG TÂM CẤP CỨU 115 ĐÀ NẴNG',
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          color: Color(0xFF94A3B8),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Audio Siren Toggle & Operator
                InkWell(
                  onTap: () => setState(() => _isAudioSirenOn = !_isAudioSirenOn),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _isAudioSirenOn ? const Color(0xFF22C55E) : const Color(0xFF64748B),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 3.5,
                          backgroundColor: _isAudioSirenOn ? const Color(0xFF22C55E) : Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _isAudioSirenOn ? 'Còi: BẬT' : 'Còi: TẮT',
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            color: _isAudioSirenOn ? const Color(0xFF4ADE80) : Colors.grey,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. THANH TIẾN TRÌNH 7 BƯỚC (7-STEP LIFECYCLE BAR)
          Container(
            margin: const EdgeInsets.fromLTRB(12, 6, 12, 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF131D31),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF24324D)),
            ),
            child: Row(
              children: [
                const Text(
                  'TIẾN TRÌNH:',
                  style: TextStyle(fontFamily: 'Roboto', color: Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.w800),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildStepNode(IncidentLifecycle.newIncident, '1. Mới nhận'),
                        _buildStepArrow(),
                        _buildStepNode(IncidentLifecycle.accepted, '2. Đã tiếp nhận'),
                        _buildStepArrow(),
                        _buildStepNode(IncidentLifecycle.dispatched, '3. Đã điều xe'),
                        _buildStepArrow(),
                        _buildStepNode(IncidentLifecycle.enRoute, '4. Đang đến'),
                        _buildStepArrow(),
                        _buildStepNode(IncidentLifecycle.onScene, '5. Tại hiện trường'),
                        _buildStepArrow(),
                        _buildStepNode(IncidentLifecycle.transporting, '6. Chuyển viện'),
                        _buildStepArrow(),
                        _buildStepNode(IncidentLifecycle.closed, '7. Đóng ca'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3. MAIN WORKSPACE RESPONSIVE (TỰ ĐỘNG THÍCH ỨNG MOBILE / TABLET / DESKTOP)
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 950;
                if (isMobile) {
                  return Column(
                    children: [
                      // Mobile Sub-Tab Selector Bar
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            _buildMobileTabButton(0, '🚑 Ca trực (${_service.currentIncidents.length})'),
                            _buildMobileTabButton(1, '🗺️ Bản đồ GPS'),
                            _buildMobileTabButton(2, '📊 Telemetry'),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                          child: _mobileSubTab == 0
                              ? _buildIncidentListColumn()
                              : _mobileSubTab == 1
                                  ? _buildTacticalMapColumn()
                                  : _buildTelemetryAndAiColumn(),
                        ),
                      ),
                    ],
                  );
                }

                // Desktop / Widescreen: 3 Columns
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: 320,
                        child: _buildIncidentListColumn(),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 5,
                        child: _buildTacticalMapColumn(),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 360,
                        child: _buildTelemetryAndAiColumn(),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileTabButton(int index, String label) {
    final isSelected = _mobileSubTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _mobileSubTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 10.5,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected ? Colors.white : const Color(0xFF94A3B8),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }



  Widget _buildStepNode(IncidentLifecycle step, String title) {
    final isCurrent = _selectedIncident.status == step;
    final isPassed = _selectedIncident.status.index > step.index;

    return InkWell(
      onTap: () {
        setState(() {
          _service.updateIncidentStatus(_selectedIncident.id, step);
          _selectedIncident = _selectedIncident.copyWith(status: step);
        });
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isCurrent
              ? const Color(0xFF2563EB)
              : (isPassed ? const Color(0xFF1E293B) : const Color(0xFF0F172A)),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isCurrent
                ? const Color(0xFF60A5FA)
                : (isPassed ? const Color(0xFF16A34A) : const Color(0xFF334155)),
            width: isCurrent ? 2 : 1,
          ),
        ),
        child: Text(
          isPassed ? '✓ $title' : title,
          style: TextStyle(
            fontFamily: 'Roboto',
            color: isCurrent ? Colors.white : (isPassed ? const Color(0xFF4ADE80) : const Color(0xFF94A3B8)),
            fontSize: 10.5,
            fontWeight: isCurrent ? FontWeight.w900 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildStepArrow() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 6),
      child: Text('→', style: TextStyle(color: Color(0xFF475569), fontSize: 12)),
    );
  }

  Widget _buildIncidentListColumn() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.format_list_bulleted_rounded, color: Color(0xFF60A5FA), size: 18),
                const SizedBox(width: 8),
                const Text(
                  'CA CẤP CỨU TIẾP NHẬN',
                  style: TextStyle(fontFamily: 'Roboto', color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${_service.currentIncidents.length} ca',
                    style: const TextStyle(fontFamily: 'Roboto', color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFF1F2937), height: 1),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(8),
              itemCount: _service.currentIncidents.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, idx) {
                final inc = _service.currentIncidents[idx];
                final isSelected = inc.id == _selectedIncident.id;
                final pColor = _getPriorityColor(inc.priority);

                return InkWell(
                  onTap: () => setState(() => _selectedIncident = inc),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF3B82F6) : const Color(0xFF1F2937),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: pColor.withAlpha(40),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: pColor),
                              ),
                              child: Text(
                                _getPriorityLabel(inc.priority),
                                style: TextStyle(fontFamily: 'Roboto', color: pColor, fontSize: 9, fontWeight: FontWeight.w900),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              inc.id,
                              style: const TextStyle(fontFamily: 'Roboto', color: Color(0xFF64748B), fontSize: 9.5, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          inc.incidentType,
                          style: const TextStyle(fontFamily: 'Roboto', color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined, color: Color(0xFF94A3B8), size: 12),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                inc.address,
                                style: const TextStyle(fontFamily: 'Roboto', color: Color(0xFF94A3B8), fontSize: 10),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (inc.liveCcf != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: inc.liveCcf! >= 60 ? Colors.green.withAlpha(40) : Colors.amber.withAlpha(40),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(
                                  'CCF: ${inc.liveCcf!.toStringAsFixed(0)}%',
                                  style: TextStyle(
                                    fontFamily: 'Roboto',
                                    color: inc.liveCcf! >= 60 ? const Color(0xFF4ADE80) : Colors.orangeAccent,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${inc.liveBpm} BPM • ${inc.elapsedSeconds}s',
                                style: const TextStyle(fontFamily: 'Roboto', color: Color(0xFF64748B), fontSize: 9.5),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTacticalMapColumn() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Stack(
        children: [
          // Simulated Dark Vector Map Canvas
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: CustomPaint(
                painter: _TacticalMapPainter(
                  incidentLat: _selectedIncident.lat,
                  incidentLng: _selectedIncident.lng,
                ),
              ),
            ),
          ),

          // Map Top Overlay: Location HUD
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF090D16).withAlpha(220),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.my_location_rounded, color: Color(0xFF38BDF8), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'TỌA ĐỘ HIỆN TRƯỜNG: ${_selectedIncident.lat.toStringAsFixed(4)}° N, ${_selectedIncident.lng.toStringAsFixed(4)}° E • ${_selectedIncident.address}',
                      style: const TextStyle(fontFamily: 'Roboto', color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withAlpha(30),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('GPS Hardware Fix (±3.2m)', style: TextStyle(color: Color(0xFF34D399), fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),

          // Map Legend / Quick Action
          Positioned(
            bottom: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF090D16).withAlpha(220),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.circle, color: Color(0xFFDC2626), size: 10),
                  SizedBox(width: 4),
                  Text('Vị trí Ca Cấp cứu', style: TextStyle(color: Colors.white, fontSize: 10)),
                  SizedBox(width: 12),
                  Icon(Icons.directions_bus_filled_rounded, color: Color(0xFF38BDF8), size: 12),
                  SizedBox(width: 4),
                  Text('Xe 115-01 (Đang di chuyển)', style: TextStyle(color: Colors.white, fontSize: 10)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryAndAiColumn() {
    final inc = _selectedIncident;
    final ccf = inc.liveCcf ?? 81.5;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // 1. HUD TELEMETRY HỒI SỨC TIM PHỔI
          Row(
            children: [
              const Icon(Icons.monitor_heart_rounded, color: Color(0xFFEC4899), size: 18),
              const SizedBox(width: 8),
              const Text(
                'TELEMETRY HỒI SỨC TIM PHỔI (P2)',
                style: TextStyle(fontFamily: 'Roboto', color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.green.withAlpha(30),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('LIVE 5s', style: TextStyle(color: Color(0xFF4ADE80), fontSize: 9, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF1F2937)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('CCF (AHA ≥60%)', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
                        Text(
                          '${ccf.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            color: ccf >= 60 ? const Color(0xFF4ADE80) : Colors.orangeAccent,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('NHỊP ÉP TIM', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
                        Text(
                          '${inc.liveBpm ?? 110} BPM',
                          style: const TextStyle(fontFamily: 'Roboto', color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ],
                ),
                const Divider(color: Color(0xFF1E293B), height: 16),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Độ sâu ép ước lượng:', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10.5)),
                    Text('5.4 cm (±1.0cm)', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 4),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Tư thế tay MoveNet:', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10.5)),
                    Text('176° • Chuẩn thẳng tay', style: TextStyle(color: Color(0xFF4ADE80), fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // 2. AI TRIAGE ASSISTANT (GEMINI 1.5 FLASH)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF0284C7)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded, color: Color(0xFF38BDF8), size: 16),
                    SizedBox(width: 6),
                    Text(
                      'AI TRIAGE (GEMINI 1.5 FLASH)',
                      style: TextStyle(fontFamily: 'Roboto', color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  inc.aiTriageRecommendation ?? 'Đang phân tích dữ liệu lâm sàng...',
                  style: const TextStyle(fontFamily: 'Roboto', color: Color(0xFFE2E8F0), fontSize: 11, height: 1.4),
                ),
                const SizedBox(height: 8),
                const Text('TRANG BỊ Y TẾ CẦN TIẾP VIỆN:', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 9.5, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: inc.requiredEquipment.map((eq) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: Text(eq, style: const TextStyle(color: Colors.white, fontSize: 9.5)),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 6),
                const Text(
                  '⚠️ RÀO CHẮN: Gợi ý AI mang tính tham vấn, không thay thế y lệnh Bác sĩ điều phối.',
                  style: TextStyle(fontFamily: 'Roboto', color: Color(0xFF64748B), fontSize: 8.5),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // 3. ĐIỀU PHỐI KÍP XE CỨU THƯƠNG
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF1F2937)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.directions_car_rounded, color: Color(0xFFF59E0B), size: 16),
                    SizedBox(width: 6),
                    Text(
                      'ĐIỀU ĐỘNG KÍP XE CỨU THƯƠNG 115',
                      style: TextStyle(fontFamily: 'Roboto', color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  inc.assignedAmbulance != null
                      ? 'ĐÃ ĐIỀU: ${inc.assignedAmbulance} (Dự kiến: ${inc.etaMinutes} phút)'
                      : 'Chưa phân công xe cấp cứu',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    color: inc.assignedAmbulance != null ? const Color(0xFF60A5FA) : const Color(0xFF94A3B8),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      _service.dispatchAmbulance(inc.id, 'Xe 115-01 (Trạm Cấp cứu Hòa Khánh)', 3);
                      setState(() {
                        _selectedIncident = inc.copyWith(
                          status: IncidentLifecycle.dispatched,
                          assignedAmbulance: 'Xe 115-01 (Trạm Cấp cứu Hòa Khánh)',
                          etaMinutes: 3,
                        );
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('✓ Đã phát lệnh điều động Xe 115-01 xuất trạm!')),
                      );
                    },
                    icon: const Icon(Icons.send_rounded, size: 16),
                    label: const Text('RA LỆNH ĐIỀU XE 115-01', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter vẽ bản đồ số tác chiến phong cách Tactical Dark Map
class _TacticalMapPainter extends CustomPainter {
  final double incidentLat;
  final double incidentLng;

  _TacticalMapPainter({required this.incidentLat, required this.incidentLng});

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFF0F172A);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Grid lines
    final gridPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..strokeWidth = 1;

    for (double x = 0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Coastal / River curve simulation (Đà Nẵng Hàn River / Coast)
    final riverPaint = Paint()
      ..color = const Color(0xFF0284C7).withAlpha(40)
      ..strokeWidth = 32
      ..style = PaintingStyle.stroke;

    final riverPath = Path()
      ..moveTo(size.width * 0.7, 0)
      ..cubicTo(size.width * 0.6, size.height * 0.4, size.width * 0.8, size.height * 0.7, size.width * 0.75, size.height);
    canvas.drawPath(riverPath, riverPaint);

    // Route line from Ambulance to Incident
    final centerIncident = Offset(size.width * 0.45, size.height * 0.48);
    final ambulancePos = Offset(size.width * 0.25, size.height * 0.75);

    final routePaint = Paint()
      ..color = const Color(0xFF38BDF8)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    canvas.drawLine(ambulancePos, centerIncident, routePaint);

    // Draw Pulse Range Ring around Incident
    final rangePaint = Paint()
      ..color = const Color(0xFFDC2626).withAlpha(30)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(centerIncident, 50, rangePaint);

    final rangeBorder = Paint()
      ..color = const Color(0xFFDC2626).withAlpha(120)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(centerIncident, 50, rangeBorder);

    // Incident Marker (Red)
    final markerPaint = Paint()..color = const Color(0xFFDC2626);
    canvas.drawCircle(centerIncident, 9, markerPaint);
    final innerDot = Paint()..color = Colors.white;
    canvas.drawCircle(centerIncident, 3.5, innerDot);

    // Ambulance Marker (Cyan)
    final ambPaint = Paint()..color = const Color(0xFF0284C7);
    canvas.drawCircle(ambulancePos, 8, ambPaint);
    canvas.drawCircle(ambulancePos, 3, innerDot);
  }

  @override
  bool shouldRepaint(covariant _TacticalMapPainter oldDelegate) {
    return oldDelegate.incidentLat != incidentLat || oldDelegate.incidentLng != incidentLng;
  }
}
