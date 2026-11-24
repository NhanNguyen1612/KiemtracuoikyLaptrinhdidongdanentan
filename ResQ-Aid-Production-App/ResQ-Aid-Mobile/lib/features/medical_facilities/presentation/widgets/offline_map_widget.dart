import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../../core/services/location_service.dart';
import '../../../sos/data/sos_payload.dart';
import '../../data/medical_facilities_data.dart';
import '../../data/offline_map_roads.dart';
import '../../domain/medical_facility_model.dart';
import '../../services/hybrid_google_map_service.dart';

class OfflineMapWidget extends StatefulWidget {
  final LocationData userLocation;
  final MedicalFacility destination;
  final double distanceKm;
  final double bearingDeg;
  final String compassDirection;
  final String compassArrow;
  final List<MedicalFacility>? allFacilities;
  final Function(MedicalFacility)? onSelectFacility;
  final ValueChanged<HybridRouteResult>? onRouteResolved;
  final bool showControls;
  final double height;

  const OfflineMapWidget({
    super.key,
    required this.userLocation,
    required this.destination,
    required this.distanceKm,
    required this.bearingDeg,
    required this.compassDirection,
    required this.compassArrow,
    this.allFacilities,
    this.onSelectFacility,
    this.onRouteResolved,
    this.showControls = true,
    this.height = 300,
  });

  @override
  State<OfflineMapWidget> createState() => _OfflineMapWidgetState();
}

class _OfflineMapWidgetState extends State<OfflineMapWidget> with SingleTickerProviderStateMixin {
  MapTileStyle _mapStyle = MapTileStyle.googleStandard;
  late double _centerLat;
  late double _centerLng;
  double _zoomLevel = 14.5;
  bool _hasInitialFit = false;

  // Trạng thái thao tác cử chỉ đa điểm (Pinch-to-Zoom + Pan)
  double _scaleStartZoom = 14.5;
  Offset? _lastFocalPoint;

  // Lộ trình thực tế (Online OSRM / Disk Cache / Offline A*)
  late HybridRouteResult _activeRoute;
  int _cachedTileCount = 0;
  bool _isDownloadingOffline = false;
  double _downloadProgress = 0.0;

  late AnimationController _pulseController;
  int _tileRepaintTick = 0;

  @override
  void initState() {
    super.initState();
    _centerLat = (widget.userLocation.lat + widget.destination.lat) / 2.0;
    _centerLng = (widget.userLocation.lng + widget.destination.lng) / 2.0;
    _activeRoute = HybridGoogleMapService.instance.getInstantFallbackRoute(
      startLat: widget.userLocation.lat,
      startLng: widget.userLocation.lng,
      destLat: widget.destination.lat,
      destLng: widget.destination.lng,
      destinationName: widget.destination.name,
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _loadRouteAndStats();
  }

  @override
  void didUpdateWidget(covariant OfflineMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final destChanged = oldWidget.destination.id != widget.destination.id;
    final userMoved = (oldWidget.userLocation.lat - widget.userLocation.lat).abs() > 0.0005 ||
        (oldWidget.userLocation.lng - widget.userLocation.lng).abs() > 0.0005;

    if (destChanged || userMoved) {
      _hasInitialFit = false;
      _activeRoute = HybridGoogleMapService.instance.getInstantFallbackRoute(
        startLat: widget.userLocation.lat,
        startLng: widget.userLocation.lng,
        destLat: widget.destination.lat,
        destLng: widget.destination.lng,
        destinationName: widget.destination.name,
      );
      _loadRouteAndStats();
    }
  }

  Future<void> _loadRouteAndStats() async {
    final route = await HybridGoogleMapService.instance.computeHybridRoute(
      startLat: widget.userLocation.lat,
      startLng: widget.userLocation.lng,
      destLat: widget.destination.lat,
      destLng: widget.destination.lng,
      destinationName: widget.destination.name,
    );
    final tileCount = await HybridGoogleMapService.instance.countCachedTiles();
    if (!mounted) return;
    setState(() {
      _activeRoute = route;
      _cachedTileCount = tileCount;
    });
    widget.onRouteResolved?.call(route);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _onTileLoaded() {
    if (!mounted) return;
    setState(() {
      _tileRepaintTick++;
    });
  }

  void _fitBounds(Size viewSize) {
    _centerLat = (widget.userLocation.lat + widget.destination.lat) / 2.0;
    _centerLng = (widget.userLocation.lng + widget.destination.lng) / 2.0;
    _zoomLevel = HybridGoogleMapService.optimalZoomForBounds(
      lat1: widget.userLocation.lat,
      lng1: widget.userLocation.lng,
      lat2: widget.destination.lat,
      lng2: widget.destination.lng,
      widthPx: viewSize.width,
      heightPx: viewSize.height,
    );
  }

  void _recenter(Size viewSize) {
    setState(() {
      _fitBounds(viewSize);
    });
  }

  void _zoomIn() {
    setState(() {
      _zoomLevel = (_zoomLevel + 0.85).clamp(10.0, 18.2);
    });
  }

  void _zoomOut() {
    setState(() {
      _zoomLevel = (_zoomLevel - 0.85).clamp(10.0, 18.2);
    });
  }

  void _cycleMapLayer() {
    setState(() {
      switch (_mapStyle) {
        case MapTileStyle.googleStandard:
          _mapStyle = MapTileStyle.googleHybridSatellite;
          break;
        case MapTileStyle.googleHybridSatellite:
          _mapStyle = MapTileStyle.googleTerrain;
          break;
        case MapTileStyle.googleTerrain:
          _mapStyle = MapTileStyle.googleStandard;
          break;
      }
    });
  }

  Future<void> _downloadOfflineAreaPack() async {
    if (_isDownloadingOffline) return;
    setState(() {
      _isDownloadingOffline = true;
      _downloadProgress = 0.02;
    });

    final saved = await HybridGoogleMapService.instance.downloadOfflineArea(
      centerLat: widget.userLocation.lat,
      centerLng: widget.userLocation.lng,
      style: _mapStyle,
      radiusKm: 3.8,
      zoomLevels: const [13, 14, 15],
      onProgress: (done, total) {
        if (!mounted || total <= 0) return;
        setState(() {
          _downloadProgress = (done / total).clamp(0.0, 1.0);
        });
      },
    );

    final totalCached = await HybridGoogleMapService.instance.countCachedTiles();
    if (!mounted) return;
    setState(() {
      _isDownloadingOffline = false;
      _cachedTileCount = math.max(saved, totalCached);
      _tileRepaintTick++;
    });

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved > 0
              ? 'Đã lưu Offline $_cachedTileCount ô bản đồ Google (${_mapStyle.labelVi}) bán kính 4km!'
              : 'Đang ở chế độ không mạng — sử dụng dữ liệu bản đồ Offline có sẵn trong máy.',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Offset _projectLatLng(double lat, double lng, Size size) {
    final centerWx = HybridGoogleMapService.lngToWorldX(_centerLng, _zoomLevel);
    final centerWy = HybridGoogleMapService.latToWorldY(_centerLat, _zoomLevel);
    final ptWx = HybridGoogleMapService.lngToWorldX(lng, _zoomLevel);
    final ptWy = HybridGoogleMapService.latToWorldY(lat, _zoomLevel);
    return Offset(
      size.width / 2.0 + (ptWx - centerWx),
      size.height / 2.0 + (ptWy - centerWy),
    );
  }

  void _handleMapTapUp(TapUpDetails details, Size viewSize) {
    if (widget.onSelectFacility == null) return;
    final facilities = widget.allFacilities ?? seedMedicalFacilities;
    final tapPos = details.localPosition;

    MedicalFacility? bestHit;
    double bestDist = 30.0; // Bán kính chạm nhạy 30px quanh ghim y tế
    for (final fac in facilities) {
      final screenPos = _projectLatLng(fac.lat, fac.lng, viewSize);
      final dist = (screenPos - tapPos).distance;
      if (dist < bestDist) {
        bestDist = dist;
        bestHit = fac;
      }
    }
    if (bestHit != null) {
      widget.onSelectFacility!(bestHit);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: const Color(0xFFE8EAED),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.18), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.38),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final viewSize = Size(
            constraints.maxWidth.isFinite ? constraints.maxWidth : 340,
            constraints.maxHeight.isFinite ? constraints.maxHeight : 260,
          );
          if (!_hasInitialFit && viewSize.width > 40 && viewSize.height > 40) {
            _fitBounds(viewSize);
            _hasInitialFit = true;
          }

          return Stack(
            children: [
              // 1. LỚP BẢN ĐỒ TƯƠNG TÁC ĐA ĐIỂM SLIPPY-TILE GOOGLE HYBRID + LỘ TRÌNH XANH DƯƠNG
              Positioned.fill(
                child: GestureDetector(
                  onDoubleTap: _zoomIn,
                  onTapUp: (d) => _handleMapTapUp(d, viewSize),
                  onScaleStart: (details) {
                    _scaleStartZoom = _zoomLevel;
                    _lastFocalPoint = details.localFocalPoint;
                  },
                  onScaleUpdate: (details) {
                    setState(() {
                      // 1. Dịch chuyển tâm bản đồ theo ngón tay (1 hoặc 2 ngón)
                      if (_lastFocalPoint != null) {
                        final delta = details.localFocalPoint - _lastFocalPoint!;
                        final curWx = HybridGoogleMapService.lngToWorldX(_centerLng, _zoomLevel);
                        final curWy = HybridGoogleMapService.latToWorldY(_centerLat, _zoomLevel);
                        _centerLng = HybridGoogleMapService.worldXToLng(curWx - delta.dx, _zoomLevel)
                            .clamp(-179.9, 179.9);
                        _centerLat = HybridGoogleMapService.worldYToLat(curWy - delta.dy, _zoomLevel)
                            .clamp(-84.0, 84.0);
                      }
                      _lastFocalPoint = details.localFocalPoint;

                      // 2. Phóng to / Thu nhỏ mượt bằng 2 ngón tay (Pinch-to-Zoom)
                      if ((details.scale - 1.0).abs() > 0.01) {
                        final zoomDelta = math.log(details.scale) / math.ln2;
                        _zoomLevel = (_scaleStartZoom + zoomDelta).clamp(10.0, 18.2);
                      }
                    });
                  },
                  child: AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, _) {
                      return CustomPaint(
                        size: Size.infinite,
                        painter: _GoogleHybridSlippyMapPainter(
                          mapStyle: _mapStyle,
                          centerLat: _centerLat,
                          centerLng: _centerLng,
                          zoomLevel: _zoomLevel,
                          userLocation: widget.userLocation,
                          destination: widget.destination,
                          route: _activeRoute,
                          fallbackDistanceKm: widget.distanceKm,
                          compassArrow: widget.compassArrow,
                          allFacilities: widget.allFacilities ?? seedMedicalFacilities,
                          roads: seedOfflineRoads,
                          waterways: seedOfflineWaterways,
                          pulseValue: _pulseController.value,
                          repaintTick: _tileRepaintTick,
                          onTileReady: _onTileLoaded,
                        ),
                      );
                    },
                  ),
                ),
              ),

              // 2. GÓC TRÊN TRÁI: TRẠNG THÁI GOOGLE HYBRID + BỘ ĐỆM OFFLINE
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.18),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _activeRoute.isExactStreetGeometry
                            ? Icons.map_rounded
                            : Icons.offline_pin_rounded,
                        color: const Color(0xFF1A73E8),
                        size: 14,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _cachedTileCount > 0
                            ? 'Google Map • $_cachedTileCount ô Offline'
                            : 'Google Map • ${_mapStyle.labelVi}',
                        style: const TextStyle(
                          color: Color(0xFF1F2937),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 3. GÓC TRÊN PHẢI: NÚT CHUYỂN LỚP BẢN ĐỒ (ĐƯỜNG PHỐ / VỆ TINH / ĐỊA HÌNH) CHUẨN GOOGLE MAPS
              if (widget.showControls)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Material(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(12),
                    elevation: 3,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _cycleMapLayer,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.layers_rounded, size: 15, color: Color(0xFF1A73E8)),
                            const SizedBox(width: 4),
                            Text(
                              _mapStyle.labelVi,
                              style: const TextStyle(
                                color: Color(0xFF1F2937),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // 4. CỤM NÚT ĐIỀU KHIỂN PHÓNG TO / THU NHỎ / VỀ TÂM KIỂU GOOGLE MAPS (CẠNH PHẢI)
              if (widget.showControls)
                Positioned(
                  right: 10,
                  bottom: 46,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.96),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildGoogleControlIcon(
                          icon: Icons.add_rounded,
                          tooltip: 'Phóng to',
                          onTap: _zoomIn,
                        ),
                        Container(width: 24, height: 1, color: Colors.black12),
                        _buildGoogleControlIcon(
                          icon: Icons.remove_rounded,
                          tooltip: 'Thu nhỏ',
                          onTap: _zoomOut,
                        ),
                        Container(width: 24, height: 1, color: Colors.black12),
                        _buildGoogleControlIcon(
                          icon: Icons.my_location_rounded,
                          tooltip: 'Căn giữa lộ trình',
                          iconColor: const Color(0xFF1A73E8),
                          onTap: () => _recenter(viewSize),
                        ),
                      ],
                    ),
                  ),
                ),

              // 5. GÓC DƯỚI TRÁI: NÚT TẢI TRƯỚC BẢN ĐỒ GOOGLE KHU VỰC OFFLINE (1 CHẠM)
              if (widget.showControls)
                Positioned(
                  left: 10,
                  bottom: 10,
                  child: Material(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(18),
                    elevation: 3,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: _isDownloadingOffline ? null : _downloadOfflineAreaPack,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_isDownloadingOffline)
                              const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF1A73E8),
                                ),
                              )
                            else
                              Icon(
                                _cachedTileCount > 25
                                    ? Icons.download_done_rounded
                                    : Icons.downloading_rounded,
                                size: 14,
                                color: _cachedTileCount > 25
                                    ? const Color(0xFF059669)
                                    : const Color(0xFF1A73E8),
                              ),
                            const SizedBox(width: 5),
                            Text(
                              _isDownloadingOffline
                                  ? 'Đang lưu Offline ${(_downloadProgress * 100).round()}%'
                                  : (_cachedTileCount > 25 ? 'Đã lưu vùng 4km' : 'Lưu Offline 4km'),
                              style: const TextStyle(
                                color: Color(0xFF1F2937),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // 6. GÓC DƯỚI PHẢI: NÚT MỞ TRỰC TIẾP DẪN ĐƯỜNG GIỌNG NÓI 3D GOOGLE MAPS APP
              if (widget.showControls)
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: Material(
                    color: const Color(0xFF1A73E8),
                    borderRadius: BorderRadius.circular(18),
                    elevation: 3,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () {
                        LocationService.openGoogleMapsTurnByTurn(
                          destLat: widget.destination.lat,
                          destLng: widget.destination.lng,
                          destName: widget.destination.name,
                          originLat: widget.userLocation.lat,
                          originLng: widget.userLocation.lng,
                        );
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.navigation_rounded, size: 13, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              'GG Maps 3D',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildGoogleControlIcon({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color iconColor = const Color(0xFF374151),
  }) {
    return SizedBox(
      width: 34,
      height: 34,
      child: IconButton(
        icon: Icon(icon, size: 18, color: iconColor),
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        onPressed: onTap,
      ),
    );
  }
}

/// Bộ kết xuất Slippy-Tile Chuẩn Google Maps + Lộ trình Xanh Dương + Lớp nền Sáng Sắc Nét khi Offline chưa tải Tile
class _GoogleHybridSlippyMapPainter extends CustomPainter {
  final MapTileStyle mapStyle;
  final double centerLat;
  final double centerLng;
  final double zoomLevel;
  final LocationData userLocation;
  final MedicalFacility destination;
  final HybridRouteResult route;
  final double fallbackDistanceKm;
  final String compassArrow;
  final List<MedicalFacility> allFacilities;
  final List<OfflineRoad> roads;
  final List<OfflineWaterway> waterways;
  final double pulseValue;
  final int repaintTick;
  final VoidCallback onTileReady;

  _GoogleHybridSlippyMapPainter({
    required this.mapStyle,
    required this.centerLat,
    required this.centerLng,
    required this.zoomLevel,
    required this.userLocation,
    required this.destination,
    required this.route,
    required this.fallbackDistanceKm,
    required this.compassArrow,
    required this.allFacilities,
    required this.roads,
    required this.waterways,
    required this.pulseValue,
    required this.repaintTick,
    required this.onTileReady,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerWx = HybridGoogleMapService.lngToWorldX(centerLng, zoomLevel);
    final centerWy = HybridGoogleMapService.latToWorldY(centerLat, zoomLevel);

    Offset project(double lat, double lng) {
      final wx = HybridGoogleMapService.lngToWorldX(lng, zoomLevel);
      final wy = HybridGoogleMapService.latToWorldY(lat, zoomLevel);
      return Offset(size.width / 2.0 + (wx - centerWx), size.height / 2.0 + (wy - centerWy));
    }

    // 1. NỀN ĐÔ THỊ SÁNG CHUẨN GOOGLE MAPS DAYLIGHT (Hiển thị ngay cả khi mất mạng & chưa kịp lưu Tile)
    _drawGoogleDaylightBase(canvas, size, project);

    // 2. KẾT XUẤT LƯỚI Ô BẢN ĐỒ RASTER (GOOGLE STREET / HYBRID SATELLITE / TERRAIN + BỘ ĐỆM FLASH OFFLINE)
    final allTilesRendered = _drawSlippyTiles(canvas, size);

    // Nếu ở vùng chưa tải hết ô bản đồ khi mất mạng, vẽ bổ sung đường phố nội bộ phong cách Google Maps
    if (!allTilesRendered) {
      _drawCleanOfflineVectorOverlay(canvas, project);
    }

    // 3. VẼ LỘ TRÌNH DẪN ĐƯỜNG MÀU XANH GOOGLE NAVIGATION (#1A73E8)
    final routePoints = route.waypoints.map((pt) => project(pt.lat, pt.lng)).toList();
    _drawGoogleStyleRoute(canvas, routePoints);

    // 4. VẼ CÁC CƠ SỞ Y TẾ LÂN CẬN (GHIM Y TẾ MINI CÓ THỂ CHẠM CHỌN)
    _drawNearbyMedicalPins(canvas, size, project);

    // 5. VẼ GHIM GIỌT NƯỚC BỆNH VIỆN ĐÍCH ĐẾN & VỊ TRÍ GPS NGƯỜI DÙNG
    final destPos = project(destination.lat, destination.lng);
    final userPos = project(userLocation.lat, userLocation.lng);
    _drawDestinationTeardropPin(canvas, destPos);
    _drawGoogleBlueUserPuck(canvas, userPos);
  }

  void _drawGoogleDaylightBase(Canvas canvas, Size size, Offset Function(double, double) project) {
    final landColor = mapStyle.isDarkBackground
        ? const Color(0xFF111827)
        : const Color(0xFFF1F3F4); // Nền xám sáng đặc trưng của Google Maps
    canvas.drawRect(Offset.zero & size, Paint()..color = landColor);

    // Lưới tọa độ siêu mảnh tinh tế (chỉ thấy khi chưa có tile)
    final subtleGrid = Paint()
      ..color = mapStyle.isDarkBackground
          ? Colors.white.withOpacity(0.05)
          : const Color(0xFFE2E8F0)
      ..strokeWidth = 0.8;
    const step = 64.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), subtleGrid);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), subtleGrid);
    }
  }

  bool _drawSlippyTiles(Canvas canvas, Size size) {
    final tileZ = zoomLevel.floor().clamp(10, 18);
    final scaleFactor = math.pow(2.0, zoomLevel - tileZ);
    final scaledTilePx = HybridGoogleMapService.tileSize * scaleFactor;

    final centerTileWx = HybridGoogleMapService.lngToWorldX(centerLng, tileZ.toDouble());
    final centerTileWy = HybridGoogleMapService.latToWorldY(centerLat, tileZ.toDouble());

    final halfWInWorld = (size.width / 2.0) / scaleFactor;
    final halfHInWorld = (size.height / 2.0) / scaleFactor;

    final maxTileIndex = (1 << tileZ) - 1;
    final minTx = ((centerTileWx - halfWInWorld) / HybridGoogleMapService.tileSize).floor().clamp(0, maxTileIndex);
    final maxTx = ((centerTileWx + halfWInWorld) / HybridGoogleMapService.tileSize).floor().clamp(0, maxTileIndex);
    final minTy = ((centerTileWy - halfHInWorld) / HybridGoogleMapService.tileSize).floor().clamp(0, maxTileIndex);
    final maxTy = ((centerTileWy + halfHInWorld) / HybridGoogleMapService.tileSize).floor().clamp(0, maxTileIndex);

    final tilePaint = Paint()..filterQuality = FilterQuality.medium;
    int totalNeeded = 0;
    int exactLoaded = 0;

    for (int tx = minTx; tx <= maxTx; tx++) {
      for (int ty = minTy; ty <= maxTy; ty++) {
        totalNeeded++;
        final left = size.width / 2.0 + (tx * HybridGoogleMapService.tileSize - centerTileWx) * scaleFactor;
        final top = size.height / 2.0 + (ty * HybridGoogleMapService.tileSize - centerTileWy) * scaleFactor;
        // Cộng 0.6px khử đường kẻ hở sub-pixel giữa 2 ô bản đồ liền kề
        final dstRect = Rect.fromLTWH(left, top, scaledTilePx + 0.6, scaledTilePx + 0.6);

        final memImg = HybridGoogleMapService.instance.getMemoryTile(mapStyle, tileZ, tx, ty);
        if (memImg != null) {
          exactLoaded++;
          final srcRect = Rect.fromLTWH(0, 0, memImg.width.toDouble(), memImg.height.toDouble());
          canvas.drawImageRect(memImg, srcRect, dstRect, tilePaint);
        } else {
          // Hiển thị tạm ô cha (Overzoom) nếu có trong bộ đệm để không bị chớp trắng
          final parent = HybridGoogleMapService.instance.getOverzoomParentTile(mapStyle, tileZ, tx, ty);
          if (parent != null) {
            canvas.drawImageRect(parent.image, parent.srcRect, dstRect, tilePaint);
          }
          HybridGoogleMapService.instance.requestTile(mapStyle, tileZ, tx, ty, onTileReady);
        }
      }
    }

    return totalNeeded > 0 && exactLoaded == totalNeeded;
  }

  /// Lớp đường phố Vector tông sáng chuẩn Google Maps khi ở chế độ Offline hoàn toàn chưa lưu Tile
  void _drawCleanOfflineVectorOverlay(Canvas canvas, Offset Function(double, double) project) {
    final zoomScale = math.pow(2.0, (zoomLevel - 14.0).clamp(-1.5, 2.0)).toDouble();

    // Sông ngòi màu xanh da trời chuẩn Google Maps (#AADAFF)
    for (final river in waterways) {
      if (river.coords.length < 2) continue;
      final path = Path();
      final p0 = project(river.coords.first.lat, river.coords.first.lng);
      path.moveTo(p0.dx, p0.dy);
      for (int i = 1; i < river.coords.length; i++) {
        final pt = project(river.coords[i].lat, river.coords[i].lng);
        path.lineTo(pt.dx, pt.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF90CAF9)
          ..strokeWidth = (13.0 * zoomScale).clamp(6.0, 26.0)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    // Trục đường chính màu vàng cam nhẹ (#FDE68A) & đường nội thị màu trắng viền xám giống hệt Google Maps
    for (final road in roads) {
      if (road.coords.length < 2) continue;
      final path = Path();
      final p0 = project(road.coords.first.lat, road.coords.first.lng);
      path.moveTo(p0.dx, p0.dy);
      for (int i = 1; i < road.coords.length; i++) {
        final pt = project(road.coords[i].lat, road.coords[i].lng);
        path.lineTo(pt.dx, pt.dy);
      }

      final casingWidth = ((road.isHighway ? 8.0 : 5.2) * zoomScale).clamp(3.0, 16.0);
      final coreWidth = ((road.isHighway ? 5.6 : 3.4) * zoomScale).clamp(1.8, 12.0);

      canvas.drawPath(
        path,
        Paint()
          ..color = road.isHighway ? const Color(0xFFF59E0B) : const Color(0xFFCBD5E1)
          ..strokeWidth = casingWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = road.isHighway ? const Color(0xFFFEF08A) : Colors.white
          ..strokeWidth = coreWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );

      if (zoomLevel >= 13.2) {
        final mid = project(
          road.coords[road.coords.length ~/ 2].lat,
          road.coords[road.coords.length ~/ 2].lng,
        );
        _drawCrispLabel(canvas, Offset(mid.dx, mid.dy - 7), road.name, const Color(0xFF475569));
      }
    }
  }

  void _drawGoogleStyleRoute(Canvas canvas, List<Offset> pts) {
    if (pts.length < 2) return;

    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }

    // Bóng mờ nhẹ bên dưới vạch chỉ đường
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF1A73E8).withOpacity(0.24)
        ..strokeWidth = 13.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Viền xanh đậm chuẩn Google Navigation (#174EA6)
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF174EA6)
        ..strokeWidth = 8.4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Lõi xanh dương Google (#1A73E8 / #4285F4)
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF2563EB)
        ..strokeWidth = 5.4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Mũi tên điều hướng trắng chạy dọc lộ trình
    double accDist = 0.0;
    for (int i = 0; i < pts.length - 1; i++) {
      final p1 = pts[i];
      final p2 = pts[i + 1];
      final dx = p2.dx - p1.dx;
      final dy = p2.dy - p1.dy;
      final segLen = math.sqrt(dx * dx + dy * dy);
      accDist += segLen;
      if (segLen > 24 && accDist > 48) {
        accDist = 0.0;
        final ux = dx / segLen;
        final uy = dy / segLen;
        final nx = -uy;
        final ny = ux;
        final cx = p1.dx + dx * 0.5;
        final cy = p1.dy + dy * 0.5;

        final chevron = Path()
          ..moveTo(cx - ux * 4.5 + nx * 3.5, cy - uy * 4.5 + ny * 3.5)
          ..lineTo(cx + ux * 3.5, cy + uy * 3.5)
          ..lineTo(cx - ux * 4.5 - nx * 3.5, cy - uy * 4.5 - ny * 3.5);
        canvas.drawPath(
          chevron,
          Paint()
            ..color = Colors.white
            ..strokeWidth = 1.8
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );
      }
    }

    // Nhãn thời gian & cự ly nổi kiểu Google Maps trên giữa tuyến đường
    final midPt = pts.length == 2
        ? Offset((pts[0].dx + pts[1].dx) / 2.0, (pts[0].dy + pts[1].dy) / 2.0)
        : pts[pts.length ~/ 2];
    final dispKm = route.distanceKm > 0 ? route.distanceKm : fallbackDistanceKm;
    final distText = dispKm < 1.0 ? '${(dispKm * 1000).round()} m' : '${dispKm.toStringAsFixed(1)} km';
    _drawGoogleEtaBubble(canvas, midPt, '🛵 ${route.durationMinutesMoto} phút • $distText');
  }

  void _drawGoogleEtaBubble(Canvas canvas, Offset center, String label) {
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Color(0xFF174EA6),
          fontWeight: FontWeight.w900,
          fontSize: 10.5,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();

    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(center.dx, center.dy - 14), width: tp.width + 14, height: tp.height + 7),
      const Radius.circular(14),
    );

    canvas.drawRRect(
      rect.shift(const Offset(0, 2)),
      Paint()..color = Colors.black.withOpacity(0.22),
    );
    canvas.drawRRect(rect, Paint()..color = Colors.white);
    canvas.drawRRect(
      rect,
      Paint()
        ..color = const Color(0xFF1A73E8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3,
    );
    tp.paint(canvas, Offset(rect.center.dx - tp.width / 2.0, rect.center.dy - tp.height / 2.0));
  }

  void _drawNearbyMedicalPins(Canvas canvas, Size size, Offset Function(double, double) project) {
    for (final fac in allFacilities) {
      if (fac.id == destination.id) continue;
      final pos = project(fac.lat, fac.lng);
      if (pos.dx < -20 || pos.dx > size.width + 20 || pos.dy < -20 || pos.dy > size.height + 20) {
        continue;
      }

      final pinColor = fac.type == FacilityType.hospital
          ? const Color(0xFFDC2626)
          : (fac.type == FacilityType.clinic ? const Color(0xFF059669) : const Color(0xFFD97706));

      canvas.drawCircle(pos + const Offset(0, 1.5), 7.5, Paint()..color = Colors.black26);
      canvas.drawCircle(pos, 7.5, Paint()..color = Colors.white);
      canvas.drawCircle(pos, 5.8, Paint()..color = pinColor);

      // Chữ thập trắng nhỏ trong pin phụ
      final crossPaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.square;
      canvas.drawLine(Offset(pos.dx - 2.6, pos.dy), Offset(pos.dx + 2.6, pos.dy), crossPaint);
      canvas.drawLine(Offset(pos.dx, pos.dy - 2.6), Offset(pos.dx, pos.dy + 2.6), crossPaint);

      if (zoomLevel >= 13.5) {
        final shortName = fac.name
            .replaceAll('Trạm Y Tế ', 'TYT ')
            .replaceAll('Bệnh Viện ', 'BV ');
        _drawCrispLabel(canvas, Offset(pos.dx, pos.dy + 10), shortName, pinColor);
      }
    }
  }

  void _drawDestinationTeardropPin(Canvas canvas, Offset tipPos) {
    // Bóng đổ chân ghim
    canvas.drawOval(
      Rect.fromCenter(center: tipPos + const Offset(0, 2), width: 14, height: 5),
      Paint()..color = Colors.black.withOpacity(0.32),
    );

    // Hình giọt nước Google Maps Pin màu Đỏ Y Tế (#EA4335)
    const radius = 13.0;
    final headCenter = Offset(tipPos.dx, tipPos.dy - 20.0);
    final pinPath = Path()
      ..moveTo(tipPos.dx, tipPos.dy)
      ..quadraticBezierTo(headCenter.dx - radius, headCenter.dy + 5, headCenter.dx - radius, headCenter.dy)
      ..arcToPoint(
        Offset(headCenter.dx + radius, headCenter.dy),
        radius: const Radius.circular(radius),
        clockwise: true,
      )
      ..quadraticBezierTo(headCenter.dx + radius, headCenter.dy + 5, tipPos.dx, tipPos.dy)
      ..close();

    canvas.drawPath(pinPath, Paint()..color = const Color(0xFFEA4335));
    canvas.drawPath(
      pinPath,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    // Nền tròn trắng & Chữ thập đỏ bên trong ghim
    canvas.drawCircle(headCenter, 7.5, Paint()..color = Colors.white);
    final crossPaint = Paint()
      ..color = const Color(0xFFEA4335)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.square;
    canvas.drawLine(Offset(headCenter.dx - 4, headCenter.dy), Offset(headCenter.dx + 4, headCenter.dy), crossPaint);
    canvas.drawLine(Offset(headCenter.dx, headCenter.dy - 4), Offset(headCenter.dx, headCenter.dy + 4), crossPaint);

    // Nhãn tên cơ sở đích đến nổi sắc nét phía trên ghim
    _drawGoogleCalloutCard(
      canvas,
      Offset(tipPos.dx, tipPos.dy - 44),
      destination.name,
      const Color(0xFFDC2626),
    );
  }

  void _drawGoogleBlueUserPuck(Canvas canvas, Offset pos) {
    // Sóng lan tỏa GPS màu xanh Google (#4285F4)
    final rippleR = 11.0 + pulseValue * 20.0;
    final rippleAlpha = ((1.0 - pulseValue) * 0.35).clamp(0.0, 1.0);
    canvas.drawCircle(
      pos,
      rippleR,
      Paint()..color = const Color(0xFF4285F4).withOpacity(rippleAlpha),
    );

    // Đổ bóng chấm GPS
    canvas.drawCircle(pos + const Offset(0, 1.5), 9.5, Paint()..color = Colors.black26);
    // Viền trắng dày chuẩn Google Maps MyLocation Dot
    canvas.drawCircle(pos, 9.0, Paint()..color = Colors.white);
    // Chấm tròn xanh dương #1A73E8
    canvas.drawCircle(pos, 6.5, Paint()..color = const Color(0xFF1A73E8));
  }

  void _drawGoogleCalloutCard(Canvas canvas, Offset center, String text, Color accent) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Color(0xFF111827),
          fontWeight: FontWeight.w800,
          fontSize: 10.5,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
      maxLines: 1,
      ellipsis: '...',
    )..layout(maxWidth: 185);

    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: tp.width + 14, height: tp.height + 6),
      const Radius.circular(8),
    );
    canvas.drawRRect(rect.shift(const Offset(0, 2)), Paint()..color = Colors.black26);
    canvas.drawRRect(rect, Paint()..color = Colors.white.withOpacity(0.96));
    canvas.drawRRect(
      rect,
      Paint()
        ..color = accent.withOpacity(0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    tp.paint(canvas, Offset(rect.center.dx - tp.width / 2.0, rect.center.dy - tp.height / 2.0));
  }

  void _drawCrispLabel(Canvas canvas, Offset pos, String text, Color textColor) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: textColor,
          fontSize: 9.2,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
      maxLines: 1,
      ellipsis: '...',
    )..layout(maxWidth: 135);

    final bgRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(pos.dx, pos.dy + tp.height / 2.0),
        width: tp.width + 8,
        height: tp.height + 2,
      ),
      const Radius.circular(4),
    );
    canvas.drawRRect(bgRect, Paint()..color = Colors.white.withOpacity(0.84));
    tp.paint(canvas, Offset(pos.dx - tp.width / 2.0, pos.dy));
  }

  @override
  bool shouldRepaint(covariant _GoogleHybridSlippyMapPainter old) {
    return old.centerLat != centerLat ||
        old.centerLng != centerLng ||
        old.zoomLevel != zoomLevel ||
        old.mapStyle != mapStyle ||
        old.destination.id != destination.id ||
        old.repaintTick != repaintTick ||
        old.pulseValue != pulseValue ||
        old.route != route;
  }
}
