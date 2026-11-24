class OfflineRoad {
  final String name;
  final List<({double lat, double lng})> coords;
  final bool isHighway;

  const OfflineRoad({
    required this.name,
    required this.coords,
    this.isHighway = false,
  });
}

class OfflineWaterway {
  final String name;
  final List<({double lat, double lng})> coords;

  const OfflineWaterway({
    required this.name,
    required this.coords,
  });
}

// Mạng lưới đường bộ & sông ngòi chính tích hợp sẵn ngoại tuyến
const List<OfflineRoad> seedOfflineRoads = [
  // --- KHU VỰC NGŨ HÀNH SƠN & VKU (ĐÀ NẴNG) ---
  OfflineRoad(
    name: 'Đ. Nam Kỳ Khởi Nghĩa',
    isHighway: true,
    coords: [
      (lat: 15.9750, lng: 108.2250),
      (lat: 15.9770, lng: 108.2380),
      (lat: 15.9785, lng: 108.2480),
      (lat: 15.9805, lng: 108.2520), // Trước cổng VKU
      (lat: 15.9830, lng: 108.2680), // Ra bãi biển Tân Trà
    ],
  ),
  OfflineRoad(
    name: 'Đ. Trần Đại Nghĩa (ĐT607)',
    isHighway: true,
    coords: [
      (lat: 15.9400, lng: 108.2580),
      (lat: 15.9600, lng: 108.2550),
      (lat: 15.9752, lng: 108.2523), // VKU
      (lat: 15.9900, lng: 108.2500),
      (lat: 16.0100, lng: 108.2470),
    ],
  ),
  OfflineRoad(
    name: 'Đ. Lê Văn Hiến',
    isHighway: true,
    coords: [
      (lat: 16.0100, lng: 108.2470), // TTYT Ngũ Hành Sơn
      (lat: 16.0315, lng: 108.2452), // BV Phụ Sản - Nhi
      (lat: 16.0500, lng: 108.2410),
    ],
  ),
  OfflineRoad(
    name: 'Đ. Lưu Quang Vũ',
    isHighway: false,
    coords: [
      (lat: 15.9760, lng: 108.2420),
      (lat: 15.9815, lng: 108.2435), // Trạm Y Tế Hòa Quý
      (lat: 15.9870, lng: 108.2445),
    ],
  ),
  OfflineRoad(
    name: 'Đ. Mai Đăng Chơn',
    isHighway: false,
    coords: [
      (lat: 15.9650, lng: 108.2390),
      (lat: 15.9800, lng: 108.2410),
      (lat: 15.9950, lng: 108.2430),
    ],
  ),
  OfflineRoad(
    name: 'Đ. Võ Chí Công (Cầu Khuê Đông)',
    isHighway: true,
    coords: [
      (lat: 15.9850, lng: 108.2250),
      (lat: 16.0050, lng: 108.2200),
      (lat: 16.0250, lng: 108.2140),
    ],
  ),
  OfflineRoad(
    name: 'Đ. Trường Sa - Võ Nguyên Giáp (Ven biển)',
    isHighway: true,
    coords: [
      (lat: 15.9800, lng: 108.2700),
      (lat: 16.0200, lng: 108.2580),
      (lat: 16.0600, lng: 108.2480),
    ],
  ),

  // --- TRUNG TÂM ĐÀ NẴNG (HẢI CHÂU - THANH KHÊ) ---
  OfflineRoad(
    name: 'Đ. Hải Phòng (Khu BV Đà Nẵng & BV C)',
    isHighway: false,
    coords: [
      (lat: 16.0710, lng: 108.2100),
      (lat: 16.0735, lng: 108.2148), // BV Đà Nẵng & C
      (lat: 16.0760, lng: 108.2200),
    ],
  ),
  OfflineRoad(
    name: 'Đ. Nguyễn Văn Linh (Cầu Rồng)',
    isHighway: true,
    coords: [
      (lat: 16.0620, lng: 108.2000),
      (lat: 16.0600, lng: 108.2150),
      (lat: 16.0590, lng: 108.2230),
      (lat: 16.0585, lng: 108.2320),
    ],
  ),
  OfflineRoad(
    name: 'Đ. Bạch Đằng (Ven Sông Hàn)',
    isHighway: false,
    coords: [
      (lat: 16.0500, lng: 108.2230),
      (lat: 16.0650, lng: 108.2235),
      (lat: 16.0780, lng: 108.2220),
    ],
  ),
  OfflineRoad(
    name: 'Đ. Quang Trung',
    isHighway: false,
    coords: [
      (lat: 16.0730, lng: 108.2120),
      (lat: 16.0762, lng: 108.2178), // TYT Thạch Thang
      (lat: 16.0780, lng: 108.2230),
    ],
  ),
  OfflineRoad(
    name: 'Đ. 30 Tháng 4',
    isHighway: false,
    coords: [
      (lat: 16.0350, lng: 108.2150),
      (lat: 16.0421, lng: 108.2145), // TYT Hòa Cường Bắc
      (lat: 16.0480, lng: 108.2140),
    ],
  ),

  // --- KHU VỰC QUẢNG NAM (ĐIỆN BÀN - HỘI AN) ---
  OfflineRoad(
    name: 'QL1A - Vĩnh Điện',
    isHighway: true,
    coords: [
      (lat: 15.8800, lng: 108.2480),
      (lat: 15.9100, lng: 108.2520),
      (lat: 15.9400, lng: 108.2580),
    ],
  ),
  OfflineRoad(
    name: 'Đ. Hai Bà Trưng (Hội An)',
    isHighway: false,
    coords: [
      (lat: 15.8780, lng: 108.3260),
      (lat: 15.8920, lng: 108.3310),
      (lat: 15.9150, lng: 108.3380),
    ],
  ),

  // --- KHU VỰC HÀ NỘI (HOÀN KIẾM - HAI BÀ TRƯNG - ĐỐNG ĐA) ---
  OfflineRoad(
    name: 'Đ. Giải Phóng - Lê Duẩn',
    isHighway: true,
    coords: [
      (lat: 20.9980, lng: 105.8415), // BV Bạch Mai
      (lat: 21.0120, lng: 105.8425),
      (lat: 21.0260, lng: 105.8440),
    ],
  ),
  OfflineRoad(
    name: 'Phố Tràng Thi - Trần Hưng Đạo',
    isHighway: true,
    coords: [
      (lat: 21.0260, lng: 105.8440),
      (lat: 21.0298, lng: 105.8485), // BV Việt Đức
      (lat: 21.0245, lng: 105.8567), // Tràng Tiền
      (lat: 21.0185, lng: 105.8601), // BV TWQĐ 108
    ],
  ),

  // --- KHU VỰC TP. HỒ CHÍ MINH (QUẬN 1 - QUẬN 5 - QUẬN 10) ---
  OfflineRoad(
    name: 'Đ. Nguyễn Chí Thanh - Lý Thường Kiệt',
    isHighway: true,
    coords: [
      (lat: 10.7578, lng: 106.6598), // BV Chợ Rẫy
      (lat: 10.7650, lng: 106.6592),
      (lat: 10.7712, lng: 106.6589), // BV Trưng Vương
    ],
  ),
  OfflineRoad(
    name: 'Đ. Sư Vạn Hạnh - Nguyễn Thị Minh Khai',
    isHighway: true,
    coords: [
      (lat: 10.7650, lng: 106.6592),
      (lat: 10.7745, lng: 106.6621), // BV Nhân Dân 115
      (lat: 10.7768, lng: 106.6850),
      (lat: 10.7789, lng: 106.7034), // Bến Nghé Quận 1
    ],
  ),
];

// Hệ thống sông ngòi mặt nước nhận diện địa hình
const List<OfflineWaterway> seedOfflineWaterways = [
  OfflineWaterway(
    name: 'Sông Cổ Cò',
    coords: [
      (lat: 15.9550, lng: 108.2480),
      (lat: 15.9680, lng: 108.2465),
      (lat: 15.9810, lng: 108.2480),
      (lat: 15.9950, lng: 108.2490),
      (lat: 16.0150, lng: 108.2430),
    ],
  ),
  OfflineWaterway(
    name: 'Sông Hàn',
    coords: [
      (lat: 16.0350, lng: 108.2250),
      (lat: 16.0550, lng: 108.2240),
      (lat: 16.0750, lng: 108.2230),
      (lat: 16.0900, lng: 108.2200),
    ],
  ),
];
