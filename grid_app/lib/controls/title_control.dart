import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;

import '../model/cell.dart';
import 'control_spec.dart';

class TitleControl extends ControlSpec {
  @override
  String get type => 'title';
  @override
  String get label => 'Title';
  @override
  IconData get icon => Icons.title;
  @override
  Map<String, dynamic> defaultProps() => {'text': 'Title', 'align': 'center'};

  @override
  pw.Widget paintPdf(Cell cell, Map<String, dynamic> data) {
    final text = (cell.props['text'] as String?) ?? '';
    // TODO(Phase-1B): honour cell.props['align'] (left/center/right); 1A always centers.
    return pw.Center(
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  @override
  Widget previewWidget(Cell cell) => Center(
        // Scale-down so the (fixed 14pt) title always fits its cell height when
        // the A4 page is scaled to phone width — otherwise tall text clips
        // vertically in short grid rows (fill + builder use this widget).
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            (cell.props['text'] as String?) ?? '',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, height: 1.0),
          ),
        ),
      );

  @override
  Widget propEditor(
          Cell cell, void Function(Map<String, dynamic> props) onChanged) =>
      TextFormField(
        initialValue: (cell.props['text'] as String?) ?? '',
        decoration: const InputDecoration(labelText: 'Title text'),
        onChanged: (v) => onChanged({...cell.props, 'text': v}),
      );
}
