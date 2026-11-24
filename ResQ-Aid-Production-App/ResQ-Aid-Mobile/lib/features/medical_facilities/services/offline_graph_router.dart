import 'dart:math' as math;
import '../data/offline_map_roads.dart';
import 'offline_medical_service.dart';

class RoadGraphNode {
  final int id;
  final double lat;
  final double lng;
  final Set<String> roadNames;

  RoadGraphNode({
    required this.id,
    required this.lat,
    required this.lng,
    required this.roadNames,
  });
}

class RoadGraphEdge {
  final int toNodeId;
  final double distanceKm;
  final double cost;
  final String roadName;
  final bool isHighway;

  const RoadGraphEdge({
    required this.toNodeId,
    required this.distanceKm,
    required this.cost,
    required this.roadName,
    required this.isHighway,
  });
}

class OfflineRouteSolution {
  final List<({double lat, double lng})> waypoints;
  final double roadDistanceKm;
  final List<String> turnByTurnSteps;
  final bool isGraphRouted;

  const OfflineRouteSolution({
    required this.waypoints,
    required this.roadDistanceKm,
    required this.turnByTurnSteps,
    required this.isGraphRouted,
  });
}

/// Động cơ Định tuyến Đồ thị Đường bộ Ngoại tuyến sử dụng Thuật toán A* (A-Star)
/// Xây dựng đồ thị liên thông từ mạng lưới vector đường bộ và tìm đường đi ngắn nhất theo mặt đường thật.
class OfflineGraphRouter {
  static OfflineGraphRouter? _cachedInstance;

  final List<RoadGraphNode> nodes;
  final Map<int, List<RoadGraphEdge>> adjacency;

  OfflineGraphRouter._({required this.nodes, required this.adjacency});

  factory OfflineGraphRouter.instance() {
    return _cachedInstance ??= _buildFromSeedRoads(seedOfflineRoads);
  }

  static OfflineGraphRouter _buildFromSeedRoads(List<OfflineRoad> roads) {
    final nodes = <RoadGraphNode>[];
    final adj = <int, List<RoadGraphEdge>>{};

    // Subdivide long segments (~250m intervals) and merge intersections within 220m
    const mergeThresholdKm = 0.22;

    int getOrCreateNode(double lat, double lng, String roadName) {
      for (final existing in nodes) {
        final d = OfflineMedicalService.calculateDistanceKm(lat, lng, existing.lat, existing.lng);
        if (d <= mergeThresholdKm) {
          existing.roadNames.add(roadName);
          return existing.id;
        }
      }
      final id = nodes.length;
      nodes.add(RoadGraphNode(id: id, lat: lat, lng: lng, roadNames: {roadName}));
      adj[id] = [];
      return id;
    }

    void addBidirectionalEdge(int u, int v, String roadName, bool isHighway) {
      if (u == v) return;
      final dist = OfflineMedicalService.calculateDistanceKm(
        nodes[u].lat,
        nodes[u].lng,
        nodes[v].lat,
        nodes[v].lng,
      );
      final weightFactor = isHighway ? 0.88 : 1.0;
      final cost = dist * weightFactor;

      final uList = adj[u]!;
      if (!uList.any((e) => e.toNodeId == v)) {
        uList.add(RoadGraphEdge(
          toNodeId: v,
          distanceKm: dist,
          cost: cost,
          roadName: roadName,
          isHighway: isHighway,
        ));
      }

      final vList = adj[v]!;
      if (!vList.any((e) => e.toNodeId == u)) {
        vList.add(RoadGraphEdge(
          toNodeId: u,
          distanceKm: dist,
          cost: cost,
          roadName: roadName,
          isHighway: isHighway,
        ));
      }
    }

    for (final road in roads) {
      if (road.coords.length < 2) continue;
      for (int i = 0; i < road.coords.length - 1; i++) {
        final p1 = road.coords[i];
        final p2 = road.coords[i + 1];
        final segDist = OfflineMedicalService.calculateDistanceKm(p1.lat, p1.lng, p2.lat, p2.lng);
        final steps = math.max(1, (segDist / 0.25).ceil());

        int prevId = getOrCreateNode(p1.lat, p1.lng, road.name);
        for (int s = 1; s <= steps; s++) {
          final t = s / steps;
          final lat = p1.lat + (p2.lat - p1.lat) * t;
          final lng = p1.lng + (p2.lng - p1.lng) * t;
          final curId = getOrCreateNode(lat, lng, road.name);
          addBidirectionalEdge(prevId, curId, road.name, road.isHighway);
          prevId = curId;
        }
      }
    }

    // Bridge nearby arterial corridors within 650m so cross-district routing stays connected
    for (int i = 0; i < nodes.length; i++) {
      for (int j = i + 1; j < nodes.length; j++) {
        if (nodes[i].roadNames.intersection(nodes[j].roadNames).isNotEmpty) continue;
        final d = OfflineMedicalService.calculateDistanceKm(
          nodes[i].lat,
          nodes[i].lng,
          nodes[j].lat,
          nodes[j].lng,
        );
        if (d <= 0.65) {
          addBidirectionalEdge(i, j, 'Đường nối liên khu vực', false);
        }
      }
    }

    return OfflineGraphRouter._(nodes: nodes, adjacency: adj);
  }

  ({int nodeId, double snapDistKm})? _findNearestNode(double lat, double lng) {
    if (nodes.isEmpty) return null;
    int bestId = 0;
    double bestDist = double.infinity;
    for (final node in nodes) {
      final d = OfflineMedicalService.calculateDistanceKm(lat, lng, node.lat, node.lng);
      if (d < bestDist) {
        bestDist = d;
        bestId = node.id;
      }
    }
    return (nodeId: bestId, snapDistKm: bestDist);
  }

  /// Giải bài toán đường đi ngắn nhất A* từ tọa độ GPS người dùng tới Cơ sở Y tế
  OfflineRouteSolution computeRoute({
    required double startLat,
    required double startLng,
    required double destLat,
    required double destLng,
    required String destinationName,
  }) {
    final directKm = OfflineMedicalService.calculateDistanceKm(startLat, startLng, destLat, destLng);
    final startSnap = _findNearestNode(startLat, startLng);
    final goalSnap = _findNearestNode(destLat, destLng);

    // Nếu người dùng ở tỉnh/thành ngoài vùng đồ thị chi tiết (> 8km tới nút đường gần nhất),
    // chuyển sang định tuyến hành lang trực tiếp
    if (startSnap == null || goalSnap == null || startSnap.snapDistKm > 8.0 || goalSnap.snapDistKm > 8.0) {
      final bearing = OfflineMedicalService.calculateBearing(startLat, startLng, destLat, destLng);
      final compass = OfflineMedicalService.getCompassDirection(bearing);
      return OfflineRouteSolution(
        waypoints: [
          (lat: startLat, lng: startLng),
          (lat: destLat, lng: destLng),
        ],
        roadDistanceKm: directKm,
        turnByTurnSteps: [
          'Định hướng ${compass.arrow} ${compass.direction} (${bearing.round()}°) tiến về $destinationName.',
          'Quãng đường ước tính ${directKm.toStringAsFixed(1)} km theo trục giao thông chính.',
        ],
        isGraphRouted: false,
      );
    }

    final startId = startSnap.nodeId;
    final goalId = goalSnap.nodeId;

    if (startId == goalId) {
      final roadLabel = nodes[startId].roadNames.first;
      return OfflineRouteSolution(
        waypoints: [
          (lat: startLat, lng: startLng),
          (lat: nodes[startId].lat, lng: nodes[startId].lng),
          (lat: destLat, lng: destLng),
        ],
        roadDistanceKm: directKm,
        turnByTurnSteps: [
          'Đi ra trục $roadLabel ngay gần bạn.',
          'Di chuyển khoảng ${(directKm * 1000).round()} m tới $destinationName.',
        ],
        isGraphRouted: true,
      );
    }

    // A* Search
    final openSet = <int>{startId};
    final cameFrom = <int, int>{};
    final cameViaRoad = <int, String>{};
    final gScore = <int, double>{startId: 0.0};
    final fScore = <int, double>{
      startId: 0.85 *
          OfflineMedicalService.calculateDistanceKm(
            nodes[startId].lat,
            nodes[startId].lng,
            nodes[goalId].lat,
            nodes[goalId].lng,
          ),
    };

    while (openSet.isNotEmpty) {
      int current = openSet.first;
      double bestF = fScore[current] ?? double.infinity;
      for (final candidate in openSet) {
        final cf = fScore[candidate] ?? double.infinity;
        if (cf < bestF) {
          bestF = cf;
          current = candidate;
        }
      }

      if (current == goalId) {
        return _reconstructSolution(
          startLat: startLat,
          startLng: startLng,
          destLat: destLat,
          destLng: destLng,
          destinationName: destinationName,
          goalId: goalId,
          cameFrom: cameFrom,
          cameViaRoad: cameViaRoad,
          startSnapKm: startSnap.snapDistKm,
          goalSnapKm: goalSnap.snapDistKm,
        );
      }

      openSet.remove(current);
      final currentG = gScore[current] ?? double.infinity;

      for (final edge in adjacency[current] ?? const <RoadGraphEdge>[]) {
        final tentativeG = currentG + edge.cost;
        if (tentativeG < (gScore[edge.toNodeId] ?? double.infinity)) {
          cameFrom[edge.toNodeId] = current;
          cameViaRoad[edge.toNodeId] = edge.roadName;
          gScore[edge.toNodeId] = tentativeG;
          final h = 0.85 *
              OfflineMedicalService.calculateDistanceKm(
                nodes[edge.toNodeId].lat,
                nodes[edge.toNodeId].lng,
                nodes[goalId].lat,
                nodes[goalId].lng,
              );
          fScore[edge.toNodeId] = tentativeG + h;
          openSet.add(edge.toNodeId);
        }
      }
    }

    // Fallback nếu thuộc 2 thành phần đồ thị rời nhau
    final bearing = OfflineMedicalService.calculateBearing(startLat, startLng, destLat, destLng);
    final compass = OfflineMedicalService.getCompassDirection(bearing);
    return OfflineRouteSolution(
      waypoints: [
        (lat: startLat, lng: startLng),
        (lat: nodes[startId].lat, lng: nodes[startId].lng),
        (lat: nodes[goalId].lat, lng: nodes[goalId].lng),
        (lat: destLat, lng: destLng),
      ],
      roadDistanceKm: directKm * 1.15,
      turnByTurnSteps: [
        'Tiến ra ${nodes[startId].roadNames.first}, đi hướng ${compass.direction}.',
        'Tiếp cận khu vực ${nodes[goalId].roadNames.first} để vào $destinationName.',
      ],
      isGraphRouted: true,
    );
  }

  OfflineRouteSolution _reconstructSolution({
    required double startLat,
    required double startLng,
    required double destLat,
    required double destLng,
    required String destinationName,
    required int goalId,
    required Map<int, int> cameFrom,
    required Map<int, String> cameViaRoad,
    required double startSnapKm,
    required double goalSnapKm,
  }) {
    final nodePath = <int>[goalId];
    final roadSegments = <String>[];
    int cur = goalId;
    while (cameFrom.containsKey(cur)) {
      roadSegments.add(cameViaRoad[cur] ?? 'Đường nội bộ');
      cur = cameFrom[cur]!;
      nodePath.add(cur);
    }

    final orderedNodes = nodePath.reversed.toList();
    final orderedRoads = roadSegments.reversed.toList();

    final waypoints = <({double lat, double lng})>[
      (lat: startLat, lng: startLng),
      for (final nid in orderedNodes) (lat: nodes[nid].lat, lng: nodes[nid].lng),
      (lat: destLat, lng: destLng),
    ];

    double totalDistKm = startSnapKm + goalSnapKm;
    for (int i = 0; i < orderedNodes.length - 1; i++) {
      final a = nodes[orderedNodes[i]];
      final b = nodes[orderedNodes[i + 1]];
      totalDistKm += OfflineMedicalService.calculateDistanceKm(a.lat, a.lng, b.lat, b.lng);
    }

    // Tổng hợp hướng dẫn rẽ theo từng chặng đường và góc chuyển hướng
    final steps = <String>[];
    if (orderedRoads.isNotEmpty) {
      String activeRoad = orderedRoads.first;
      double segKm = startSnapKm;
      int segStartNodeIdx = 0;

      for (int i = 0; i < orderedRoads.length; i++) {
        final a = nodes[orderedNodes[i]];
        final b = nodes[orderedNodes[i + 1]];
        final d = OfflineMedicalService.calculateDistanceKm(a.lat, a.lng, b.lat, b.lng);

        if (orderedRoads[i] == activeRoad) {
          segKm += d;
        } else {
          final distLabel = segKm < 1.0 ? '${(segKm * 1000).round()} m' : '${segKm.toStringAsFixed(1)} km';
          if (steps.isEmpty) {
            steps.add('Đi theo $activeRoad khoảng $distLabel.');
          } else {
            final turnVerb = _computeTurnVerb(orderedNodes, segStartNodeIdx, i);
            steps.add('$turnVerb vào $activeRoad, đi tiếp $distLabel.');
          }
          activeRoad = orderedRoads[i];
          segKm = d;
          segStartNodeIdx = i;
        }
      }

      final lastDistLabel = segKm < 1.0 ? '${(segKm * 1000).round()} m' : '${segKm.toStringAsFixed(1)} km';
      if (steps.isEmpty) {
        steps.add('Đi thẳng theo $activeRoad khoảng $lastDistLabel.');
      } else {
        final turnVerb = _computeTurnVerb(orderedNodes, segStartNodeIdx, orderedRoads.length - 1);
        steps.add('$turnVerb vào $activeRoad ($lastDistLabel).');
      }
    }

    steps.add('Đến đích: $destinationName.');

    return OfflineRouteSolution(
      waypoints: waypoints,
      roadDistanceKm: totalDistKm,
      turnByTurnSteps: steps,
      isGraphRouted: true,
    );
  }

  String _computeTurnVerb(List<int> path, int prevStartIdx, int pivotIdx) {
    if (pivotIdx <= 0 || pivotIdx + 1 >= path.length) return 'Chuyển hướng';
    final pPrev = nodes[path[math.max(0, pivotIdx - 1)]];
    final pCur = nodes[path[pivotIdx]];
    final pNext = nodes[path[pivotIdx + 1]];

    final b1 = OfflineMedicalService.calculateBearing(pPrev.lat, pPrev.lng, pCur.lat, pCur.lng);
    final b2 = OfflineMedicalService.calculateBearing(pCur.lat, pCur.lng, pNext.lat, pNext.lng);
    double diff = (b2 - b1 + 540.0) % 360.0 - 180.0; // [-180, 180]

    if (diff > 28) return 'Rẽ phải';
    if (diff < -28) return 'Rẽ trái';
    return 'Đi tiếp';
  }
}
