import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resq_aid/core/services/location_service.dart';
import 'package:resq_aid/core/services/medical_dialogue_brain.dart';
import 'package:resq_aid/features/medical_facilities/domain/medical_facility_model.dart';
import 'package:resq_aid/features/medical_facilities/services/hybrid_google_map_service.dart';
import 'package:resq_aid/features/medical_facilities/services/offline_medical_service.dart';
import 'package:resq_aid/features/medical_facilities/presentation/nearest_medical_facility_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Medical Facility Navigation & 100% Offline Medical Directory Tests', () {
    test('1. LocationService.openNearestMedicalMap returns true in FLUTTER_TEST mode', () async {
      final result = await LocationService.openNearestMedicalMap(query: 'trạm y tế bệnh viện gần nhất');
      expect(result, isTrue);
    });

    test('2. Offline Haversine Distance & Compass Bearing Calculation', () {
      // VKU: 15.9752, 108.2523
      // Trạm Y Tế Hòa Quý: 15.9815, 108.2435
      final distKm = OfflineMedicalService.calculateDistanceKm(15.9752, 108.2523, 15.9815, 108.2435);
      expect(distKm, greaterThan(0.9));
      expect(distKm, lessThan(1.5));

      final bearing = OfflineMedicalService.calculateBearing(15.9752, 108.2523, 15.9815, 108.2435);
      expect(bearing, greaterThan(270.0));
      expect(bearing, lessThan(360.0));

      final compass = OfflineMedicalService.getCompassDirection(bearing);
      expect(compass.direction, equals('Tây Bắc'));
      expect(compass.arrow, equals('↖'));
    });

    test('3. OfflineMedicalService.findNearestFacilities sorts by nearest distance', () {
      final results = OfflineMedicalService.findNearestFacilities();
      expect(results, isNotEmpty);

      // Trạm Hòa Quý hoặc Hòa Hải phải nằm trong top đầu vì gần VKU nhất (< 2.5km)
      final top1 = results.first;
      expect(top1.distanceKm, lessThan(2.5));
      expect(top1.facility.province, equals('Đà Nẵng'));

      // Kiểm tra tính đơn điệu tăng dần của khoảng cách (sorted ascending)
      for (int i = 0; i < results.length - 1; i++) {
        expect(results[i].distanceKm, lessThanOrEqualTo(results[i + 1].distanceKm));
      }
    });

    test('4. Filter by FacilityType & Offline Search Keyword', () {
      // Lọc Bệnh viện
      final hospitals = OfflineMedicalService.findNearestFacilities(typeFilter: FacilityType.hospital);
      expect(hospitals.every((r) => r.facility.type == FacilityType.hospital), isTrue);

      // Lọc Trạm Y Tế
      final clinics = OfflineMedicalService.findNearestFacilities(typeFilter: FacilityType.clinic);
      expect(clinics.every((r) => r.facility.type == FacilityType.clinic), isTrue);

      // Tìm kiếm từ khóa không dấu "hoa quy"
      final searchResults = OfflineMedicalService.findNearestFacilities(searchQuery: 'hoa quy');
      expect(searchResults, isNotEmpty);
      expect(searchResults.first.facility.name, contains('Hòa Quý'));
    });

    test('5. Offline route guidance text generation', () {
      final results = OfflineMedicalService.findNearestFacilities();
      final guide = OfflineMedicalService.generateOfflineRouteGuide(results.first);

      expect(guide, contains('HƯỚNG DẪN DẪN ĐƯỜNG OFFLINE'));
      expect(guide, contains('Khoảng cách'));
      expect(guide, contains('Hướng đi chính'));
      expect(guide, contains('Số điện thoại'));
    });

    test('6. MedicalDialogueBrain detects medical facility intent and gives offline nearest station', () {
      expect(MedicalDialogueBrain.isSeekingMedicalFacility('tim tram y te gan nhat'), isTrue);
      expect(MedicalDialogueBrain.isSeekingMedicalFacility('chi duong den benh vien gan nhat'), isTrue);
      expect(MedicalDialogueBrain.isSeekingMedicalFacility('tim tram xa gan nhat'), isTrue);
      expect(MedicalDialogueBrain.isSeekingMedicalFacility('benh vien o dau gan day'), isTrue);
      expect(MedicalDialogueBrain.isSeekingMedicalFacility('tim nha thuoc gan nhat'), isTrue);
      expect(MedicalDialogueBrain.isSeekingMedicalFacility('mo google map tim vien cap cuu'), isTrue);
      expect(MedicalDialogueBrain.isSeekingMedicalFacility('tram y te phuong o dau'), isTrue);

      // Negative cases: should not trigger navigation
      expect(MedicalDialogueBrain.isSeekingMedicalFacility('toi bi dut tay'), isFalse);
      expect(MedicalDialogueBrain.isSeekingMedicalFacility('huong dan ep tim cpr'), isFalse);
      expect(MedicalDialogueBrain.isSeekingMedicalFacility('chao bac si'), isFalse);

      final brain = MedicalDialogueBrain();
      brain.reset();

      final response = brain.processQuery('tìm trạm y tế gần nhất');
      expect(response, contains('trạm y tế'));
      expect(response, contains('Gần bạn nhất'));
      expect(response, contains('Gọi 115'));
    });

    testWidgets('7. NearestMedicalFacilityScreen renders correctly with offline badges and filters', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: NearestMedicalFacilityScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('TRẠM Y TẾ & BỆNH VIỆN'), findsOneWidget);
      expect(find.text('100% NGOẠI TUYẾN • KHÔNG CẦN 4G'), findsOneWidget);
      expect(find.text('GỌI 115'), findsOneWidget);
      expect(find.text('Tất cả'), findsOneWidget);
      expect(find.text('Trạm Y tế'), findsOneWidget);
      expect(find.text('Bệnh viện'), findsOneWidget);

      // Ít nhất có 1 nút CHỈ ĐƯỜNG và GỌI
      expect(find.text('CHỈ ĐƯỜNG'), findsWidgets);
    });

    test('8. Web Mercator EPSG:3857 Slippy-Tile Projection & Hybrid Route Engine accuracy', () async {
      const testLat = 15.9752;
      const testLng = 108.2523;
      const z = 15.0;

      final wx = HybridGoogleMapService.lngToWorldX(testLng, z);
      final wy = HybridGoogleMapService.latToWorldY(testLat, z);

      expect(HybridGoogleMapService.worldXToLng(wx, z), closeTo(testLng, 1e-6));
      expect(HybridGoogleMapService.worldYToLat(wy, z), closeTo(testLat, 1e-6));

      final optZoom = HybridGoogleMapService.optimalZoomForBounds(
        lat1: 15.9752,
        lng1: 108.2523,
        lat2: 15.9815,
        lng2: 108.2435,
        widthPx: 360,
        heightPx: 270,
      );
      expect(optZoom, greaterThanOrEqualTo(12.0));
      expect(optZoom, lessThanOrEqualTo(16.5));

      final navOk = await LocationService.openGoogleMapsTurnByTurn(
        destLat: 15.9815,
        destLng: 108.2435,
        destName: 'Trạm Y Tế Phường Hòa Quý',
      );
      expect(navOk, isTrue);

      final route = await HybridGoogleMapService.instance.computeHybridRoute(
        startLat: 15.9752,
        startLng: 108.2523,
        destLat: 15.9815,
        destLng: 108.2435,
        destinationName: 'Trạm Y Tế Phường Hòa Quý',
      );
      expect(route.waypoints.length, greaterThanOrEqualTo(2));
      expect(route.turnByTurnSteps, isNotEmpty);
    });

    testWidgets('9. Hybrid Google Map View renders layers, zoom controls and GG Maps 3D button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: NearestMedicalFacilityScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Bản Đồ Google Hybrid'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Đường phố'), findsOneWidget);
      expect(find.text('GG Maps 3D'), findsOneWidget);
      expect(find.text('Lưu Offline 4km'), findsOneWidget);

      // Bấm chuyển lớp bản đồ sang Vệ tinh
      await tester.tap(find.text('Đường phố'));
      await tester.pump();
      expect(find.text('Vệ tinh'), findsOneWidget);
    });
  });
}
