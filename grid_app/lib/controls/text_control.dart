import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;

import '../model/cell.dart';
import 'control_spec.dart';

/// A free-text value input that fills its cell. The label, if any, is a separate
/// `label` control beside it (spec §15).
class TextControl extends ControlSpec {
  @override
  String get type => 'text';
  @override
  String get label => 'Text';
  @override
  IconData get icon => Icons.short_text;
  @override
  Map<String, dynamic> defaultProps() => {'key': 'text', 'hint': ''};

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
        child: const Text('[text]',
            style: TextStyle(fontSize: 9, color: Color(0xFF9A9A9A))),
      );

  @override
  Widget fillWidget(
          Cell cell, Object? value, void Function(Object? value) onChanged) =>
      Container(
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

  @override
  Widget propEditor(
          Cell cell, void Function(Map<String, dynamic> props) onChanged) =>
      TextFormField(
        initialValue: (cell.props['key'] as String?) ?? '',
        decoration: const InputDecoration(labelText: 'Key'),
        onChanged: (v) => onChanged({...cell.props, 'key': v}),
      );
}
