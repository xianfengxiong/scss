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

    final inputBox = Container(
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
