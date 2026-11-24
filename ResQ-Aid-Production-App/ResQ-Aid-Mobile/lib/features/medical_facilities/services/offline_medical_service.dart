import 'dart:math' as math;
import '../domain/medical_facility_model.dart';
import '../data/medical_facilities_data.dart';
import '../../../core/services/location_service.dart';
import '../../sos/data/sos_payload.dart';
import 'offline_graph_router.dart';

class OfflineMedicalService {
  static const double earthRadiusKm = 6371.0;

  /// Tính khoảng cách Haversine chuẩn xác giữa 2 điểm GPS (đơn vị: km)
  static double calculateDistanceKm(double lat1, double lon1, double lat2, double lon2) {
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);

    final rLat1 = _degreesToRadians(lat1);
    final rLat2 = _degreesToRadians(lat2);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.sin(dLon / 2) * math.sin(dLon / 2) * math.cos(rLat1) * math.cos(rLat2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  /// Tính góc phương vị la bàn (Bearing: 0° -> 360°) từ vị trí người dùng đến cơ sở y tế
  static double calculateBearing(double lat1, double lon1, double lat2, double lon2) {
    final rLat1 = _degreesToRadians(lat1);
    final rLat2 = _degreesToRadians(lat2);
    final dLon = _degreesToRadians(lon2 - lon1);

    final y = math.sin(dLon) * math.cos(rLat2);
    final x = math.cos(rLat1) * math.sin(rLat2) -
        math.sin(rLat1) * math.cos(rLat2) * math.cos(dLon);

    final radians = math.atan2(y, x);
    final degrees = (radians * 180.0 / math.pi + 360.0) % 360.0;
    return degrees;
  }

  /// Quy đổi góc Bearing sang 8 hướng la bàn Việt Nam & ký hiệu mũi tên
  static ({String direction, String arrow}) getCompassDirection(double bearing) {
    if (bearing >= 337.5 || bearing < 22.5) {
      return (direction: 'Bắc', arrow: '↑');
    } else if (bearing >= 22.5 && bearing < 67.5) {
      return (direction: 'Đông Bắc', arrow: '↗');
    } else if (bearing >= 67.5 && bearing < 112.5) {
      return (direction: 'Đông', arrow: '→');
    } else if (bearing >= 112.5 && bearing < 157.5) {
      return (direction: 'Đông Nam', arrow: '↘');
    } else if (bearing >= 157.5 && bearing < 202.5) {
      return (direction: 'Nam', arrow: '↓');
    } else if (bearing >= 202.5 && bearing < 247.5) {
      return (direction: 'Tây Nam', arrow: '↙');
    } else if (bearing >= 247.5 && bearing < 292.5) {
      return (direction: 'Tây', arrow: '←');
    } else {
      return (direction: 'Tây Bắc', arrow: '↖');
    }
  }

  /// Tra cứu danh sách trạm y tế / bệnh viện gần nhất, sắp xếp từ gần đến xa (100% Offline)
  static List<FacilityDistanceResult> findNearestFacilities({
    LocationData? userLocation,
    FacilityType? typeFilter,
    String? searchQuery,
    int limit = 50,
  }) {
    final userLat = userLocation?.lat ?? LocationService.vkuLat;
    final userLng = userLocation?.lng ?? LocationService.vkuLng;

    final queryClean = searchQuery != null ? _removeDiacritics(searchQuery.trim().toLowerCase()) : '';

    final results = <FacilityDistanceResult>[];

    for (final facility in seedMedicalFacilities) {
      // 1. Bộ lọc loại cơ sở
      if (typeFilter != null && facility.type != typeFilter) {
        continue;
      }

      // 2. Bộ lọc tìm kiếm theo từ khóa (tên, địa chỉ, quận, huyện, tỉnh)
      if (queryClean.isNotEmpty) {
        final nameClean = _removeDiacritics(facility.name.toLowerCase());
        final addressClean = _removeDiacritics(facility.address.toLowerCase());
        final districtClean = _removeDiacritics(facility.district.toLowerCase());
        final provinceClean = _removeDiacritics(facility.province.toLowerCase());
        final servicesClean = _removeDiacritics(facility.emergencyServices.join(' ').toLowerCase());

        final matched = nameClean.contains(queryClean) ||
            addressClean.contains(queryClean) ||
            districtClean.contains(queryClean) ||
            provinceClean.contains(queryClean) ||
            servicesClean.contains(queryClean);

        if (!matched) continue;
      }

      // 3. Tính toán khoảng cách & hướng la bàn ngoại tuyến
      final distanceKm = calculateDistanceKm(userLat, userLng, facility.lat, facility.lng);
      final bearing = calculateBearing(userLat, userLng, facility.lat, facility.lng);
      final compass = getCompassDirection(bearing);

      results.add(FacilityDistanceResult(
        facility: facility,
        distanceKm: distanceKm,
        bearingDeg: bearing,
        compassDirection: compass.direction,
        compassArrow: compass.arrow,
      ));
    }

    // 4. Sắp xếp từ gần nhất đến xa nhất
    results.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

    if (results.length > limit) {
      return results.sublist(0, limit);
    }
    return results;
  }

  /// Sinh văn bản chỉ đường ngoại tuyến từng bước chi tiết qua Đồ thị Đường bộ A* (A-Star)
  static String generateOfflineRouteGuide(
    FacilityDistanceResult item, {
    LocationData? userLocation,
  }) {
    final facility = item.facility;
    final startLat = userLocation?.lat ?? LocationService.vkuLat;
    final startLng = userLocation?.lng ?? LocationService.vkuLng;
    final route = OfflineGraphRouter.instance().computeRoute(
      startLat: startLat,
      startLng: startLng,
      destLat: facility.lat,
      destLng: facility.lng,
      destinationName: facility.name,
    );

    final buffer = StringBuffer();
    buffer.writeln('🧭 HƯỚNG DẪN DẪN ĐƯỜNG OFFLINE (ĐỒ THỊ A*) ĐẾN: ${facility.name.toUpperCase()}');
    buffer.writeln('• Khoảng cách giao thông ước tính: ${route.roadDistanceKm < 1.0 ? '${(route.roadDistanceKm * 1000).round()} m' : '${route.roadDistanceKm.toStringAsFixed(1)} km'} (Chim bay: ${item.formattedDistance})');
    buffer.writeln('• Hướng đi chính: ${item.compassDirection} (Góc ${item.bearingDeg.round()}° - Mũi tên: ${item.compassArrow})');
    buffer.writeln('• Địa chỉ: ${facility.address}');
    buffer.writeln('• Số điện thoại trực cấp cứu: ${facility.phone}');
    buffer.writeln();
    buffer.writeln('[CHỈ DẪN NGÃ RẼ TỪNG CHẶNG (A* ROAD GRAPH)]:');
    for (int i = 0; i < route.turnByTurnSteps.length; i++) {
      buffer.writeln('${i + 1}. ${route.turnByTurnSteps[i]}');
    }
    buffer.writeln();
    buffer.writeln('[LƯU Ý CẤP CỨU]: Hãy bấm nút Gọi điện để báo trước tình trạng nạn nhân cho kíp trực trong lúc di chuyển.');
    return buffer.toString().trim();
  }

  static double _degreesToRadians(double degrees) {
    return degrees * math.pi / 180.0;
  }

  static String _removeDiacritics(String str) {
    const withDia = 'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴÈÉẸẺẼÊỀẾỆỂỄÌÍỊỈĨÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠÙÚỤỦŨƯỪỨỰỬỮỲÝỴỶỸĐ';
    const withoutDia = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyydAAAAAAAAAAAAAAAAAEEEEEEEEEEEIIIIIOOOOOOOOOOOOOOOOOUUUUUUUUUUUYYYYYD';
    var result = str;
    for (int i = 0; i < withDia.length; i++) {
      result = result.replaceAll(withDia[i], withoutDia[i]);
    }
    return result;
  }
}
