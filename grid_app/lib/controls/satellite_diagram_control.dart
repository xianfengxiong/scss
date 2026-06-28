import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:pdf/widgets.dart' as pw;

import '../model/cell.dart';
import '../model/pin.dart';
import '../services/image_service.dart';
import '../services/location_service.dart';
import 'control_spec.dart';

/// The screen's return value: updated pins + camera state + the saved PNG path.
typedef SatelliteResult = ({
  List<Pin> pins,
  LatLng center,
  double zoom,
  String path,
});

// ---- Pure value-parsing helpers (the stored value is a JSON-safe Map). ----

Map<String, dynamic>? _asMap(Object? v) =>
    v is Map ? v.cast<String, dynamic>() : null;

/// The screenshot path inside a stored diagram value, or null if absent/empty.
String? diagramPath(Object? v) {
  final p = _asMap(v)?['path'];
  return p is String && p.isNotEmpty ? p : null;
}

/// The pins inside a stored diagram value; malformed entries are skipped.
List<Pin> diagramPins(Object? v) {
  final raw = _asMap(v)?['pins'];
  if (raw is! List) return const [];
  final out = <Pin>[];
  for (final e in raw) {
    if (e is Map && e['lat'] is num && e['lon'] is num) {
      out.add(Pin(
        lat: (e['lat'] as num).toDouble(),
        lon: (e['lon'] as num).toDouble(),
        label: e['label'] is String ? e['label'] as String : '',
      ));
    }
  }
  return out;
}

/// The saved map center, or null if absent/malformed (→ caller seeds via GPS).
LatLng? diagramCenter(Object? v) {
  final c = _asMap(v)?['center'];
  if (c is! Map) return null;
  final lat = c['lat'];
  final lon = c['lon'];
  return lat is num && lon is num
      ? LatLng(lat.toDouble(), lon.toDouble())
      : null;
}

/// The saved zoom, defaulting to 17 when absent/malformed.
double diagramZoom(Object? v) {
  final z = _asMap(v)?['zoom'];
  return z is num ? z.toDouble() : 17.0;
}

/// A satellite-map diagram control. Fill mode opens a full-screen map to drop
/// pins and capture a screenshot; the value is a Map {path, pins, center, zoom}.
/// PDF embeds the screenshot (bytes resolved via [resolvePdfValue]) plus an
/// optional caption. Supports clear (set value to null) for re-measuring.
class SatelliteDiagramControl extends ControlSpec {
  /// Injected so first-fill can center on the device's current GPS. Null → the
  /// map falls back to a fixed center (tests / non-device).
  final LocationService? location;

  /// Injected so the captured screenshot can be persisted via [ImageService
  /// .saveBytes]. Null → opening the map is a no-op (tests / non-device).
  final ImageService? image;

  SatelliteDiagramControl({this.location, this.image});

  @override
  String get type => 'satelliteDiagram';
  @override
  String get label => 'Satellite Diagram';
  @override
  IconData get icon => Icons.map_outlined;
  @override
  Map<String, dynamic> defaultProps() => {'key': 'diagram', 'caption': ''};

  @override
  String? validate(Cell cell, Object? value) => null; // empty is legal

  @override
  Future<Object?> resolvePdfValue(Cell cell, Object? value) async {
    final path = diagramPath(value);
    if (path == null) return null;
    final f = File(path);
    if (!await f.exists()) return null;
    return f.readAsBytes();
  }

  @override
  pw.Widget paintPdf(Cell cell, Map<String, dynamic> data) {
    final v = data[cell.props['key']];
    if (v is! Uint8List) return pw.SizedBox();
    pw.Widget img;
    try {
      img = pw.Image(pw.MemoryImage(v), fit: pw.BoxFit.contain);
    } catch (e) {
      debugPrint('[SatelliteDiagramControl] paintPdf: corrupt image bytes — $e');
      return pw.SizedBox();
    }
    final caption = (cell.props['caption'] as String?)?.trim() ?? '';
    if (caption.isEmpty) return img;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Expanded(child: img),
        pw.Text(caption,
            style: const pw.TextStyle(fontSize: 8),
            textAlign: pw.TextAlign.center),
      ],
    );
  }

  @override
  Widget previewWidget(Cell cell) => Container(
        alignment: Alignment.center,
        child: const Text('[satellite]',
            style: TextStyle(fontSize: 9, color: Color(0xFF9A9A9A))),
      );
}
