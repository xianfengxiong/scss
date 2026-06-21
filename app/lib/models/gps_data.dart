import 'dart:convert';

enum GpsSource { auto, manual }

enum GpsStatus { valid, weak, unavailable }

/// A captured GPS position for a [Site].
class GpsData {
  final double lat;
  final double lon;
  final double? accuracy; // meters
  final GpsSource source;
  final GpsStatus status;

  const GpsData({
    required this.lat,
    required this.lon,
    this.accuracy,
    this.source = GpsSource.auto,
    this.status = GpsStatus.valid,
  });

  /// Derives a status bucket from horizontal accuracy (meters).
  static GpsStatus statusFromAccuracy(double? accuracy) {
    if (accuracy == null) return GpsStatus.unavailable;
    if (accuracy <= 20) return GpsStatus.valid;
    return GpsStatus.weak;
  }

  GpsData copyWith({
    double? lat,
    double? lon,
    double? accuracy,
    GpsSource? source,
    GpsStatus? status,
  }) =>
      GpsData(
        lat: lat ?? this.lat,
        lon: lon ?? this.lon,
        accuracy: accuracy ?? this.accuracy,
        source: source ?? this.source,
        status: status ?? this.status,
      );

  Map<String, dynamic> toJson() => {
        'lat': lat,
        'lon': lon,
        'accuracy': accuracy,
        'source': source.name,
        'status': status.name,
      };

  factory GpsData.fromJson(Map<String, dynamic> j) => GpsData(
        lat: (j['lat'] as num).toDouble(),
        lon: (j['lon'] as num).toDouble(),
        accuracy: (j['accuracy'] as num?)?.toDouble(),
        source: GpsSource.values
            .firstWhere((e) => e.name == j['source'], orElse: () => GpsSource.auto),
        status: GpsStatus.values.firstWhere(
            (e) => e.name == j['status'], orElse: () => GpsStatus.valid),
      );

  String encode() => jsonEncode(toJson());

  static GpsData decode(String s) =>
      GpsData.fromJson(jsonDecode(s) as Map<String, dynamic>);

  /// "41.123456, 20.123456 (±8m)"
  String get display =>
      '${lat.toStringAsFixed(6)}, ${lon.toStringAsFixed(6)}'
      '${accuracy != null ? ' (±${accuracy!.toStringAsFixed(0)}m)' : ''}';
}
