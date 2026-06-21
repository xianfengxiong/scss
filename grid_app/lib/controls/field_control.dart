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

  @override
  pw.Widget paintPdf(Cell cell, Map<String, dynamic> data) {
    final label = (cell.props['label'] as String?) ?? '';
    final key = (cell.props['key'] as String?) ?? '';
    final value = (data[key] ?? '').toString();
    final rawLabelCols = (cell.props['labelCols'] as num?)?.toInt() ?? 1;
    final labelCols = rawLabelCols.clamp(1, cell.colSpan > 1 ? cell.colSpan - 1 : 1);
    final valueCols = (cell.colSpan - labelCols).clamp(1, cell.colSpan);

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
}
