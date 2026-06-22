import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;

import '../model/cell.dart';
import '../services/location_service.dart';
import 'control_spec.dart';

/// A GPS coordinate value input. In fill mode, a 📍 button reads the device
/// position and fills "lat, lon" (6 dp); manual entry still works. Behaviour
/// lifted from Phase 3a's FieldControl coordinate branch.
class CoordinateControl extends ControlSpec {
  /// Injected by the registry so fill mode can capture GPS. Null in tests /
  /// non-device contexts → a plain text input.
  final LocationService? location;

  CoordinateControl({this.location});

  @override
  String get type => 'coordinate';
  @override
  String get label => 'Coordinate';
  @override
  IconData get icon => Icons.my_location;
  @override
  Map<String, dynamic> defaultProps() => {'key': 'coordinate'};

  @override
  pw.Widget paintPdf(Cell cell, Map<String, dynamic> data) {
    final value = (data[cell.props['key']] ?? '').toString();
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      alignment: pw.Alignment.centerLeft,
      decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
      child: pw.Text(value, style: const pw.TextStyle(fontSize: 9)),
    );
  }

  @override
  Widget previewWidget(Cell cell) => Container(
        padding: const EdgeInsets.all(2),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
            border: Border.all(width: 0.5, color: const Color(0xFFBDBDBD))),
        child: const Text('[coordinate]',
            style: TextStyle(fontSize: 9, color: Color(0xFF9A9A9A))),
      );

  @override
  Widget fillWidget(
      Cell cell, Object? value, void Function(Object? value) onChanged) {
    if (location == null) {
      return Container(
        decoration: BoxDecoration(
            border: Border.all(width: 0.5, color: const Color(0xFFBDBDBD))),
        child: TextFormField(
          initialValue: value?.toString() ?? '',
          expands: true,
          maxLines: null,
          textAlignVertical: TextAlignVertical.center,
          style: const TextStyle(fontSize: 9),
          decoration: const InputDecoration(
            isDense: true,
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          ),
          onChanged: onChanged,
        ),
      );
    }
    return _CoordinateField(
      location: location!,
      initialValue: value?.toString() ?? '',
      onChanged: onChanged,
    );
  }

  @override
  Widget propEditor(
          Cell cell, void Function(Map<String, dynamic> props) onChanged) =>
      TextFormField(
        initialValue: (cell.props['key'] as String?) ?? '',
        decoration: const InputDecoration(labelText: 'Key'),
        onChanged: (v) => onChanged({...cell.props, 'key': v}),
      );
}

/// Fill-mode value box for a coordinate: a text input plus a GPS button that
/// reads the device position and fills "lat, lon". Manual edits flow through
/// [onChanged].
class _CoordinateField extends StatefulWidget {
  final LocationService location;
  final String initialValue;
  final void Function(Object? value) onChanged;

  const _CoordinateField({
    required this.location,
    required this.initialValue,
    required this.onChanged,
  });

  @override
  State<_CoordinateField> createState() => _CoordinateFieldState();
}

class _CoordinateFieldState extends State<_CoordinateField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialValue);
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    setState(() => _loading = true);
    final r = await widget.location.getCoordinate();
    // widget gone during the GPS call — nothing to update (no rebuild can occur).
    if (!mounted) return;
    setState(() => _loading = false);
    if (r.ok) {
      _controller.text = formatCoordinate(r.lat!, r.lon!);
      widget.onChanged(_controller.text);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(r.error ?? 'GPS capture failed.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          border: Border.all(width: 0.5, color: const Color(0xFFBDBDBD))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              expands: true,
              maxLines: null,
              textAlignVertical: TextAlignVertical.center,
              style: const TextStyle(fontSize: 9),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              ),
              onChanged: widget.onChanged,
            ),
          ),
          IconButton(
            key: const ValueKey('gps-capture'),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            iconSize: 16,
            tooltip: 'Capture GPS',
            onPressed: _loading ? null : _capture,
            icon: _loading
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.my_location),
          ),
        ],
      ),
    );
  }
}
