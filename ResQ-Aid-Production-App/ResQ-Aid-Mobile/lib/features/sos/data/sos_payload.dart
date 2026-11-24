import 'dart:convert';

class LocationData {
  final double lat;
  final double lng;
  final double accuracyM;
  final String source; // GPS, NETWORK, MANUAL

  LocationData({
    required this.lat,
    required this.lng,
    required this.accuracyM,
    required this.source,
  });

  Map<String, dynamic> toJson() => {
    'lat': lat,
    'lng': lng,
    'accuracy_m': accuracyM,
    'source': source,
  };

  factory LocationData.fromJson(Map<String, dynamic> json) => LocationData(
    lat: (json['lat'] as num).toDouble(),
    lng: (json['lng'] as num).toDouble(),
    accuracyM: (json['accuracy_m'] as num).toDouble(),
    source: json['source'] as String? ?? 'GPS',
  );
}

class SosPayloadP0 {
  final String clientUuid;
  final String deviceId;
  final DateTime createdAt;
  final String incidentType;
  final LocationData location;
  final bool isDemo;

  SosPayloadP0({
    required this.clientUuid,
    required this.deviceId,
    required this.createdAt,
    required this.incidentType,
    required this.location,
    required this.isDemo,
  });

  Map<String, dynamic> toJson() => {
    'client_uuid': clientUuid,
    'device_id': deviceId,
    'created_at': createdAt.toIso8601String(),
    'incident_type': incidentType,
    'location': location.toJson(),
    'is_demo': isDemo,
  };

  String toJsonString() => jsonEncode(toJson());

  int get byteSize => utf8.encode(toJsonString()).length;
}
