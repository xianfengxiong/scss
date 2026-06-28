import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:screenshot/screenshot.dart';

import '../controls/satellite_diagram_control.dart';
import '../model/pin.dart';
import '../services/location_service.dart';

/// Esri World Imagery — free satellite tiles, no API key (attribution required).
const String _esriUrl =
    'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';

const LatLng _fallbackCenter = LatLng(40.0759, 20.1389); // Gjirokastër

/// Full-screen satellite map for dropping pins and capturing a screenshot.
/// Self-contained (no Site/DB): takes initial pins/center/zoom, returns updated
/// pins + camera state + saved PNG path via [Navigator.pop]. device-only — not
/// covered by widget tests (flutter_map/screenshot/geolocator platform channels
/// are unavailable in the unit-test VM).
class SatelliteDiagramScreen extends StatefulWidget {
  final List<Pin> initialPins;
  final LatLng? initialCenter;
  final double initialZoom;
  final LocationService? location;
  final Future<String> Function(Uint8List bytes) saveBytes;

  const SatelliteDiagramScreen({
    super.key,
    required this.initialPins,
    this.initialCenter,
    this.initialZoom = 17,
    this.location,
    required this.saveBytes,
  });

  @override
  State<SatelliteDiagramScreen> createState() => _SatelliteDiagramScreenState();
}

class _SatelliteDiagramScreenState extends State<SatelliteDiagramScreen> {
  final _screenshotController = ScreenshotController();
  final _mapController = MapController();
  late List<Pin> _pins;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _pins = List.of(widget.initialPins);
    if (widget.initialCenter == null) _seedFromGps();
  }

  /// First-fill only: recenter on the device's current position once available.
  Future<void> _seedFromGps() async {
    final svc = widget.location;
    if (svc == null) return;
    final res = await svc.getCoordinate();
    if (!mounted || !res.ok) return;
    _mapController.move(LatLng(res.lat!, res.lon!), widget.initialZoom);
  }

  void _addPin(LatLng pos) {
    setState(() => _pins = [..._pins, Pin(lat: pos.latitude, lon: pos.longitude)]);
  }

  Future<void> _editPin(int index) async {
    final ctrl = TextEditingController(text: _pins[index].label);
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pin'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Label (optional)'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, 'delete'),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
          TextButton(
              onPressed: () => Navigator.pop(context, 'cancel'),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, 'ok'),
              child: const Text('OK')),
        ],
      ),
    );
    final label = ctrl.text.trim(); // read before dispose
    ctrl.dispose();
    if (!mounted) return;
    if (action == 'delete') {
      setState(() => _pins = [..._pins]..removeAt(index));
    } else if (action == 'ok') {
      setState(() {
        final list = [..._pins];
        list[index] = list[index].copyWith(label: label);
        _pins = list;
      });
    }
  }

  Future<void> _saveAndExit() async {
    setState(() => _saving = true);
    Uint8List? bytes;
    try {
      bytes = await _screenshotController.capture(
          delay: const Duration(milliseconds: 250));
    } catch (_) {
      bytes = null;
    }
    if (bytes == null) {
      if (mounted) setState(() => _saving = false);
      return;
    }
    final String path;
    try {
      path = await widget.saveBytes(bytes);
    } catch (_) {
      if (mounted) setState(() => _saving = false);
      return;
    }
    if (!mounted) return;
    final cam = _mapController.camera;
    Navigator.pop<SatelliteResult>(context,
        (pins: _pins, center: cam.center, zoom: cam.zoom, path: path));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Satellite Diagram'),
        actions: [
          _saving
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : IconButton(
                  icon: const Icon(Icons.save_outlined),
                  tooltip: 'Save snapshot',
                  onPressed: _saveAndExit,
                ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.black87,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            child: const Text(
              'Tap map to drop a pin · tap a pin to edit/delete · Save to snapshot.',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          Expanded(
            child: Screenshot(
              controller: _screenshotController,
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: widget.initialCenter ?? _fallbackCenter,
                  initialZoom: widget.initialZoom,
                  onTap: (_, latlng) => _addPin(latlng),
                ),
                children: [
                  TileLayer(
                    urlTemplate: _esriUrl,
                    userAgentPackageName: 'com.scss.scss',
                    maxNativeZoom: 19,
                  ),
                  MarkerLayer(
                    markers: [
                      for (int i = 0; i < _pins.length; i++)
                        Marker(
                          point: LatLng(_pins[i].lat, _pins[i].lon),
                          width: 120,
                          height: 60,
                          alignment: Alignment.topCenter,
                          child: GestureDetector(
                            onTap: () => _editPin(i),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.location_on,
                                    color: Colors.red, size: 36),
                                if (_pins[i].label.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4),
                                    color: Colors.white70,
                                    child: Text(_pins[i].label,
                                        style: const TextStyle(fontSize: 10)),
                                  ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
