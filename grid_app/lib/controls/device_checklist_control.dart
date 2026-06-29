import 'package:flutter/material.dart';
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
  pw.Widget paintPdf(Cell cell, Map<String, dynamic> data) => pw.SizedBox();
}
