// lib/models/metro_station.dart
class MetroStation {
  final int metroId;
  final String metroName;
  final String? metroLong; // Longitude, optional
  final String? metroLat;  // Latitude, optional

  MetroStation({
    required this.metroId,
    required this.metroName,
    this.metroLong,
    this.metroLat,
  });

  factory MetroStation.fromJson(Map<String, dynamic> json) {
    return MetroStation(
      metroId: json['met_id'],
      metroName: json['met_name'] ?? 'Unknown Metro',
      metroLong: json['met_long'],
      metroLat: json['met_lat'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'met_id': metroId,
      'met_name': metroName,
      'met_long': metroLong,
      'met_lat': metroLat,
    };
  }
}