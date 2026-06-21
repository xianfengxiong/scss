import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;

import '../model/cell.dart';
import 'control_spec.dart';

class FieldControl extends ControlSpec {
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
          padding: const pw.EdgeInsets.all(2),
          decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
          child: pw.Text(t, style: const pw.TextStyle(fontSize: 9)),
        );

    return pw.Row(children: [
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
    return Row(children: [
      Expanded(flex: labelCols, child: box(label)),
      Expanded(flex: valueCols, child: box(valueType, grey: true)),
    ]);
  }
}
