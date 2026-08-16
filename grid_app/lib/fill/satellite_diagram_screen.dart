import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;
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
  final _mapKey = GlobalKey();
  late List<Pin> _pins;
  bool _saving = false;
  bool _locating = false;

  /// Index of the pin being long-press dragged, or null. While set, the pin
  /// tracks the finger and renders enlarged as feedback.
  int? _dragging;

  /// Current map rotation in degrees — drives the compass so north stays
  /// readable after the user two-finger-rotates the map.
  double _mapRotation = 0;

  /// Index of the device pin in aim mode (heading adjustment), or null.
  /// Entered automatically after the edit dialog confirms a device icon;
  /// exited by tapping anywhere else. The aim handle is an edit control and
  /// must never reach the snapshot — cleared before capture.
  int? _aiming;

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
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.locateFailed)));
      return;
    }
    _mapController.move(LatLng(res.lat!, res.lon!), _mapController.camera.zoom);
  }

  void _addPin(LatLng pos) {
    // In aim mode a map tap just finishes aiming — don't also drop a pin.
    if (_aiming != null) {
      setState(() => _aiming = null);
      return;
    }
    setState(
        () => _pins = [..._pins, Pin(lat: pos.latitude, lon: pos.longitude)]);
  }

  /// Aim-mode drag: point pin [index] at the finger. The heading is the
  /// compass bearing (0° = north, clockwise) from the pin's on-screen position
  /// to the finger, so the fan tracks the finger at any zoom/rotation of use.
  void _aimPinAt(int index, Offset globalPosition) {
    final box = _mapKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(globalPosition);
    final p = _pins[index];
    final pinScreen =
        _mapController.camera.latLngToScreenOffset(LatLng(p.lat, p.lon));
    final v = local - pinScreen;
    if (v.distance < 8) return; // too close to the pin: bearing is unstable
    final deg = (math.atan2(v.dx, -v.dy) * 180 / math.pi + 360) % 360;
    setState(() {
      final list = [..._pins];
      list[index] = list[index].copyWith(rotation: deg.roundToDouble());
      _pins = list;
    });
  }

  /// Long-press drag: move pin [index] under the finger. The global position
  /// is mapped into the FlutterMap render box, then through the camera to a
  /// LatLng — so it stays correct at any zoom/pan.
  void _dragPinTo(int index, Offset globalPosition) {
    final box = _mapKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(globalPosition);
    final latlng = _mapController.camera.screenOffsetToLatLng(local);
    setState(() {
      final list = [..._pins];
      list[index] =
          list[index].copyWith(lat: latlng.latitude, lon: latlng.longitude);
      _pins = list;
    });
  }

  Future<void> _editPin(int index) async {
    final result = await showDialog<(String, String, String)>(
      context: context,
      builder: (_) => PinLabelDialog(
        initialLabel: _pins[index].label,
        initialIcon: _pins[index].icon,
      ),
    );
    if (result == null || !mounted) return;
    final (action, label, icon) = result;
    if (action == 'delete') {
      setState(() {
        _pins = [..._pins]..removeAt(index);
        _aiming = null; // indices shifted; the aimed pin may be gone
      });
    } else if (action == 'ok') {
      setState(() {
        final list = [..._pins];
        list[index] = list[index].copyWith(label: label, icon: icon);
        _pins = list;
        // Directional device confirmed → straight into on-map aim mode
        // (WYSIWYG heading). Pin and PTZ have no heading to aim.
        _aiming = pinRotates(icon) ? index : null;
      });
    }
  }

  Future<void> _saveAndExit() async {
    // The aim handle is an edit control — never bake it into the snapshot.
    setState(() {
      _aiming = null;
      _saving = true;
    });
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
    Navigator.pop<SatelliteResult>(
        context, (pins: _pins, center: cam.center, zoom: cam.zoom, path: path));
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
              _aiming == null ? l10n.mapHint : l10n.aimHint,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                Screenshot(
                  controller: _screenshotController,
                  child: FlutterMap(
                    key: _mapKey,
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: widget.initialCenter ?? _fallbackCenter,
                      initialZoom: widget.initialZoom,
                      onTap: (_, latlng) => _addPin(latlng),
                      onPositionChanged: (camera, _) {
                        if (camera.rotation != _mapRotation) {
                          setState(() => _mapRotation = camera.rotation);
                        }
                      },
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
                                // Long-press then drag moves the pin; winning the
                                // long-press arena keeps the map from panning.
                                onLongPressStart: (_) {
                                  HapticFeedback.mediumImpact();
                                  setState(() => _dragging = i);
                                },
                                onLongPressMoveUpdate: (d) =>
                                    _dragPinTo(i, d.globalPosition),
                                onLongPressEnd: (_) =>
                                    setState(() => _dragging = null),
                                onLongPressCancel: () =>
                                    setState(() => _dragging = null),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    if (_pins[i].label.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 4),
                                        color: Colors.white70,
                                        child: Text(_pins[i].label,
                                            style:
                                                const TextStyle(fontSize: 10)),
                                      ),
                                    // Directional icons rotate with the aim handle
                                    // so the glyph itself shows the heading; the
                                    // classic pin and the omnidirectional PTZ stay
                                    // upright (pinRotates). The dragged pin renders
                                    // enlarged as pickup feedback.
                                    Transform.rotate(
                                      angle: pinRotates(_pins[i].icon)
                                          ? _pins[i].rotation * math.pi / 180
                                          : 0,
                                      child: pinGlyph(_pins[i].icon,
                                          color: Colors.red,
                                          size: _dragging == i ? 44 : 36),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          // Aim handle (top layer, edit-only): a dot on the heading
                          // ray; dragging anywhere in its box re-aims the device.
                          // A plain GestureDetector pan loses the arena to the
                          // map's own drag recognizer (pan needs slop to claim,
                          // the map claims first), so an EagerGestureRecognizer
                          // wins the arena on pointer-down and a raw Listener
                          // drives the aiming from move events.
                          if (_aiming case final ai?)
                            Marker(
                              point: LatLng(_pins[ai].lat, _pins[ai].lon),
                              width: 200,
                              height: 200,
                              alignment: Alignment.center,
                              child: RawGestureDetector(
                                behavior: HitTestBehavior.opaque,
                                gestures: {
                                  EagerGestureRecognizer:
                                      GestureRecognizerFactoryWithHandlers<
                                              EagerGestureRecognizer>(
                                          EagerGestureRecognizer.new, (_) {}),
                                },
                                child: Listener(
                                  behavior: HitTestBehavior.opaque,
                                  onPointerMove: (e) =>
                                      _aimPinAt(ai, e.position),
                                  child: CustomPaint(
                                    size: const Size(200, 200),
                                    painter:
                                        _AimHandlePainter(_pins[ai].rotation),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Compass: outside the Screenshot subtree (edit aid, never in
                // the snapshot). Tracks the map rotation; tap resets to north.
                Positioned(
                  top: 12,
                  right: 12,
                  child: _CompassButton(
                    rotationDeg: _mapRotation,
                    tooltip: l10n.resetNorth,
                    onTap: () => _mapController.rotate(0),
                  ),
                ),
              ],
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

/// Round compass button: the needle tracks the map rotation (red half =
/// north); tapping resets the map to north-up.
class _CompassButton extends StatelessWidget {
  final double rotationDeg;
  final String tooltip;
  final VoidCallback onTap;
  const _CompassButton(
      {required this.rotationDeg, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.92),
        shape: const CircleBorder(),
        elevation: 2,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Transform.rotate(
              angle: rotationDeg * math.pi / 180,
              child: const CustomPaint(painter: _CompassNeedlePainter()),
            ),
          ),
        ),
      ),
    );
  }
}

class _CompassNeedlePainter extends CustomPainter {
  const _CompassNeedlePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final len = size.width * 0.30;
    final w = size.width * 0.115;
    canvas.drawPath(
        Path()
          ..moveTo(c.dx, c.dy - len)
          ..lineTo(c.dx - w, c.dy)
          ..lineTo(c.dx + w, c.dy)
          ..close(),
        Paint()..color = const Color(0xffd3312c));
    canvas.drawPath(
        Path()
          ..moveTo(c.dx, c.dy + len)
          ..lineTo(c.dx - w, c.dy)
          ..lineTo(c.dx + w, c.dy)
          ..close(),
        Paint()..color = const Color(0xff9e9e9e));
    canvas.drawCircle(c, 1.6, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_CompassNeedlePainter old) => false;
}

/// Aim-mode gizmo: a ray from the pin along the heading with a grab dot at
/// the end. Purely visual — the enclosing GestureDetector handles the drag.
class _AimHandlePainter extends CustomPainter {
  final double headingDeg;
  const _AimHandlePainter(this.headingDeg);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final rad = (headingDeg - 90) * math.pi / 180;
    final dir = Offset(math.cos(rad), math.sin(rad));
    final tip = center + dir * (size.width / 2 - 16);
    canvas.drawLine(
        center,
        tip,
        Paint()
          ..color = Colors.white
          ..strokeWidth = 2);
    canvas.drawCircle(tip, 11, Paint()..color = Colors.white);
    canvas.drawCircle(tip, 8, Paint()..color = Colors.red);
  }

  @override
  bool shouldRepaint(_AimHandlePainter old) => old.headingDeg != headingDeg;
}
