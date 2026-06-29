import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../model/cell.dart';
import 'control_spec.dart';

/// A grid-native device checklist: fixed device rows × three columns
/// (checkbox+name / Number / Remark). Each device row = one grid row, so the
/// table aligns with the rest of the page (spec 2026-06-29, scheme B). rowSpan
/// and the device-row count stay in sync via [requiredRowSpan] / [reconcile].
class DeviceChecklistControl extends ControlSpec {
  @override
  String get type => 'deviceChecklist';
  @override
  String get label => 'Device Checklist';
  @override
  IconData get icon => Icons.checklist;

  @override
  Map<String, dynamic> defaultProps() => {
        'key': 'deviceChecklist',
        'title': 'Type of device to install',
        'showHeader': true,
        'numberLabel': 'Number',
        'remarkLabel': 'Remark',
        'rows': [
          {'label': '', 'key': 'r1'},
          {'label': '', 'key': 'r2'},
          {'label': '', 'key': 'r3'},
          {'label': '', 'key': 'r4'},
        ],
        'numberCols': 1,
        'remarkCols': 2,
      };

  // ---- prop accessors (static so tests + widgets share them) ----
  static List<Map<String, dynamic>> rowsOf(Cell c) =>
      (c.props['rows'] as List?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList() ??
      <Map<String, dynamic>>[];
  static bool showHeaderOf(Cell c) => c.props['showHeader'] as bool? ?? true;
  static int numberColsOf(Cell c) => (c.props['numberCols'] as num?)?.toInt() ?? 1;
  static int remarkColsOf(Cell c) => (c.props['remarkCols'] as num?)?.toInt() ?? 2;

  /// Device-name column width in grid columns = colSpan − number − remark,
  /// floored at 1 so rendering never divides by a non-positive flex.
  static int nameColsFor(Cell c, int colSpan) {
    final n = colSpan - numberColsOf(c) - remarkColsOf(c);
    return n < 1 ? 1 : n;
  }

  @override
  int? requiredRowSpan(Cell cell) =>
      rowsOf(cell).length + (showHeaderOf(cell) ? 1 : 0);

  @override
  int? defaultColSpan() => 4;

  @override
  Cell reconcile(Cell cell) {
    final header = showHeaderOf(cell) ? 1 : 0;
    final want = cell.rowSpan - header;
    final wantRows = want < 0 ? 0 : want;
    final rows = rowsOf(cell);
    if (rows.length == wantRows) return cell;
    final next = [...rows];
    if (next.length > wantRows) {
      next.removeRange(wantRows, next.length);
    } else {
      while (next.length < wantRows) {
        next.add({'label': '', 'key': _freeRowKey(next)});
      }
    }
    return cell.copyWith(props: {...cell.props, 'rows': next});
  }

  /// First `r<n>` key (n from 1) not already used in [rows].
  static String _freeRowKey(List<Map<String, dynamic>> rows) {
    final used = rows.map((e) => e['key']).toSet();
    var n = 1;
    while (used.contains('r$n')) {
      n++;
    }
    return 'r$n';
  }

  static Map<String, dynamic> _rowValue(Map<String, dynamic> data, String key, String rowKey) {
    final v = data[key];
    if (v is Map) {
      final rv = v[rowKey];
      if (rv is Map) return Map<String, dynamic>.from(rv);
    }
    return const {};
  }

  @override
  pw.Widget paintPdf(Cell cell, Map<String, dynamic> data) {
    final key = cell.props['key'] as String? ?? '';
    final rows = rowsOf(cell);
    final header = showHeaderOf(cell);
    final nameFlex = nameColsFor(cell, cell.colSpan);
    final numFlex = numberColsOf(cell);
    final remFlex = remarkColsOf(cell);
    const fs = pw.TextStyle(fontSize: 9);

    pw.Widget pcell(pw.Widget child, {pw.Alignment align = pw.Alignment.centerLeft}) =>
        pw.Container(
          alignment: align,
          padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 1),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey, width: 0.4),
          ),
          child: child,
        );

    pw.Widget row3(pw.Widget a, pw.Widget b, pw.Widget cc) => pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Expanded(flex: nameFlex, child: a),
            pw.Expanded(flex: numFlex, child: b),
            pw.Expanded(flex: remFlex, child: cc),
          ],
        );

    final children = <pw.Widget>[];
    if (header) {
      children.add(pw.Expanded(
        child: row3(
          pcell(pw.Text(cell.props['title'] as String? ?? '', style: fs)),
          pcell(pw.Text(cell.props['numberLabel'] as String? ?? '', style: fs)),
          pcell(pw.Text(cell.props['remarkLabel'] as String? ?? '', style: fs)),
        ),
      ));
    }
    for (final r in rows) {
      final rk = r['key'] as String? ?? '';
      final rv = _rowValue(data, key, rk);
      final checked = rv['check'] == true;
      children.add(pw.Expanded(
        child: row3(
          pcell(pw.Row(children: [
            pw.Container(
              width: 8,
              height: 8,
              alignment: pw.Alignment.center,
              decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.6)),
              child: checked
                  ? pw.Text('X', style: const pw.TextStyle(fontSize: 7))
                  : pw.SizedBox(),
            ),
            pw.SizedBox(width: 3),
            pw.Expanded(child: pw.Text(r['label'] as String? ?? '', style: fs)),
          ])),
          pcell(pw.Text(rv['number']?.toString() ?? '', style: fs)),
          pcell(pw.Text(rv['remark']?.toString() ?? '', style: fs)),
        ),
      ));
    }
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: children.isEmpty ? [pw.SizedBox()] : children,
    );
  }
}
