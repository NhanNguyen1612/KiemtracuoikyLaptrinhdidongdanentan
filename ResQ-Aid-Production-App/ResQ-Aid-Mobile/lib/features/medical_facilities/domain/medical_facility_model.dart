enum FacilityType {
  hospital, // Bệnh viện
  clinic, // Trạm y tế / Trạm xá phường xã
  emergencyCenter, // Trung tâm Cấp cứu 115
  pharmacy, // Nhà thuốc
}

class MedicalFacility {
  final String id;
  final String name;
  final FacilityType type;
  final String address;
  final String phone;
  final double lat;
  final double lng;
  final String level; // "Tuyến Trung ương", "Tuyến Tỉnh / Thành phố", "Tuyến Quận / Huyện", "Tuyến Phường / Xã"
  final bool is24_7;
  final List<String> emergencyServices;
  final String province;
  final String district;

  const MedicalFacility({
    required this.id,
    required this.name,
    required this.type,
    required this.address,
    required this.phone,
    required this.lat,
    required this.lng,
    required this.level,
    this.is24_7 = true,
    this.emergencyServices = const [],
    required this.province,
    required this.district,
  });

  String get typeLabel {
    switch (type) {
      case FacilityType.hospital:
        return 'Bệnh viện';
      case FacilityType.clinic:
        return 'Trạm Y Tế / Trạm Xá';
      case FacilityType.emergencyCenter:
        return 'Cấp cứu 115';
      case FacilityType.pharmacy:
        return 'Nhà thuốc';
    }
  }
}

class FacilityDistanceResult {
  final MedicalFacility facility;
  final double distanceKm;
  final double bearingDeg;
  final String compassDirection; // "Đông Bắc", "Bắc", "Tây Bắc", v.v.
  final String compassArrow; // "↗", "↑", "↖", v.v.

  const FacilityDistanceResult({
    required this.facility,
    required this.distanceKm,
    required this.bearingDeg,
    required this.compassDirection,
    required this.compassArrow,
  });

  String get formattedDistance {
    if (distanceKm < 1.0) {
      final meters = (distanceKm * 1000).round();
      return '$meters m';
    }
    return '${distanceKm.toStringAsFixed(1)} km';
  }

  String get navigationSummary {
    return 'Đi theo hướng $compassDirection ($compassArrow) khoảng $formattedDistance';
  }
}
