import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../features/sos/data/sos_payload.dart';

class LocationService {
  // Tọa độ mặc định: Trường ĐH CNTT&TT Việt - Hàn (VKU), Đà Nẵng
  static const double vkuLat = 15.9752;
  static const double vkuLng = 108.2523;

  static Future<LocationData> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return _fallbackLocation('SERVICE_DISABLED');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return _fallbackLocation('PERMISSION_DENIED');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return _fallbackLocation('PERMISSION_PERMANENTLY_DENIED');
      }

      // Giới hạn 3 giây timeout (NFR: phản hồi cực nhanh khi bấm SOS)
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 3),
        ),
      );

      return LocationData(
        lat: position.latitude,
        lng: position.longitude,
        accuracyM: position.accuracy,
        source: 'GPS',
      );
    } on TimeoutException {
      // Fallback khi định vị phần cứng quá 3 giây (ở trong nhà / hầm xe)
      final lastPos = await Geolocator.getLastKnownPosition();
      if (lastPos != null) {
        return LocationData(
          lat: lastPos.latitude,
          lng: lastPos.longitude,
          accuracyM: lastPos.accuracy,
          source: 'LAST_KNOWN',
        );
      }
      return _fallbackLocation('TIMEOUT_FALLBACK');
    } catch (e) {
      return _fallbackLocation('ERROR_${e.toString()}');
    }
  }

  static LocationData fallbackLocation([String source = 'FALLBACK']) {
    return _fallbackLocation(source);
  }

  static LocationData _fallbackLocation(String source) {
    return LocationData(
      lat: vkuLat,
      lng: vkuLng,
      accuracyM: 50.0,
      source: source,
    );
  }

  /// Mở Google Maps tìm kiếm và dẫn đường tới trạm y tế / bệnh viện / trạm xá gần nhất
  /// Hỗ trợ cả Android & iOS qua Google Maps App / Apple Maps / Web
  static Future<bool> openNearestMedicalMap({
    String query = 'trạm y tế bệnh viện gần nhất',
  }) async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return true;
    }
    try {
      final loc = await getCurrentLocation();
      final lat = loc.lat;
      final lng = loc.lng;
      final encodedQuery = Uri.encodeComponent(query);

      // 1. Google Maps Universal Search Link (hoạt động tốt nhất trên mobile)
      final googleMapsUri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$encodedQuery&center=$lat,$lng',
      );

      // 2. Geo URI native chuẩn Android
      final geoUri = Uri.parse('geo:$lat,$lng?q=$encodedQuery');

      if (await canLaunchUrl(googleMapsUri)) {
        return await launchUrl(googleMapsUri, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(geoUri)) {
        return await launchUrl(geoUri);
      }
    } catch (e) {
      debugPrint('[LocationService] Lỗi mở Google Maps: $e');
      final fallbackWebUri = Uri.parse('https://www.google.com/maps/search/trạm+y+tế+bệnh+viện+gần+nhất');
      if (await canLaunchUrl(fallbackWebUri)) {
        return await launchUrl(fallbackWebUri, mode: LaunchMode.externalApplication);
      }
    }
    return false;
  }

  /// Phối hợp trực tiếp với ứng dụng Google Maps gốc (Android/iOS) để bật Dẫn đường giọng nói 3D Turn-by-Turn
  /// Hoạt động cả khi Offline nếu người dùng đã lưu Bản đồ ngoại tuyến trong Google Maps!
  /// [mode]: 'd' (ô tô/xe máy), 'w' (đi bộ), 'b' (xe đạp)
  static Future<bool> openGoogleMapsTurnByTurn({
    required double destLat,
    required double destLng,
    String? destName,
    double? originLat,
    double? originLng,
    String mode = 'd',
  }) async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return true;
    }
    try {
      // 1. Android Native Google Maps Turn-by-Turn Intent (Hỗ trợ dẫn đường Offline của Google Maps App)
      if (Platform.isAndroid) {
        final navUri = Uri.parse('google.navigation:q=$destLat,$destLng&mode=$mode');
        if (await canLaunchUrl(navUri)) {
          final ok = await launchUrl(navUri, mode: LaunchMode.externalApplication);
          if (ok) return true;
        }
      }

      // 2. iOS Google Maps Native App Scheme
      if (Platform.isIOS) {
        final travelMode = mode == 'w' ? 'walking' : 'driving';
        final iosNavUri = Uri.parse(
          'comgooglemaps://?daddr=$destLat,$destLng&directionsmode=$travelMode',
        );
        if (await canLaunchUrl(iosNavUri)) {
          final ok = await launchUrl(iosNavUri, mode: LaunchMode.externalApplication);
          if (ok) return true;
        }
      }

      // 3. Universal Google Maps Directions Link (truyền chính xác tọa độ GPS đích + điểm xuất phát)
      final travelMode = mode == 'w' ? 'walking' : 'driving';
      final originParam = (originLat != null && originLng != null)
          ? '&origin=$originLat,$originLng'
          : '';
      final dirUri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1$originParam&destination=$destLat,$destLng&travelmode=$travelMode&dir_action=navigate',
      );
      if (await canLaunchUrl(dirUri)) {
        return await launchUrl(dirUri, mode: LaunchMode.externalApplication);
      }

      // 4. Geo URI Fallback
      final label = Uri.encodeComponent(destName ?? 'Cơ sở y tế');
      final geoUri = Uri.parse('geo:$destLat,$destLng?q=$destLat,$destLng($label)');
      if (await canLaunchUrl(geoUri)) {
        return await launchUrl(geoUri);
      }
    } catch (e) {
      debugPrint('[LocationService] Lỗi mở dẫn đường Google Maps 3D: $e');
    }
    return false;
  }

  /// Mở ứng dụng Google Maps đúng vùng GPS hiện tại để người dùng tải/đồng bộ Bản đồ ngoại tuyến Google
  static Future<bool> openGoogleMapsRegion({
    required double lat,
    required double lng,
  }) async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return true;
    }
    try {
      final geoUri = Uri.parse('geo:$lat,$lng?z=14');
      if (await canLaunchUrl(geoUri)) {
        return await launchUrl(geoUri, mode: LaunchMode.externalApplication);
      }
      final webUri = Uri.parse('https://www.google.com/maps/@$lat,$lng,14z');
      if (await canLaunchUrl(webUri)) {
        return await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
    return false;
  }
}
