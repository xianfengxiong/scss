/// Parse a user-typed coordinate pair into (lat, lon) decimal degrees, or
/// null. Accepts what people paste from Google Maps / phones / survey notes:
///
/// * `25.2048, 55.2708` · `25.2048 55.2708` · Chinese comma `25.2,55.3`
/// * hemisphere letters before or after: `25.2048N 55.2708E`, `S33.9 E18.4`
///   (S/W negate; letters also fix the order when longitude comes first)
/// * degree-minute-second: `25°12'17.3"N 55°16'14.9"E` (any of ° ' " may be
///   the ASCII or typographic variant; `d`, `m`, `s` sequences by position)
///
/// Out-of-range values (|lat| > 90, |lon| > 180) → null.
({double lat, double lon})? parseLatLon(String input) {
  var s = input.trim();
  if (s.isEmpty) return null;
  // Unify separators: full-width/Chinese punctuation and semicolons → comma.
  s = s.replaceAll(RegExp('[,;;、]'), ',');
  final parts = s.contains(',')
      ? s.split(',').map((p) => p.trim()).where((p) => p.isNotEmpty).toList()
      : s.split(RegExp(r'\s+'));
  if (parts.length != 2) return null;

  final a = _parseToken(parts[0]);
  final b = _parseToken(parts[1]);
  if (a == null || b == null) return null;

  // Order: default lat, lon; hemisphere letters override.
  _Coord lat, lon;
  if (a.axis == _Axis.lon || b.axis == _Axis.lat) {
    lon = a;
    lat = b;
  } else {
    lat = a;
    lon = b;
  }
  if (lat.axis == _Axis.lon || lon.axis == _Axis.lat) return null;
  if (lat.value.abs() > 90 || lon.value.abs() > 180) return null;
  return (lat: lat.value, lon: lon.value);
}

enum _Axis { unknown, lat, lon }

class _Coord {
  final double value;
  final _Axis axis;
  const _Coord(this.value, this.axis);
}

final _hemiLead = RegExp(r'^([NSEWnsew])\s*(.*)$');
final _hemiTrail = RegExp(r'^(.*?)\s*([NSEWnsew])$');
final _number = RegExp(r'-?\d+(?:\.\d+)?');

_Coord? _parseToken(String raw) {
  var t = raw.trim();
  if (t.isEmpty) return null;
  String? hemi;
  final lead = _hemiLead.firstMatch(t);
  if (lead != null) {
    hemi = lead.group(1)!.toUpperCase();
    t = lead.group(2)!;
  } else {
    final trail = _hemiTrail.firstMatch(t);
    if (trail != null) {
      hemi = trail.group(2)!.toUpperCase();
      t = trail.group(1)!;
    }
  }
  t = t.trim();
  if (t.isEmpty) return null;

  double? value;
  final isDms = RegExp('[°\'"′″]').hasMatch(t);
  if (isDms) {
    final nums = _number.allMatches(t).map((m) => m.group(0)!).toList();
    if (nums.isEmpty || nums.length > 3) return null;
    final d = double.parse(nums[0]);
    final m = nums.length > 1 ? double.parse(nums[1]) : 0.0;
    final sec = nums.length > 2 ? double.parse(nums[2]) : 0.0;
    if (m < 0 || m >= 60 || sec < 0 || sec >= 60) return null;
    final mag = d.abs() + m / 60 + sec / 3600;
    value = d.isNegative || nums[0].startsWith('-') ? -mag : mag;
  } else {
    if (!RegExp(r'^-?\d+(\.\d+)?$').hasMatch(t)) return null;
    value = double.parse(t);
  }

  var axis = _Axis.unknown;
  if (hemi != null) {
    axis = (hemi == 'N' || hemi == 'S') ? _Axis.lat : _Axis.lon;
    if (hemi == 'S' || hemi == 'W') value = -value.abs();
  }
  return _Coord(value, axis);
}
