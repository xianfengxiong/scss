/// A vertex of a [MapPolygon] — plain lat/lon so the model stays free of
/// latlong2, like `Pin`; the map screen converts at the edge.
class GeoPoint {
  final double lat;
  final double lon;
  const GeoPoint(this.lat, this.lon);

  Map<String, dynamic> toJson() => {'lat': lat, 'lon': lon};

  /// Null for anything that isn't a `{lat: num, lon: num}` map.
  static GeoPoint? tryParse(Object? j) =>
      j is Map && j['lat'] is num && j['lon'] is num
          ? GeoPoint((j['lat'] as num).toDouble(), (j['lon'] as num).toDouble())
          : null;

  @override
  bool operator ==(Object other) =>
      other is GeoPoint && other.lat == lat && other.lon == lon;

  @override
  int get hashCode => Object.hash(lat, lon);

  @override
  String toString() => 'GeoPoint($lat, $lon)';
}

/// A filled region on a satellite diagram (site boundary, coverage zone …),
/// Google-Earth style: vertices in tap order, a translucent fill, a solid
/// outline of the same hue and an optional name drawn at the centroid — all
/// baked into the snapshot. Self-intersecting rings are allowed as drawn
/// (user decision 2026-09-20): whatever the non-zero fill rule paints is what
/// you get. `color` is an opaque 0xRRGGBB int; `opacity` (0..1) applies to
/// the fill only, so a faint fill still has a readable edge. Values written
/// before polygons existed simply lack the `polygons` key → none.
class MapPolygon {
  static const int defaultColor = 0xFFC107; // amber
  static const double defaultOpacity = 0.35;

  /// Fewer vertices is a line, not a region; parsers drop such entries.
  static const int minPoints = 3;

  final List<GeoPoint> points;
  final String label;
  final int color;
  final double opacity;

  const MapPolygon({
    required this.points,
    this.label = '',
    this.color = defaultColor,
    this.opacity = defaultOpacity,
  });

  MapPolygon copyWith(
          {List<GeoPoint>? points,
          String? label,
          int? color,
          double? opacity}) =>
      MapPolygon(
        points: points ?? this.points,
        label: label ?? this.label,
        color: color ?? this.color,
        opacity: opacity ?? this.opacity,
      );

  Map<String, dynamic> toJson() => {
        'points': [for (final p in points) p.toJson()],
        'label': label,
        'color': color,
        'opacity': opacity,
      };

  /// Tolerant parse: null unless [j] is a map with ≥[minPoints] well-formed
  /// points. Malformed vertices are skipped, missing style fields take the
  /// defaults, opacity is clamped to 0..1 and color masked to RGB. This is the
  /// one parser for both the model and the control's value helpers — two
  /// hand-rolled parsers is how pin icon/rotation went missing (2026-08-16).
  static MapPolygon? tryParse(Object? j) {
    if (j is! Map) return null;
    final raw = j['points'];
    if (raw is! List) return null;
    final pts = <GeoPoint>[
      for (final e in raw)
        if (GeoPoint.tryParse(e) case final g?) g
    ];
    if (pts.length < minPoints) return null;
    final color = j['color'];
    final opacity = j['opacity'];
    return MapPolygon(
      points: pts,
      label: j['label'] is String ? j['label'] as String : '',
      color: color is num ? color.toInt() & 0xFFFFFF : defaultColor,
      opacity:
          opacity is num ? opacity.toDouble().clamp(0.0, 1.0) : defaultOpacity,
    );
  }

  /// Whether ([lat], [lon]) lies inside the ring — non-zero winding on the
  /// lat/lon plane, matching how the fill is painted (so a tap on any painted
  /// area of a self-intersecting ring counts). Planar is fine at site scale.
  /// Drives tap-to-edit: the map layer's own hit test runs at pointer-down and
  /// can be stale when an upper layer swallows the hit, so we decide from the
  /// tapped coordinate instead.
  bool contains(double lat, double lon) {
    var winding = 0;
    for (var i = 0; i < points.length; i++) {
      final a = points[i];
      final b = points[(i + 1) % points.length];
      // Sign of (b - a) × (p - a), with lon as x and lat as y.
      final side = (b.lon - a.lon) * (lat - a.lat) - (lon - a.lon) * (b.lat - a.lat);
      if (a.lat <= lat) {
        if (b.lat > lat && side > 0) winding++;
      } else if (b.lat <= lat && side < 0) {
        winding--;
      }
    }
    return winding != 0;
  }
}

/// Index of the topmost (last-drawn) polygon containing the point, or null.
int? polygonIndexAt(List<MapPolygon> polygons, double lat, double lon) {
  for (var i = polygons.length - 1; i >= 0; i--) {
    if (polygons[i].contains(lat, lon)) return i;
  }
  return null;
}
