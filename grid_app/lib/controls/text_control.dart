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
      child: pw.Text(value, style: const pw.TextStyle(fontSize: 9)),
    );
  }

  @override
  Widget previewWidget(Cell cell) => Container(
        padding: const EdgeInsets.all(2),
        alignment: Alignment.centerLeft,
        child: const Text('[text]',
            style: TextStyle(fontSize: 9, color: Color(0xFF9A9A9A))),
      );

  @override
  Widget fillWidget(
          Cell cell, Object? value, void Function(Object? value) onChanged) =>
      TextFormField(
        initialValue: value?.toString() ?? '',
        expands: true,
        maxLines: null,
        textAlignVertical: TextAlignVertical.center,
        style: const TextStyle(fontSize: 9),
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          hintText: cell.props['hint'] as String?,
          hintStyle: const TextStyle(fontSize: 9, color: Color(0xFF9A9A9A)),
        ),
        onChanged: onChanged,
      );

  @override
  Widget propEditor(
          Cell cell, void Function(Map<String, dynamic> props) onChanged) =>
      Column(
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
            initialValue: (cell.props['hint'] as String?) ?? '',
            decoration: const InputDecoration(labelText: 'Hint'),
            onChanged: (v) => onChanged({...cell.props, 'hint': v}),
          ),
        ],
      );
}
