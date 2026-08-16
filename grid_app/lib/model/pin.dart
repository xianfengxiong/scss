/// A map marker placed on a satellite diagram. `label` is an optional caption
/// (e.g. a pole number) drawn under the pin and baked into the screenshot.
/// `icon` picks the marker glyph by key (see fill/pin_icons.dart); the model
/// stores only the key so it stays Flutter-free and sync/JSON stays stable.
/// `rotation` is the device heading in degrees clockwise (cameras are aimed
/// at a junction); the classic 'pin' glyph never rotates — its tip marks the
/// coordinate. Rows written before these fields existed default to the red
/// pin at 0°, so old surveys render unchanged.
class Pin {
  final double lat;
  final double lon;
  final String label;
  final String icon;
  final double rotation;

  const Pin({
    required this.lat,
    required this.lon,
    this.label = '',
    this.icon = 'pin',
    this.rotation = 0,
  });

  Pin copyWith(
          {double? lat,
          double? lon,
          String? label,
          String? icon,
          double? rotation}) =>
      Pin(
        lat: lat ?? this.lat,
        lon: lon ?? this.lon,
        label: label ?? this.label,
        icon: icon ?? this.icon,
        rotation: rotation ?? this.rotation,
      );

  Map<String, dynamic> toJson() =>
      {'lat': lat, 'lon': lon, 'label': label, 'icon': icon, 'rotation': rotation};

  factory Pin.fromJson(Map<String, dynamic> j) => Pin(
        lat: (j['lat'] as num).toDouble(),
        lon: (j['lon'] as num).toDouble(),
        label: j['label'] as String? ?? '',
        icon: j['icon'] as String? ?? 'pin',
        rotation: (j['rotation'] as num?)?.toDouble() ?? 0,
      );
}
