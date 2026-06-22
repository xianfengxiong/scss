import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;

import '../model/cell.dart';
import 'control_spec.dart';

/// A read-only text label that fills its cell. Part of the text-control family
/// (with `title`). Separate from value controls so a "Label │ value" row is two
/// grid-aligned cells (spec §15).
class LabelControl extends ControlSpec {
  @override
  String get type => 'label';
  @override
  String get label => 'Label';
  @override
  IconData get icon => Icons.label_outline;
  @override
  Map<String, dynamic> defaultProps() =>
      {'text': 'Label', 'align': 'left', 'bold': false};

  String _text(Cell c) => (c.props['text'] as String?) ?? '';
  String _alignName(Cell c) => (c.props['align'] as String?) ?? 'left';
  bool _bold(Cell c) => (c.props['bold'] as bool?) ?? false;

  Alignment _align(Cell c) {
    switch (_alignName(c)) {
      case 'center':
        return Alignment.center;
      case 'right':
        return Alignment.centerRight;
      default:
        return Alignment.centerLeft;
    }
  }

  pw.Alignment _pwAlign(Cell c) {
    switch (_alignName(c)) {
      case 'center':
        return pw.Alignment.center;
      case 'right':
        return pw.Alignment.centerRight;
      default:
        return pw.Alignment.centerLeft;
    }
  }

  @override
  pw.Widget paintPdf(Cell cell, Map<String, dynamic> data) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        alignment: _pwAlign(cell),
        decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
        child: pw.Text(_text(cell),
            style: pw.TextStyle(
                fontSize: 9,
                fontWeight:
                    _bold(cell) ? pw.FontWeight.bold : pw.FontWeight.normal)),
      );

  @override
  Widget previewWidget(Cell cell) => Container(
        padding: const EdgeInsets.all(2),
        alignment: _align(cell),
        decoration: BoxDecoration(
            border: Border.all(width: 0.5, color: const Color(0xFFBDBDBD))),
        child: Text(_text(cell),
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 9,
                fontWeight: _bold(cell) ? FontWeight.bold : FontWeight.normal)),
      );

  @override
  Widget propEditor(
      Cell cell, void Function(Map<String, dynamic> props) onChanged) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          initialValue: _text(cell),
          decoration: const InputDecoration(labelText: 'Text'),
          onChanged: (v) => onChanged({...cell.props, 'text': v}),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _alignName(cell),
          decoration: const InputDecoration(labelText: 'Align'),
          items: const ['left', 'center', 'right']
              .map((v) => DropdownMenuItem(value: v, child: Text(v)))
              .toList(),
          onChanged: (v) => onChanged({...cell.props, 'align': v ?? 'left'}),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Bold'),
          value: _bold(cell),
          onChanged: (v) => onChanged({...cell.props, 'bold': v}),
        ),
      ],
    );
  }
}
