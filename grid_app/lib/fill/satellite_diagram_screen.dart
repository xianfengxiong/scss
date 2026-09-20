import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:screenshot/screenshot.dart';

import '../controls/satellite_diagram_control.dart';
import '../l10n/app_localizations.dart';
import '../model/map_polygon.dart';
import '../model/pin.dart';
import '../services/location_service.dart';
import 'pin_icons.dart';
import 'pin_label_dialog.dart';
import 'polygon_edit_dialog.dart';

/// Esri World Imagery — free satellite tiles, no API key (attribution required).
const String _esriUrl =
    'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';

const LatLng _fallbackCenter = LatLng(40.0759, 20.1389); // Gjirokastër

/// Which map tap does what: drop a pin, or add a polygon vertex.
enum _Tool { pin, polygon }

/// Full-screen satellite map for dropping pins, drawing filled polygons
/// (zones) and capturing a screenshot. Self-contained (no Site/DB): takes
/// initial pins/polygons/center/zoom, returns the updated set + camera state +
/// the saved snapshot file name via [Navigator.pop]. device-only — not covered
/// by widget tests (flutter_map/screenshot/geolocator platform channels are
/// unavailable in the unit-test VM).
class SatelliteDiagramScreen extends StatefulWidget {
  final List<Pin> initialPins;
  final List<MapPolygon> initialPolygons;
  final LatLng? initialCenter;
  final double initialZoom;
  final LocationService? location;
  final Future<String> Function(Uint8List bytes) saveSnapshot;

  const SatelliteDiagramScreen({
    super.key,
    required this.initialPins,
    this.initialPolygons = const [],
    this.initialCenter,
    this.initialZoom = 17,
    this.location,
    required this.saveSnapshot,
  });

  @override
  State<SatelliteDiagramScreen> createState() => _SatelliteDiagramScreenState();
}

class _SatelliteDiagramScreenState extends State<SatelliteDiagramScreen>
    with SingleTickerProviderStateMixin {
  final _screenshotController = ScreenshotController();
  final _mapController = MapController();
  final _mapKey = GlobalKey();
  late List<Pin> _pins;
  late List<MapPolygon> _polygons;
  bool _saving = false;
  bool _locating = false;

  _Tool _tool = _Tool.pin;

  /// Vertices of the polygon being drawn (polygon tool). Rendered live as a
  /// dashed outline, filled from 3 points on; committed by Done (or silently
  /// when switching tool / saving, if it already has 3+ points).
  List<LatLng> _draft = const [];

  /// Polygon whose vertex handles are shown (after its edit dialog closes) so
  /// the shape can be fine-tuned by long-press dragging. Edit aid only —
  /// cleared before capture and by a tap elsewhere.
  int? _selectedPolygon;

  /// Vertex (of [_selectedPolygon]) being long-press dragged, or null.
  int? _draggingVertex;

  /// After the my-location button centers the map, a pulsing blue dot marks
  /// the position for a few seconds — otherwise it's hard to tell which point
  /// of the imagery you are.
  LatLng? _myLocation;
  Timer? _myLocationTimer;
  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 500));

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

  static final Color _draftColor = polygonColor(MapPolygon.defaultColor);
  static final _dashed = StrokePattern.dashed(segments: const [8, 6]);

  @override
  void initState() {
    super.initState();
    _pins = List.of(widget.initialPins);
    _polygons = List.of(widget.initialPolygons);
    if (widget.initialCenter == null) _seedFromGps();
  }

  @override
  void dispose() {
    _myLocationTimer?.cancel();
    _pulse.dispose();
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
    final here = LatLng(res.lat!, res.lon!);
    _mapController.move(here, _mapController.camera.zoom);
    // Pulse a blue dot on the position for 3 s so it's findable on imagery.
    _pulse.repeat(reverse: true);
    setState(() => _myLocation = here);
    _myLocationTimer?.cancel();
    _myLocationTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      _pulse.stop();
      setState(() => _myLocation = null);
    });
  }

  void _onMapTap(LatLng pos) {
    // A tap while an edit gizmo is up just dismisses it — no pin, no vertex.
    if (_aiming != null) {
      setState(() => _aiming = null);
      return;
    }
    if (_selectedPolygon != null) {
      setState(() => _selectedPolygon = null);
      return;
    }
    switch (_tool) {
      case _Tool.pin:
        // Pins inside zones are the normal case (a camera within the site
        // boundary), so a polygon under the finger never blocks a pin.
        setState(() =>
            _pins = [..._pins, Pin(lat: pos.latitude, lon: pos.longitude)]);
      case _Tool.polygon:
        // Not mid-draw: a tap on an existing polygon edits it. Mid-draw every
        // tap is a vertex, even over another polygon (nested zones).
        if (_draft.isEmpty) {
          final hit = polygonIndexAt(_polygons, pos.latitude, pos.longitude);
          if (hit != null) {
            _editPolygon(hit);
            return;
          }
        }
        setState(() => _draft = [..._draft, pos]);
    }
  }

  void _setTool(_Tool tool) {
    if (tool == _tool) return;
    setState(() {
      _commitDraft(); // a 3+-point draft survives the switch; shorter is dropped
      _selectedPolygon = null;
      _aiming = null;
      _tool = tool;
    });
  }

  /// Turn the draft into a polygon if it is one (≥3 points), else drop it.
  /// Mutates state — call inside setState. Returns the new polygon's index.
  int? _commitDraft() {
    final pts = _draft;
    _draft = const [];
    if (pts.length < MapPolygon.minPoints) return null;
    _polygons = [
      ..._polygons,
      MapPolygon(
          points: [for (final p in pts) GeoPoint(p.latitude, p.longitude)]),
    ];
    return _polygons.length - 1;
  }

  /// Done: commit the draft and go straight to naming/colouring it
  /// (Google Earth opens the properties dialog on creation too).
  Future<void> _finishDraft() async {
    if (_draft.length < MapPolygon.minPoints) return;
    int? index;
    setState(() => index = _commitDraft());
    if (index case final i?) await _editPolygon(i);
  }

  void _undoDraftPoint() =>
      setState(() => _draft = _draft.sublist(0, _draft.length - 1));

  void _cancelDraft() => setState(() => _draft = const []);

  Future<void> _editPolygon(int index) async {
    final poly = _polygons[index];
    final result = await showDialog<PolygonEditResult>(
      context: context,
      builder: (_) => PolygonEditDialog(
        initialLabel: poly.label,
        initialColor: poly.color,
        initialOpacity: poly.opacity,
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      if (result.action == 'delete') {
        _polygons = [..._polygons]..removeAt(index);
        _selectedPolygon = null;
        return;
      }
      if (result.action == 'ok') {
        final list = [..._polygons];
        list[index] = poly.copyWith(
            label: result.label,
            color: result.color,
            opacity: result.opacity);
        _polygons = list;
      }
      // OK or cancel: show the vertex handles so the outline can be
      // fine-tuned (long-press drag); a tap elsewhere hides them.
      _selectedPolygon = index;
    });
  }

  /// Long-press drag: move vertex [vertex] of polygon [poly] under the finger
  /// (same global→map-box→LatLng mapping as [_dragPinTo]).
  void _dragVertexTo(int poly, int vertex, Offset globalPosition) {
    final box = _mapKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final ll = _mapController.camera
        .screenOffsetToLatLng(box.globalToLocal(globalPosition));
    setState(() {
      final pts = [..._polygons[poly].points];
      pts[vertex] = GeoPoint(ll.latitude, ll.longitude);
      final list = [..._polygons];
      list[poly] = list[poly].copyWith(points: pts);
      _polygons = list;
    });
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
    // Edit aids never reach the snapshot: aim handle, my-location pulse,
    // vertex handles. An unfinished 3+-point outline is kept, not lost.
    _myLocationTimer?.cancel();
    _pulse.stop();
    setState(() {
      _aiming = null;
      _myLocation = null;
      _commitDraft();
      _selectedPolygon = null;
      _draggingVertex = null;
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
      path = await widget.saveSnapshot(bytes);
    } catch (_) {
      if (mounted) setState(() => _saving = false);
      return;
    }
    if (!mounted) return;
    final cam = _mapController.camera;
    Navigator.pop<SatelliteResult>(context, (
      pins: _pins,
      polygons: _polygons,
      center: cam.center,
      zoom: cam.zoom,
      path: path,
    ));
  }

  String _hint(AppLocalizations l10n) {
    if (_aiming != null) return l10n.aimHint;
    if (_selectedPolygon != null) return l10n.polygonSelectedHint;
    if (_tool == _Tool.polygon) {
      return _draft.isEmpty
          ? l10n.polygonHint
          : l10n.polygonDrawingHint(_draft.length);
    }
    return l10n.mapHint;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.satelliteTitle),
        actions: [
          IconButton(
            key: const ValueKey('tool-pin'),
            isSelected: _tool == _Tool.pin,
            icon: const Icon(Icons.place_outlined),
            selectedIcon: const Icon(Icons.place),
            tooltip: l10n.pinTool,
            onPressed: () => _setTool(_Tool.pin),
          ),
          IconButton(
            key: const ValueKey('tool-polygon'),
            isSelected: _tool == _Tool.polygon,
            icon: const Icon(Icons.pentagon_outlined),
            selectedIcon: const Icon(Icons.pentagon),
            tooltip: l10n.polygonTool,
            onPressed: () => _setTool(_Tool.polygon),
          ),
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
              _hint(l10n),
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
                      onTap: (_, latlng) => _onMapTap(latlng),
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
                      // Zones under the pins: translucent fill, solid outline
                      // of the same hue, name at the centroid — all part of
                      // the snapshot. The selected one gets a thicker outline.
                      if (_polygons.isNotEmpty)
                        PolygonLayer(
                          polygons: [
                            for (int i = 0; i < _polygons.length; i++)
                              Polygon(
                                points: [
                                  for (final g in _polygons[i].points)
                                    LatLng(g.lat, g.lon)
                                ],
                                color: polygonColor(_polygons[i].color)
                                    .withValues(alpha: _polygons[i].opacity),
                                borderColor: polygonColor(_polygons[i].color),
                                borderStrokeWidth:
                                    _selectedPolygon == i ? 4 : 2,
                                label: _polygons[i].label.isEmpty
                                    ? null
                                    : _polygons[i].label,
                                labelStyle: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  shadows: [
                                    Shadow(blurRadius: 4, color: Colors.black)
                                  ],
                                ),
                              ),
                          ],
                        ),
                      // The in-progress outline: dashed so it reads as a
                      // draft; a line until the 3rd vertex makes it a region.
                      if (_draft.length >= MapPolygon.minPoints)
                        PolygonLayer(
                          polygons: [
                            Polygon(
                              points: _draft,
                              color: _draftColor.withValues(
                                  alpha: MapPolygon.defaultOpacity),
                              borderColor: _draftColor,
                              borderStrokeWidth: 2,
                              pattern: _dashed,
                            ),
                          ],
                        )
                      else if (_draft.length == 2)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: _draft,
                              color: _draftColor,
                              strokeWidth: 2,
                              pattern: _dashed,
                            ),
                          ],
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
                          // Transient my-location pulse (edit aid; cleared
                          // before snapshot and 3 s after locating).
                          if (_myLocation case final loc?)
                            Marker(
                              point: loc,
                              width: 48,
                              height: 48,
                              alignment: Alignment.center,
                              child: IgnorePointer(
                                child: FadeTransition(
                                  opacity: _pulse
                                      .drive(Tween(begin: 0.15, end: 1.0)),
                                  child: Center(
                                    child: Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: const Color(0xff2979ff),
                                        border: Border.all(
                                            color: Colors.white, width: 3),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xff2979ff)
                                                .withValues(alpha: 0.55),
                                            blurRadius: 12,
                                            spreadRadius: 5,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
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
                      // Vertex handles (edit-only, cleared before capture):
                      // passive dots on the draft, draggable ones on the
                      // selected polygon.
                      if (_draft.isNotEmpty || _selectedPolygon != null)
                        MarkerLayer(
                          markers: [
                            for (final p in _draft)
                              Marker(
                                point: p,
                                width: 16,
                                height: 16,
                                alignment: Alignment.center,
                                child: IgnorePointer(
                                  child: _VertexDot(color: _draftColor, size: 12),
                                ),
                              ),
                            if (_selectedPolygon case final si?)
                              for (int v = 0;
                                  v < _polygons[si].points.length;
                                  v++)
                                Marker(
                                  point: LatLng(_polygons[si].points[v].lat,
                                      _polygons[si].points[v].lon),
                                  width: 32,
                                  height: 32,
                                  alignment: Alignment.center,
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    // Swallow taps: a tap on a handle must
                                    // neither deselect nor add anything.
                                    onTap: () {},
                                    onLongPressStart: (_) {
                                      HapticFeedback.mediumImpact();
                                      setState(() => _draggingVertex = v);
                                    },
                                    onLongPressMoveUpdate: (d) =>
                                        _dragVertexTo(si, v, d.globalPosition),
                                    onLongPressEnd: (_) =>
                                        setState(() => _draggingVertex = null),
                                    onLongPressCancel: () =>
                                        setState(() => _draggingVertex = null),
                                    child: Center(
                                      child: _VertexDot(
                                        color: polygonColor(
                                            _polygons[si].color),
                                        size: _draggingVertex == v ? 22 : 16,
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
                    onDoubleTap: () {
                      _mapController.rotate(0);
                      // Programmatic rotate doesn't fire onPositionChanged —
                      // sync the needle ourselves or it stays stale until the
                      // next gesture.
                      setState(() => _mapRotation = 0);
                    },
                  ),
                ),
                // Draft controls (outside the Screenshot subtree). Right
                // margin clears the my-location FAB.
                if (_draft.isNotEmpty)
                  Positioned(
                    left: 12,
                    right: 84,
                    bottom: 12,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Material(
                        color: Colors.white.withValues(alpha: 0.94),
                        elevation: 2,
                        borderRadius: BorderRadius.circular(24),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextButton.icon(
                                  key: const ValueKey('draft-undo'),
                                  onPressed: _undoDraftPoint,
                                  icon: const Icon(Icons.undo, size: 18),
                                  label: Text(l10n.undoPoint),
                                ),
                                TextButton(
                                  key: const ValueKey('draft-cancel'),
                                  onPressed: _cancelDraft,
                                  child: Text(l10n.cancel),
                                ),
                                FilledButton.icon(
                                  key: const ValueKey('draft-done'),
                                  onPressed:
                                      _draft.length >= MapPolygon.minPoints
                                          ? _finishDraft
                                          : null,
                                  icon: const Icon(Icons.check, size: 18),
                                  label: Text(l10n.done),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      // Outside the Screenshot subtree, so the captured snapshot never shows it.
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

/// A polygon vertex handle: white disc with a coloured rim, enlarged while
/// dragged (same pickup feedback as pins).
class _VertexDot extends StatelessWidget {
  final Color color;
  final double size;
  const _VertexDot({required this.color, required this.size});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(color: color, width: 3),
          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 3)],
        ),
      );
}

/// Round compass button: the needle tracks the map rotation (red half =
/// north); tapping resets the map to north-up.
class _CompassButton extends StatelessWidget {
  final double rotationDeg;
  final String tooltip;
  final VoidCallback onDoubleTap;
  const _CompassButton(
      {required this.rotationDeg,
      required this.tooltip,
      required this.onDoubleTap});

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
          // Double-tap only: a single tap was too easy to hit by accident
          // while panning near the corner.
          onDoubleTap: onDoubleTap,
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
