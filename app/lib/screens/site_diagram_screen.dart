import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:screenshot/screenshot.dart';

import '../data/database.dart';
import '../models/pin.dart';
import '../services/image_service.dart';

/// Esri World Imagery — free satellite tiles, no API key (attribution required).
const String _esriUrl =
    'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';

class SiteDiagramScreen extends StatefulWidget {
  final Site site;
  final LatLng? initialCenter;
  const SiteDiagramScreen(
      {super.key, required this.site, this.initialCenter});

  @override
  State<SiteDiagramScreen> createState() => _SiteDiagramScreenState();
}

class _SiteDiagramScreenState extends State<SiteDiagramScreen> {
  final _screenshotController = ScreenshotController();
  final _imageService = ImageService();
  late List<Pin> _pins;
  String? _diagramPath;
  bool _online = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _pins = List.of(widget.site.pins);
    _diagramPath = widget.site.diagramImagePath;
    _checkConnectivity();
  }

  Future<void> _checkConnectivity() async {
    final res = await Connectivity().checkConnectivity();
    if (mounted) {
      setState(() => _online = res.any((r) => r != ConnectivityResult.none));
    }
  }

  LatLng get _center {
    if (widget.initialCenter != null) return widget.initialCenter!;
    final gps = widget.site.gps;
    if (gps != null) return LatLng(gps.lat, gps.lon);
    if (_pins.isNotEmpty) return LatLng(_pins.first.lat, _pins.first.lon);
    return const LatLng(40.0759, 20.1389); // Gjirokastër fallback
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
    if (action == 'delete') {
      setState(() => _pins = [..._pins]..removeAt(index));
    } else if (action == 'ok') {
      setState(() {
        final list = [..._pins];
        list[index] = list[index].copyWith(label: ctrl.text.trim());
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
    var path = _diagramPath;
    if (bytes != null) {
      path = await _imageService.saveBytes(widget.site.id, bytes,
          ext: 'png', prefix: 'diagram');
    }
    if (!mounted) return;
    Navigator.pop(context, (pins: _pins, diagramPath: path));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Site Diagram'),
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
          if (!_online)
            Container(
              width: double.infinity,
              color: Colors.orange.shade100,
              padding: const EdgeInsets.all(8),
              child: const Text(
                'No network — satellite tiles may not load. Pins still work; '
                'the saved snapshot is used in the PDF.',
                style: TextStyle(fontSize: 12),
              ),
            ),
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
                options: MapOptions(
                  initialCenter: _center,
                  initialZoom: 17,
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
