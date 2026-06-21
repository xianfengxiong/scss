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
    return pw.Center(
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
      ),
    );
  }
}
