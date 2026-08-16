import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:screenshot/screenshot.dart';

import '../controls/satellite_diagram_control.dart';
import '../l10n/app_localizations.dart';
import '../model/pin.dart';
import '../services/location_service.dart';
import 'pin_icons.dart';
import 'pin_label_dialog.dart';

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
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _pins = List.of(widget.initialPins);
    if (widget.initialCenter == null) _seedFromGps();
  }

  @override
  void dispose() {
    // We own this MapController (passed to FlutterMap), so we dispose it — the
    // map only disposes controllers it created internally.
    _mapController.dispose();
    super.dispose();
  }

  /// First-fill only: recenter on the device's current position once available.
  Future<void> _seedFromGps() async {
    final svc = widget.location;
    if (svc == null) return;
    final res = await svc.getCoordinate();
    if (!mounted || !res.ok) return;
    _mapController.move(LatLng(res.lat!, res.lon!), widget.initialZoom);
  }

  /// The my-location button: recenter on the device's position, keeping the
  /// current zoom (the user set it for a reason).
  Future<void> _goToMyLocation() async {
    final svc = widget.location;
    if (svc == null || _locating) return;
    setState(() => _locating = true);
    final res = await svc.getCoordinate();
    if (!mounted) return;
    setState(() => _locating = false);
    if (!res.ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppLocalizations.of(context)!.locateFailed)));
      return;
    }
    _mapController.move(
        LatLng(res.lat!, res.lon!), _mapController.camera.zoom);
  }

  void _addPin(LatLng pos) {
    setState(() => _pins = [..._pins, Pin(lat: pos.latitude, lon: pos.longitude)]);
  }

  Future<void> _editPin(int index) async {
    final result = await showDialog<(String, String, String, double)>(
      context: context,
      builder: (_) => PinLabelDialog(
        initialLabel: _pins[index].label,
        initialIcon: _pins[index].icon,
        initialRotation: _pins[index].rotation,
      ),
    );
    if (result == null || !mounted) return;
    final (action, label, icon, rotation) = result;
    if (action == 'delete') {
      setState(() => _pins = [..._pins]..removeAt(index));
    } else if (action == 'ok') {
      setState(() {
        final list = [..._pins];
        list[index] =
            list[index].copyWith(label: label, icon: icon, rotation: rotation);
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
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.satelliteTitle),
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
                  tooltip: l10n.saveSnapshot,
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
            child: Text(
              l10n.mapHint,
              style: const TextStyle(color: Colors.white, fontSize: 12),
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
                          // Anchor the geographic point at the box's bottom edge;
                          // push content down (icon last) so the pin's TIP sits on
                          // the point. The 36px icon in a 60px box was top-aligned
                          // before, leaving the tip ~24px above the tapped
                          // coordinate — the offset seen on device.
                          alignment: Alignment.topCenter,
                          child: GestureDetector(
                            // Opaque: the whole marker box is tappable and the tap
                            // is consumed, so selecting a pin can't also drop a new
                            // one on the map below.
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _editPin(i),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (_pins[i].label.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4),
                                    color: Colors.white70,
                                    child: Text(_pins[i].label,
                                        style: const TextStyle(fontSize: 10)),
                                  ),
                                // Device icons rotate to their heading; the
                                // classic pin never does — its tip marks the
                                // coordinate and must stay on it.
                                Transform.rotate(
                                  angle: _pins[i].icon == 'pin'
                                      ? 0
                                      : _pins[i].rotation * math.pi / 180,
                                  child: Icon(pinIconOf(_pins[i].icon),
                                      color: Colors.red, size: 36),
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
      // Outside the Screenshot subtree, so the captured PNG never shows it.
      floatingActionButton: widget.location == null
          ? null
          : FloatingActionButton(
              key: const ValueKey('my-location'),
              tooltip: l10n.myLocation,
              onPressed: _goToMyLocation,
              child: _locating
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5))
                  : const Icon(Icons.my_location),
            ),
    );
  }
}
