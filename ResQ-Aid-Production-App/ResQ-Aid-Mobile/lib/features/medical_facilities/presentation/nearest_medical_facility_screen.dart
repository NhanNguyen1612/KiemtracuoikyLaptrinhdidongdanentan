import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../domain/medical_facility_model.dart';
import '../services/hybrid_google_map_service.dart';
import '../services/offline_medical_service.dart';
import '../../../core/services/location_service.dart';
import '../../sos/data/sos_payload.dart';
import 'widgets/offline_map_widget.dart';

class NearestMedicalFacilityScreen extends StatefulWidget {
  final FacilityType? initialFilter;
  final String? initialSearch;

  const NearestMedicalFacilityScreen({
    super.key,
    this.initialFilter,
    this.initialSearch,
  });

  @override
  State<NearestMedicalFacilityScreen> createState() => _NearestMedicalFacilityScreenState();
}

class _NearestMedicalFacilityScreenState extends State<NearestMedicalFacilityScreen> {
  LocationData? _currentLocation;
  bool _isLoadingGps = true;
  FacilityType? _selectedType;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isMapView = false;
  FacilityDistanceResult? _selectedMapFacility;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialFilter;
    if (widget.initialSearch != null) {
      _searchController.text = widget.initialSearch!;
      _searchQuery = widget.initialSearch!;
    }
    _loadLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLocation() async {
    setState(() => _isLoadingGps = true);
    final loc = await LocationService.getCurrentLocation();
    if (mounted) {
      setState(() {
        _currentLocation = loc;
        _isLoadingGps = false;
      });
    }
  }

  Future<void> _callPhone(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _showOfflineDirectionModal(BuildContext context, FacilityDistanceResult item) {
    final loc = _currentLocation ?? LocationService.fallbackLocation('GPS_OFFLINE');
    HybridRouteResult resolvedRoute = HybridGoogleMapService.instance.getInstantFallbackRoute(
      startLat: loc.lat,
      startLng: loc.lng,
      destLat: item.facility.lat,
      destLng: item.facility.lng,
      destinationName: item.facility.name,
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final roadDistKm = resolvedRoute.distanceKm > 0 ? resolvedRoute.distanceKm : item.distanceKm;
            final formattedRoadDist = roadDistKm < 1.0
                ? '${(roadDistKm * 1000).round()} m'
                : '${roadDistKm.toStringAsFixed(1)} km';
            final travelMinMoto = resolvedRoute.durationMinutesMoto;
            final travelMinWalk = resolvedRoute.durationMinutesWalk;
            final topSteps = resolvedRoute.turnByTurnSteps.take(4).toList();

            return Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.map_rounded, color: Color(0xFF38BDF8), size: 21),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          resolvedRoute.isExactStreetGeometry
                              ? 'BẢN ĐỒ GOOGLE HYBRID & LỘ TRÌNH THỰC TẾ'
                              : 'BẢN ĐỒ GOOGLE HYBRID (CHẾ ĐỘ OFFLINE)',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14.5,
                            letterSpacing: 0.4,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'Tự động lưu ô bản đồ Google dùng Offline • Kéo 2 ngón để phóng to',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),

                  // BẢN ĐỒ SLIPPY-TILE GOOGLE HYBRID SẮC NÉT
                  OfflineMapWidget(
                    height: 270,
                    userLocation: loc,
                    destination: item.facility,
                    distanceKm: item.distanceKm,
                    bearingDeg: item.bearingDeg,
                    compassDirection: item.compassDirection,
                    compassArrow: item.compassArrow,
                    onRouteResolved: (newRoute) {
                      setModalState(() {
                        resolvedRoute = newRoute;
                      });
                    },
                  ),
                  const SizedBox(height: 10),

                  // THÔNG SỐ CỰ LY ĐƯỜNG BỘ & THỜI GIAN DI CHUYỂN
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              item.compassArrow,
                              style: const TextStyle(
                                color: Color(0xFF10B981),
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              formattedRoadDist,
                              style: const TextStyle(
                                color: Color(0xFF10B981),
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '(${item.compassDirection})',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            const Icon(Icons.two_wheeler_rounded, size: 15, color: Color(0xFF38BDF8)),
                            const SizedBox(width: 4),
                            Text(
                              '~$travelMinMoto p',
                              style: const TextStyle(
                                color: Color(0xFF38BDF8),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Icon(Icons.directions_walk_rounded, size: 15, color: Color(0xFFFBBF24)),
                            const SizedBox(width: 2),
                            Text(
                              '~$travelMinWalk p',
                              style: const TextStyle(
                                color: Color(0xFFFBBF24),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // CHỈ DẪN TỪNG NGÃ RẼ TRÊN ĐƯỜNG PHỐ
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.facility.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.facility.address,
                          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                        ),
                        const SizedBox(height: 8),
                        ...topSteps.map(
                          (step) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.subdirectory_arrow_right_rounded,
                                  color: Color(0xFF38BDF8),
                                  size: 15,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    step,
                                    style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Nút Gọi trực ban & Mở Dẫn Đường Giọng Nói 3D Google Maps App (chính xác tọa độ GPS!)
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.phone_in_talk_rounded, size: 18),
                          label: Text(
                            'GỌI ${item.facility.phone}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                            overflow: TextOverflow.ellipsis,
                          ),
                          onPressed: () => _callPhone(item.facility.phone),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1A73E8),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.navigation_rounded, size: 18),
                          label: const Text(
                            'DẪN ĐƯỜNG GG MAPS',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            LocationService.openGoogleMapsTurnByTurn(
                              destLat: item.facility.lat,
                              destLng: item.facility.lng,
                              destName: item.facility.name,
                              originLat: loc.lat,
                              originLng: loc.lng,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final results = OfflineMedicalService.findNearestFacilities(
      userLocation: _currentLocation,
      typeFilter: _selectedType,
      searchQuery: _searchQuery,
    );

    // Điểm đến được chọn mặc định là cơ sở gần nhất
    final currentTarget = _selectedMapFacility ?? (results.isNotEmpty ? results.first : null);

    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TRẠM Y TẾ & BỆNH VIỆN',
              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                Icon(Icons.offline_bolt_rounded, color: Color(0xFF10B981), size: 12),
                SizedBox(width: 4),
                Text(
                  '100% NGOẠI TUYẾN • KHÔNG CẦN 4G',
                  style: TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: _isLoadingGps
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF38BDF8)),
                  )
                : const Icon(Icons.my_location_rounded, color: Color(0xFF38BDF8), size: 22),
            tooltip: 'Cập nhật lại GPS',
            onPressed: _isLoadingGps ? null : _loadLocation,
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. BANNER KHẨN CẤP 115
          Container(
            margin: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7F1D1D), Color(0xFF991B1B)],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.5)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
                  child: const Icon(Icons.phone_in_talk_rounded, color: Colors.white, size: 15),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'NGUY KỊCH ĐE DỌA TÍNH MẠNG?',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12.5),
                      ),
                      Text(
                        'Bấm gọi ngay 115 để điều xe cứu thương!',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFFDC2626),
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _callPhone('115'),
                  child: const Text('GỌI 115', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11.5)),
                ),
              ],
            ),
          ),

          // 2. CHUYỂN ĐỔI CHẾ ĐỘ HIỂN THỊ: DANH SÁCH vs BẢN ĐỒ OFFLINE
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _isMapView = false),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      decoration: BoxDecoration(
                        color: !_isMapView ? const Color(0xFF0284C7) : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.format_list_bulleted_rounded, size: 15, color: !_isMapView ? Colors.white : Colors.white60),
                          const SizedBox(width: 6),
                          Text(
                            'Danh Sách (${results.length})',
                            style: TextStyle(
                              color: !_isMapView ? Colors.white : Colors.white70,
                              fontWeight: !_isMapView ? FontWeight.bold : FontWeight.normal,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _isMapView = true),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      decoration: BoxDecoration(
                        color: _isMapView ? const Color(0xFF10B981) : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.map_rounded, size: 15, color: _isMapView ? Colors.white : Colors.white60),
                          const SizedBox(width: 6),
                          Text(
                            'Bản Đồ Google Hybrid',
                            style: TextStyle(
                              color: _isMapView ? Colors.white : Colors.white70,
                              fontWeight: _isMapView ? FontWeight.bold : FontWeight.normal,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3. THANH TÌM KIẾM OFFLINE
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              style: const TextStyle(color: Colors.white, fontSize: 13.5),
              decoration: InputDecoration(
                hintText: 'Tìm trạm y tế, bệnh viện, tên đường...',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 12.5),
                prefixIcon: const Icon(Icons.search_rounded, color: Colors.white54, size: 19),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, color: Colors.white54, size: 17),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFF1E293B),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // 4. FILTER TABS (TẤT CẢ / BỆNH VIỆN / TRẠM Y TẾ / NHÀ THUỐC)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                _buildFilterChip('Tất cả', null, Icons.local_hospital_rounded),
                const SizedBox(width: 8),
                _buildFilterChip('Trạm Y tế', FacilityType.clinic, Icons.medical_services_rounded),
                const SizedBox(width: 8),
                _buildFilterChip('Bệnh viện', FacilityType.hospital, Icons.apartment_rounded),
                const SizedBox(width: 8),
                _buildFilterChip('Cấp cứu 115', FacilityType.emergencyCenter, Icons.emergency_rounded),
                const SizedBox(width: 8),
                _buildFilterChip('Nhà thuốc', FacilityType.pharmacy, Icons.medication_rounded),
              ],
            ),
          ),

          // 5. THÔNG BÁO VỊ TRÍ GPS HIỆN TẠI
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 3),
            child: Row(
              children: [
                const Icon(Icons.near_me_rounded, color: Color(0xFF38BDF8), size: 13),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _currentLocation != null
                        ? 'Toạ độ bạn: ${_currentLocation!.lat.toStringAsFixed(4)}, ${_currentLocation!.lng.toStringAsFixed(4)} (GPS)'
                        : 'Vị trí mặc định (VKU, Đà Nẵng)',
                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10.5),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${results.length} cơ sở',
                  style: const TextStyle(color: Color(0xFF10B981), fontSize: 10.5, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          // 6. PHẦN THÂN: HIỂN THỊ DANH SÁCH HOẶC BẢN ĐỒ TOÀN CẢNH
          Expanded(
            child: _isMapView
                ? _buildFullMapView(results, currentTarget)
                : _buildListView(results),
          ),
        ],
      ),
    );
  }

  Widget _buildFullMapView(List<FacilityDistanceResult> results, FacilityDistanceResult? currentTarget) {
    if (results.isEmpty || currentTarget == null) {
      return const Center(
        child: Text('Không tìm thấy cơ sở y tế trên bản đồ', style: TextStyle(color: Colors.white54)),
      );
    }

    final loc = _currentLocation ?? LocationService.fallbackLocation('GPS_OFFLINE');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      child: Column(
        children: [
          // Bản đồ ngoại tuyến tương tác
          Expanded(
            child: OfflineMapWidget(
              height: double.infinity,
              userLocation: loc,
              destination: currentTarget.facility,
              distanceKm: currentTarget.distanceKm,
              bearingDeg: currentTarget.bearingDeg,
              compassDirection: currentTarget.compassDirection,
              compassArrow: currentTarget.compassArrow,
              allFacilities: results.map((r) => r.facility).toList(),
              onSelectFacility: (fac) {
                final found = results.firstWhere((r) => r.facility.id == fac.id, orElse: () => currentTarget);
                setState(() => _selectedMapFacility = found);
              },
            ),
          ),
          const SizedBox(height: 10),

          // Card thông tin nhanh cơ sở đang chọn trên bản đồ
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.18),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${currentTarget.compassArrow} ${currentTarget.formattedDistance}',
                        style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Hướng ${currentTarget.compassDirection}',
                      style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    Text(
                      currentTarget.facility.level,
                      style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 10.5),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  currentTarget.facility.name,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(
                  currentTarget.facility.address,
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0284C7),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.phone_in_talk_rounded, size: 14),
                        label: Text(
                          'GỌI ${currentTarget.facility.phone}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                        onPressed: () => _callPhone(currentTarget.facility.phone),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      flex: 3,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF10B981),
                          side: const BorderSide(color: Color(0xFF10B981)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.alt_route_rounded, size: 14),
                        label: const Text('CHỈ ĐƯỜNG', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        onPressed: () => _showOfflineDirectionModal(context, currentTarget),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      flex: 3,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A73E8),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.navigation_rounded, size: 14),
                        label: const Text('GG MAPS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        onPressed: () {
                          LocationService.openGoogleMapsTurnByTurn(
                            destLat: currentTarget.facility.lat,
                            destLng: currentTarget.facility.lng,
                            destName: currentTarget.facility.name,
                            originLat: loc.lat,
                            originLng: loc.lng,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListView(List<FacilityDistanceResult> results) {
    if (results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_off_rounded, color: Colors.white24, size: 48),
              const SizedBox(height: 12),
              const Text(
                'Không tìm thấy cơ sở y tế phù hợp',
                style: TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Hãy thử tìm từ khóa khác hoặc xóa bộ lọc loại cơ sở.',
                style: TextStyle(color: Colors.white38, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: const Color(0xFF38BDF8)),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Hiện tất cả cơ sở'),
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                    _selectedType = null;
                  });
                },
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final item = results[index];
        return _buildFacilityCard(item);
      },
    );
  }

  Widget _buildFilterChip(String label, FacilityType? type, IconData icon) {
    final isSelected = _selectedType == type;
    return InkWell(
      onTap: () => setState(() => _selectedType = type),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0284C7) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF38BDF8) : Colors.white12,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: isSelected ? Colors.white : Colors.white60),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFacilityCard(FacilityDistanceResult item) {
    final f = item.facility;
    final isClose = item.distanceKm < 2.0;
    final distColor = isClose ? const Color(0xFF10B981) : (item.distanceKm < 5.0 ? const Color(0xFF38BDF8) : const Color(0xFFF59E0B));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isClose ? const Color(0xFF10B981).withOpacity(0.3) : Colors.white10,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dòng 1: Khoảng cách + Hướng la bàn + Phân loại
          Row(
            children: [
              // Cự ly nổi bật
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: distColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: distColor.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.compassArrow,
                      style: TextStyle(color: distColor, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      item.formattedDistance,
                      style: TextStyle(
                        color: distColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),

              // Hướng la bàn
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Hướng ${item.compassDirection}',
                  style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              const Spacer(),

              // Cấp cứu 24/7
              if (f.is24_7)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
                  ),
                  child: const Text(
                    '24/7',
                    style: TextStyle(color: Color(0xFFF87171), fontSize: 10, fontWeight: FontWeight.w900),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Dòng 2: Tên cơ sở y tế
          Text(
            f.name,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 2),

          // Dòng 3: Cấp độ cơ sở
          Text(
            f.level,
            style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),

          // Dòng 4: Địa chỉ
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on_rounded, color: Colors.white38, size: 14),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  f.address,
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Dòng 5: Dịch vụ cấp cứu chips
          if (f.emergencyServices.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: f.emergencyServices.take(3).map((s) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    s,
                    style: const TextStyle(color: Colors.white54, fontSize: 10),
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 12),

          // Dòng 6: Các nút hành động tức thì (Gọi trực ban + Bản đồ trong App + Dẫn đường 3D Google Maps)
          Row(
            children: [
              Expanded(
                flex: 5,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.phone_in_talk_rounded, size: 15),
                  label: Text(
                    'GỌI ${f.phone}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
                    overflow: TextOverflow.ellipsis,
                  ),
                  onPressed: () => _callPhone(f.phone),
                ),
              ),
              const SizedBox(width: 6),

              Expanded(
                flex: 4,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF10B981),
                    side: BorderSide(color: const Color(0xFF10B981).withOpacity(0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.map_rounded, size: 15),
                  label: const Text(
                    'CHỈ ĐƯỜNG',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
                    overflow: TextOverflow.ellipsis,
                  ),
                  onPressed: () => _showOfflineDirectionModal(context, item),
                ),
              ),
              const SizedBox(width: 6),

              Tooltip(
                message: 'Mở dẫn đường giọng nói 3D trên ứng dụng Google Maps',
                child: Material(
                  color: const Color(0xFF1A73E8),
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      LocationService.openGoogleMapsTurnByTurn(
                        destLat: f.lat,
                        destLng: f.lng,
                        destName: f.name,
                        originLat: _currentLocation?.lat,
                        originLng: _currentLocation?.lng,
                      );
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                      child: Icon(Icons.navigation_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
