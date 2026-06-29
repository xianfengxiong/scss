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

  static Map<String, dynamic> valueOf(Object? v) =>
      v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

  @override
  Widget previewWidget(Cell cell) {
    final rows = rowsOf(cell);
    final header = showHeaderOf(cell);
    const grey = TextStyle(fontSize: 9, color: Color(0xFF9A9A9A));
    Widget line(String a) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
        child: Text(a, style: grey, maxLines: 1, overflow: TextOverflow.ellipsis));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (header)
          Expanded(
              child: line(cell.props['title'] as String? ?? 'Device checklist')),
        for (final r in rows)
          Expanded(
            child: line('☐ ${(r['label'] as String?)?.isNotEmpty == true ? r['label'] : '设备名'}'),
          ),
      ],
    );
  }

  @override
  Widget propEditor(
      Cell cell, void Function(Map<String, dynamic> props) onChanged) {
    final rows = rowsOf(cell);
    Widget textField(String label, String key) => TextFormField(
          initialValue: cell.props[key]?.toString() ?? '',
          decoration: InputDecoration(labelText: label),
          onChanged: (v) => onChanged({...cell.props, key: v}),
        );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        textField('Key', 'key'),
        const SizedBox(height: 8),
        textField('Title', 'title'),
        Row(children: [
          const Text('Show header'),
          const Spacer(),
          Switch(
            key: const ValueKey('devck-showheader'),
            value: showHeaderOf(cell),
            onChanged: (v) => onChanged({...cell.props, 'showHeader': v}),
          ),
        ]),
        Row(children: [
          Expanded(child: textField('Number label', 'numberLabel')),
          const SizedBox(width: 8),
          Expanded(child: textField('Remark label', 'remarkLabel')),
        ]),
        const SizedBox(height: 8),
        const Text('Device rows', style: TextStyle(fontWeight: FontWeight.bold)),
        for (var i = 0; i < rows.length; i++)
          Row(
            key: ValueKey('devck-row-${rows[i]['key']}'),
            children: [
              Expanded(
                child: TextFormField(
                  key: ValueKey('devck-rowlabel-${rows[i]['key']}'),
                  initialValue: rows[i]['label'] as String? ?? '',
                  decoration:
                      const InputDecoration(isDense: true, hintText: '设备名'),
                  onChanged: (v) {
                    final next = [
                      for (final r in rows) {...r}
                    ];
                    next[i]['label'] = v;
                    onChanged({...cell.props, 'rows': next});
                  },
                ),
              ),
              IconButton(
                key: ValueKey('devck-delrow-${rows[i]['key']}'),
                icon: const Icon(Icons.remove_circle_outline, size: 18),
                onPressed: () {
                  final next = [
                    for (final r in rows) {...r}
                  ]..removeAt(i);
                  onChanged({...cell.props, 'rows': next});
                },
              ),
            ],
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const ValueKey('devck-addrow'),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('加一行'),
            onPressed: () {
              final next = [
                for (final r in rows) {...r},
                {'label': '', 'key': _freeRowKey(rows)},
              ];
              onChanged({...cell.props, 'rows': next});
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget fillWidget(
          Cell cell, Object? value, void Function(Object? value) onChanged) =>
      _DeviceChecklistField(
        cell: cell,
        value: valueOf(value),
        onChanged: onChanged,
      );

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

class _DeviceChecklistField extends StatelessWidget {
  final Cell cell;
  final Map<String, dynamic> value;
  final void Function(Object? value) onChanged;

  const _DeviceChecklistField({
    required this.cell,
    required this.value,
    required this.onChanged,
  });

  void _set(String rowKey, String field, Object? v) {
    final next = {...value};
    final row = {...(next[rowKey] as Map? ?? const {})};
    row[field] = v;
    next[rowKey] = row;
    onChanged(next);
  }

  Map<String, dynamic> _row(String rowKey) {
    final r = value[rowKey];
    return r is Map ? Map<String, dynamic>.from(r) : const {};
  }

  @override
  Widget build(BuildContext context) {
    final rows = DeviceChecklistControl.rowsOf(cell);
    final header = DeviceChecklistControl.showHeaderOf(cell);
    final nameFlex = DeviceChecklistControl.nameColsFor(cell, cell.colSpan);
    final numFlex = DeviceChecklistControl.numberColsOf(cell);
    final remFlex = DeviceChecklistControl.remarkColsOf(cell);
    const cellBorder = Border.fromBorderSide(
        BorderSide(color: Color(0xFFCCCCCC), width: 0.5));

    Widget box(Widget child) =>
        Container(decoration: const BoxDecoration(border: cellBorder), child: child);

    Widget row3(Widget a, Widget b, Widget cc) => Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: nameFlex, child: box(a)),
            Expanded(flex: numFlex, child: box(b)),
            Expanded(flex: remFlex, child: box(cc)),
          ],
        );

    Widget input(String rowKey, String field) => TextFormField(
          key: ValueKey('devck-$field-$rowKey'),
          initialValue: _row(rowKey)[field]?.toString() ?? '',
          keyboardType:
              field == 'number' ? TextInputType.number : TextInputType.text,
          style: const TextStyle(fontSize: 9),
          decoration: const InputDecoration(
            isDense: true,
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(horizontal: 3, vertical: 2),
          ),
          onChanged: (v) => _set(rowKey, field, v),
        );

    final children = <Widget>[];
    if (header) {
      Widget h(String s) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
          child: Text(s,
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)));
      children.add(Expanded(
        child: row3(
          h(cell.props['title'] as String? ?? ''),
          h(cell.props['numberLabel'] as String? ?? ''),
          h(cell.props['remarkLabel'] as String? ?? ''),
        ),
      ));
    }
    for (final r in rows) {
      final rk = r['key'] as String? ?? '';
      final checked = _row(rk)['check'] == true;
      children.add(Expanded(
        child: row3(
          Row(children: [
            SizedBox(
              width: 28,
              child: Checkbox(
                key: ValueKey('devck-check-$rk'),
                value: checked,
                visualDensity: VisualDensity.compact,
                onChanged: (v) => _set(rk, 'check', v ?? false),
              ),
            ),
            Expanded(
              child: Text(r['label'] as String? ?? '',
                  style: const TextStyle(fontSize: 9)),
            ),
          ]),
          input(rk, 'number'),
          input(rk, 'remark'),
        ),
      ));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children.isEmpty ? const [SizedBox()] : children,
    );
  }
}
