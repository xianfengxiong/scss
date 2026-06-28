import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:pdf/widgets.dart' as pw;

import '../fill/satellite_diagram_screen.dart';
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
      // pw.Image sizes its own box to the FITTED image (contain → narrow for a
      // portrait capture in a wide cell); the parent SizedBox then pins that box
      // top-left. Wrap in pw.Center so the image centers in the cell, matching
      // the fill thumbnail (Flutter's BoxFit.contain centers by default).
      img = pw.Center(
          child: pw.Image(pw.MemoryImage(v), fit: pw.BoxFit.contain));
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

  @override
  Widget propEditor(
      Cell cell, void Function(Map<String, dynamic> props) onChanged) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          key: const ValueKey('satellite-key'),
          initialValue: (cell.props['key'] as String?) ?? '',
          decoration: const InputDecoration(labelText: 'Key'),
          onChanged: (v) => onChanged({...cell.props, 'key': v}),
        ),
        const SizedBox(height: 8),
        TextFormField(
          key: const ValueKey('satellite-caption'),
          initialValue: (cell.props['caption'] as String?) ?? '',
          decoration: const InputDecoration(labelText: 'Caption'),
          onChanged: (v) => onChanged({...cell.props, 'caption': v}),
        ),
      ],
    );
  }

  @override
  Widget fillWidget(
          Cell cell, Object? value, void Function(Object? value) onChanged) =>
      _SatelliteField(
        location: location,
        image: image,
        path: diagramPath(value),
        pins: diagramPins(value),
        center: diagramCenter(value),
        zoom: diagramZoom(value),
        onChanged: onChanged,
      );
}

/// Fill-mode widget: a screenshot thumbnail with a clear button, or an
/// open-map button when empty. Opening pushes [SatelliteDiagramScreen] and
/// stores its result as the diagram value Map.
class _SatelliteField extends StatelessWidget {
  final LocationService? location;
  final ImageService? image;
  final String? path;
  final List<Pin> pins;
  final LatLng? center;
  final double zoom;
  final void Function(Object? value) onChanged;

  const _SatelliteField({
    required this.location,
    required this.image,
    required this.path,
    required this.pins,
    required this.center,
    required this.zoom,
    required this.onChanged,
  });

  Future<void> _openMap(BuildContext context) async {
    final svc = image;
    if (svc == null) return; // tests / non-device no-op
    final result = await Navigator.of(context).push<SatelliteResult>(
      MaterialPageRoute(
        builder: (_) => SatelliteDiagramScreen(
          initialPins: pins,
          initialCenter: center,
          initialZoom: zoom,
          location: location,
          saveBytes: (bytes) => svc.saveBytes(bytes),
        ),
      ),
    );
    if (result == null) return;
    onChanged({
      'path': result.path,
      'pins': [for (final p in result.pins) p.toJson()],
      'center': {'lat': result.center.latitude, 'lon': result.center.longitude},
      'zoom': result.zoom,
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = path;
    if (p != null && p.isNotEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          // Tap the thumbnail to reopen the map and edit the existing pins
          // (center/zoom/pins are passed back in via _openMap). contain (matching
          // the PDF) so every pin stays visible even when the capture's aspect
          // ratio differs from the cell — may letterbox, but never crops a pin.
          GestureDetector(
            onTap: () => _openMap(context),
            child: Image.file(File(p), fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
                    const Center(child: Icon(Icons.broken_image, size: 16))),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              key: const ValueKey('satellite-clear'),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              iconSize: 16,
              tooltip: 'Clear',
              icon: const Icon(Icons.close),
              onPressed: () => onChanged(null),
            ),
          ),
        ],
      );
    }
    return Center(
      child: IconButton(
        key: const ValueKey('satellite-open'),
        iconSize: 20,
        tooltip: 'Open map',
        icon: const Icon(Icons.add_location_alt_outlined),
        onPressed: () => _openMap(context),
      ),
    );
  }
}
