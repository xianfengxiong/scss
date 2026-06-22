import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;

import '../model/cell.dart';
import '../services/location_service.dart';
import 'control_spec.dart';

class FieldControl extends ControlSpec {
  /// Injected by the registry so a `coordinate` field can capture GPS in fill
  /// mode. Null in tests / non-device contexts → coordinate fields stay text.
  final LocationService? location;

  FieldControl({this.location});

  @override
  String get type => 'field';
  @override
  String get label => 'Field';
  @override
  IconData get icon => Icons.text_fields;
  @override
  Map<String, dynamic> defaultProps() =>
      {'label': 'Label', 'key': 'field', 'valueType': 'text', 'labelCols': 1};

  /// Label/value column split, clamped so both flex values are >= 1 even on bad
  /// data. Shared by paintPdf and previewWidget so the canvas matches the PDF.
  /// When colSpan=1, the clamp forces labelCols=1 and valueCols=1, producing a
  /// 50/50 split — this is intentional as a defensive fallback and is consistent
  /// between PDF and preview output.
  (int, int) _labelValueSplit(Cell cell) {
    final raw = (cell.props['labelCols'] as num?)?.toInt() ?? 1;
    final labelCols = raw.clamp(1, cell.colSpan > 1 ? cell.colSpan - 1 : 1);
    final valueCols = (cell.colSpan - labelCols).clamp(1, cell.colSpan);
    return (labelCols, valueCols);
  }

  @override
  pw.Widget paintPdf(Cell cell, Map<String, dynamic> data) {
    final label = (cell.props['label'] as String?) ?? '';
    final key = (cell.props['key'] as String?) ?? '';
    final value = (data[key] ?? '').toString();
    final (labelCols, valueCols) = _labelValueSplit(cell);

    pw.Widget box(String t) => pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          alignment: pw.Alignment.centerLeft,
          decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
          child: pw.Text(t, style: const pw.TextStyle(fontSize: 9)),
        );

    // stretch: both boxes fill the full cell height, so an empty value box does
    // not shrink-wrap to a thin line and rows stay even.
    return pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
      pw.Expanded(flex: labelCols, child: box(label)),
      pw.Expanded(flex: valueCols, child: box(value)),
    ]);
  }

  @override
  Widget previewWidget(Cell cell) {
    final label = (cell.props['label'] as String?) ?? '';
    final valueType = (cell.props['valueType'] as String?) ?? 'text';
    final (labelCols, valueCols) = _labelValueSplit(cell);
    Widget box(String t, {bool grey = false}) => Container(
          padding: const EdgeInsets.all(2),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
              border: Border.all(width: 0.5, color: const Color(0xFFBDBDBD))),
          child: Text(t,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 9, color: grey ? const Color(0xFF9A9A9A) : Colors.black)),
        );
    return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(flex: labelCols, child: box(label)),
      Expanded(flex: valueCols, child: box('[$valueType]', grey: true)),
    ]);
  }

  @override
  Widget fillWidget(
      Cell cell, Object? value, void Function(Object? value) onChanged) {
    final label = (cell.props['label'] as String?) ?? '';
    final valueType = (cell.props['valueType'] as String?) ?? 'text';
    final (labelCols, valueCols) = _labelValueSplit(cell);

    final labelBox = Container(
      padding: const EdgeInsets.all(2),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
          border: Border.all(width: 0.5, color: const Color(0xFFBDBDBD))),
      child: Text(label,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 9)),
    );

    final Widget inputBox;
    if (valueType == 'coordinate' && location != null) {
      inputBox = _CoordinateField(
        location: location!,
        initialValue: value?.toString() ?? '',
        onChanged: onChanged,
      );
    } else {
      inputBox = Container(
        decoration: BoxDecoration(
            border: Border.all(width: 0.5, color: const Color(0xFFBDBDBD))),
        child: TextFormField(
          initialValue: value?.toString() ?? '',
          keyboardType:
              valueType == 'number' ? TextInputType.number : TextInputType.text,
          // Fill the cell's height so the input matches the WYSIWYG row.
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

    return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(flex: labelCols, child: labelBox),
      Expanded(flex: valueCols, child: inputBox),
    ]);
  }

  @override
  Widget propEditor(
      Cell cell, void Function(Map<String, dynamic> props) onChanged) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          initialValue: (cell.props['label'] as String?) ?? '',
          decoration: const InputDecoration(labelText: 'Label'),
          onChanged: (v) => onChanged({...cell.props, 'label': v}),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: (cell.props['valueType'] as String?) ?? 'text',
          decoration: const InputDecoration(labelText: 'Value type'),
          items: const ['text', 'number', 'coordinate', 'select', 'date']
              .map((v) => DropdownMenuItem(value: v, child: Text(v)))
              .toList(),
          onChanged: (v) =>
              onChanged({...cell.props, 'valueType': v ?? 'text'}),
        ),
      ],
    );
  }
}

/// Fill-mode value box for a `coordinate` field: a text input plus a GPS button
/// that reads the device position and fills "lat, lon". Manual edits still flow
/// through [onChanged].
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
