/// A map marker placed on a Site's satellite diagram.
///
/// Multiple pins on one Site represent multiple poles / devices at that
/// junction or area.
class Pin {
  final double lat;
  final double lon;
  final String label;

  const Pin({required this.lat, required this.lon, this.label = ''});

  Pin copyWith({double? lat, double? lon, String? label}) => Pin(
        lat: lat ?? this.lat,
        lon: lon ?? this.lon,
        label: label ?? this.label,
      );

  Map<String, dynamic> toJson() => {'lat': lat, 'lon': lon, 'label': label};

  factory Pin.fromJson(Map<String, dynamic> j) => Pin(
        lat: (j['lat'] as num).toDouble(),
        lon: (j['lon'] as num).toDouble(),
        label: j['label'] as String? ?? '',
      );
}
