import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;

import '../model/cell.dart';
import 'control_spec.dart';

/// A numeric value input that fills its cell. `unit` (e.g. "m") is appended to
/// the value in preview/PDF.
class NumberControl extends ControlSpec {
  @override
  String get type => 'number';
  @override
  String get label => 'Number';
  @override
  IconData get icon => Icons.pin;
  @override
  Map<String, dynamic> defaultProps() => {'key': 'number', 'unit': ''};

  String _unit(Cell c) => (c.props['unit'] as String?) ?? '';

  @override
  pw.Widget paintPdf(Cell cell, Map<String, dynamic> data) {
    final raw = (data[cell.props['key']] ?? '').toString();
    final unit = _unit(cell);
    final text = raw.isEmpty || unit.isEmpty ? raw : '$raw $unit';
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      alignment: pw.Alignment.centerLeft,
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 9)),
    );
  }

  @override
  Widget previewWidget(Cell cell) => Container(
        padding: const EdgeInsets.all(2),
        alignment: Alignment.centerLeft,
        child: Text(_unit(cell).isEmpty ? '[number]' : '[number] ${_unit(cell)}',
            style: const TextStyle(fontSize: 9, height: 1.0, color: Color(0xFF9A9A9A))),
      );

  @override
  Widget fillWidget(
          Cell cell, Object? value, void Function(Object? value) onChanged) =>
      TextFormField(
        initialValue: value?.toString() ?? '',
        keyboardType: TextInputType.number,
        expands: true,
        maxLines: null,
        textAlignVertical: TextAlignVertical.center,
        style: const TextStyle(fontSize: 9, height: 1.0),
        strutStyle: const StrutStyle(fontSize: 9, height: 1.0, forceStrutHeight: true),
        decoration: const InputDecoration(
          isDense: true,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        ),
        onChanged: onChanged,
      );

  @override
  Widget propEditor(
      Cell cell, void Function(Map<String, dynamic> props) onChanged) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          initialValue: (cell.props['key'] as String?) ?? '',
          decoration: const InputDecoration(labelText: 'Key'),
          onChanged: (v) => onChanged({...cell.props, 'key': v}),
        ),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: _unit(cell),
          decoration: const InputDecoration(labelText: 'Unit'),
          onChanged: (v) => onChanged({...cell.props, 'unit': v}),
        ),
      ],
    );
  }
}
