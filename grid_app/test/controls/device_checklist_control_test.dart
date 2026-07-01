import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:scss_grid/controls/default_controls.dart';
import 'package:scss_grid/controls/device_checklist_control.dart';
import 'package:scss_grid/controls/number_control.dart';
import 'package:scss_grid/model/cell.dart';

Widget _host(Widget child) => MaterialApp(
    home: Scaffold(body: SizedBox(width: 320, height: 700, child: child)));

void main() {
  test('ControlSpec hooks default to no-op on existing controls', () {
    final n = NumberControl();
    const cell = Cell(id: 'n', col: 0, row: 0, type: 'number');
    expect(n.requiredRowSpan(cell), isNull);
    expect(n.reconcile(cell), same(cell));
    expect(n.defaultColSpan(), isNull);
  });

  test('type / label / defaultProps / dataKey', () {
    final c = DeviceChecklistControl();
    expect(c.type, 'deviceChecklist');
    expect(c.label, 'Device Checklist');
    final p = c.defaultProps();
    expect(p['key'], 'deviceChecklist');
    expect(p['title'], 'Type of device to install');
    expect(p['showHeader'], true);
    expect(p['numberLabel'], 'Number');
    expect(p['remarkLabel'], 'Remark');
    expect(p['numberCols'], 1);
    expect(p['remarkCols'], 2);
    expect((p['rows'] as List).length, 4);
    final cell = Cell(id: 'd', col: 0, row: 0, type: 'deviceChecklist', props: p);
    expect(c.dataKey(cell), 'deviceChecklist');
    expect(DeviceChecklistControl.showHeaderOf(cell), true);
    expect(DeviceChecklistControl.numberColsOf(cell), 1);
    expect(DeviceChecklistControl.remarkColsOf(cell), 2);
    // colSpan 6: name = 6 - 1 - 2 = 3
    expect(DeviceChecklistControl.nameColsFor(cell, 6), 3);
  });

  test('registered in default registry', () {
    final r = buildDefaultRegistry();
    expect(r.specFor('deviceChecklist'), isA<DeviceChecklistControl>());
  });

  test('requiredRowSpan = rows + header', () {
    final c = DeviceChecklistControl();
    final withHeader = Cell(
        id: 'd', col: 0, row: 0, type: 'deviceChecklist', props: c.defaultProps());
    expect(c.requiredRowSpan(withHeader), 5); // 4 rows + header
    final noHeader = withHeader.copyWith(
        props: {...withHeader.props, 'showHeader': false});
    expect(c.requiredRowSpan(noHeader), 4);
    expect(c.defaultColSpan(), 6); // name column widest by default (6-1-2=3)
  });

  test('reconcile makes rows follow rowSpan (grow appends blank, shrink trims)', () {
    final c = DeviceChecklistControl();
    final base = Cell(
        id: 'd', col: 0, row: 0, colSpan: 6, rowSpan: 5,
        type: 'deviceChecklist', props: c.defaultProps()); // 4 rows, header

    // grow: rowSpan 7 → want 6 device rows → append 2 blanks with unique keys
    final grown = c.reconcile(base.copyWith(rowSpan: 7));
    final grownRows = DeviceChecklistControl.rowsOf(grown);
    expect(grownRows.length, 6);
    expect(grownRows.map((e) => e['key']).toSet().length, 6); // keys unique
    expect(grownRows.last['label'], '');

    // shrink: rowSpan 3 → want 2 device rows → trim from the end
    final shrunk = c.reconcile(base.copyWith(rowSpan: 3));
    final shrunkRows = DeviceChecklistControl.rowsOf(shrunk);
    expect(shrunkRows.length, 2);
    // shrink trims from the end: surviving first row keeps original key
    expect(shrunkRows.first['key'], DeviceChecklistControl.rowsOf(base).first['key']);

    // grow preserves existing rows: first 4 keys are unchanged (only blanks appended)
    final baseKeys = DeviceChecklistControl.rowsOf(base).map((e) => e['key']).toList();
    expect(grownRows.take(4).map((e) => e['key']).toList(), baseKeys);

    // already consistent → unchanged identity-ish (same length)
    expect(DeviceChecklistControl.rowsOf(c.reconcile(base)).length, 4);
  });

  test('paintPdf builds a Column of rows, tolerates null/missing values', () {
    final c = DeviceChecklistControl();
    final cell = Cell(
        id: 'd', col: 0, row: 0, colSpan: 6, rowSpan: 5,
        type: 'deviceChecklist', props: c.defaultProps());
    expect(c.paintPdf(cell, const {}), isA<pw.Column>());
    expect(
        () => c.paintPdf(cell, const {
              'deviceChecklist': {
                'r1': {'check': true, 'number': '3', 'remark': 'ok'},
                'r3': {'check': false},
              }
            }),
        returnsNormally);
    final noHeader =
        cell.copyWith(props: {...cell.props, 'showHeader': false});
    expect(() => c.paintPdf(noHeader, const {}), returnsNormally);
  });

  test('nameColsFor: floors to 1 when colSpan - number - remark < 1', () {
    final c = DeviceChecklistControl();
    final cell = Cell(
        id: 'd', col: 0, row: 0, type: 'deviceChecklist', props: c.defaultProps());
    // defaults: numberCols=1, remarkCols=2; colSpan 3 → 3-1-2=0 → floored to 1
    expect(DeviceChecklistControl.nameColsFor(cell, 3), 1);
    // normal case: colSpan 6 → 6-1-2=3
    expect(DeviceChecklistControl.nameColsFor(cell, 6), 3);
  });

  testWidgets('fillWidget: pre-existing rows preserved when another row is edited',
      (tester) async {
    final c = DeviceChecklistControl();
    final cell = Cell(
        id: 'd', col: 0, row: 0, colSpan: 6, rowSpan: 5,
        type: 'deviceChecklist', props: c.defaultProps());
    Map<String, dynamic> value = {'r2': {'check': true}};
    await tester.pumpWidget(_host(c.fillWidget(cell, value, (v) {
      value = Map<String, dynamic>.from(v as Map);
    })));
    await tester.enterText(find.byKey(const ValueKey('devck-number-r1')), '42');
    // r1 number is written
    expect((value['r1'] as Map)['number'], '42');
    // r2's pre-existing check is preserved
    expect((value['r2'] as Map)['check'], true);
  });

  testWidgets('fillWidget: tap a row checkbox → onChanged sets that row check',
      (tester) async {
    final c = DeviceChecklistControl();
    final cell = Cell(
        id: 'd', col: 0, row: 0, colSpan: 6, rowSpan: 5,
        type: 'deviceChecklist', props: c.defaultProps());
    Object? captured;
    await tester.pumpWidget(_host(c.fillWidget(cell, null, (v) => captured = v)));
    await tester.tap(find.byKey(const ValueKey('devck-check-r2')));
    await tester.pump();
    expect(captured, isA<Map>());
    expect((captured as Map)['r2'], {'check': true});
  });

  testWidgets('fillWidget: typing Number/Remark writes that row only',
      (tester) async {
    final c = DeviceChecklistControl();
    final cell = Cell(
        id: 'd', col: 0, row: 0, colSpan: 6, rowSpan: 5,
        type: 'deviceChecklist', props: c.defaultProps());
    Map<String, dynamic> value = {};
    await tester.pumpWidget(_host(c.fillWidget(cell, value, (v) {
      value = Map<String, dynamic>.from(v as Map);
    })));
    await tester.enterText(find.byKey(const ValueKey('devck-number-r1')), '3');
    expect((value['r1'] as Map)['number'], '3');
    expect(value.containsKey('r2'), isFalse);
  });

  testWidgets('propEditor: add row appends a blank row to props.rows',
      (tester) async {
    final c = DeviceChecklistControl();
    final cell = Cell(
        id: 'd', col: 0, row: 0, colSpan: 6, rowSpan: 5,
        type: 'deviceChecklist', props: c.defaultProps());
    Map<String, dynamic>? captured;
    await tester.pumpWidget(_host(SingleChildScrollView(
        child: c.propEditor(cell, (p) => captured = p))));
    await tester.tap(find.byKey(const ValueKey('devck-addrow')));
    expect(captured, isNotNull);
    expect((captured!['rows'] as List).length, 5);
  });

  testWidgets('propEditor: delete row removes that row', (tester) async {
    final c = DeviceChecklistControl();
    final cell = Cell(
        id: 'd', col: 0, row: 0, colSpan: 6, rowSpan: 5,
        type: 'deviceChecklist', props: c.defaultProps());
    Map<String, dynamic>? captured;
    await tester.pumpWidget(_host(SingleChildScrollView(
        child: c.propEditor(cell, (p) => captured = p))));
    await tester.tap(find.byKey(const ValueKey('devck-delrow-r2')));
    expect((captured!['rows'] as List).length, 3);
    expect((captured!['rows'] as List).map((e) => e['key']),
        isNot(contains('r2')));
  });

  testWidgets('propEditor: editing a row label updates props.rows', (tester) async {
    final c = DeviceChecklistControl();
    final cell = Cell(
        id: 'd', col: 0, row: 0, colSpan: 6, rowSpan: 5,
        type: 'deviceChecklist', props: c.defaultProps());
    Map<String, dynamic>? captured;
    await tester.pumpWidget(_host(SingleChildScrollView(
        child: c.propEditor(cell, (p) => captured = p))));
    await tester.enterText(
        find.byKey(const ValueKey('devck-rowlabel-r1')), 'POE Switch');
    final rows = captured!['rows'] as List;
    expect((rows.first as Map)['label'], 'POE Switch');
  });

  // #2: PDF checked mark is a vector checkmark (✓), not the letter 'X'.
  test('checkMark: checked → vector CustomPaint, unchecked → empty SizedBox', () {
    expect(DeviceChecklistControl.checkMark(true), isA<pw.CustomPaint>());
    expect(DeviceChecklistControl.checkMark(false), isA<pw.SizedBox>());
  });

  // #3: fill-mode check must be a compact indicator that fits a small grid row,
  // NOT a fixed-size Material Checkbox that overflows the cell.
  testWidgets('fillWidget: uses a compact check indicator, not a Material Checkbox',
      (tester) async {
    final c = DeviceChecklistControl();
    final cell = Cell(
        id: 'd', col: 0, row: 0, colSpan: 6, rowSpan: 5,
        type: 'deviceChecklist', props: c.defaultProps());
    await tester.pumpWidget(_host(c.fillWidget(cell, null, (_) {})));
    expect(find.byType(Checkbox), findsNothing);
    expect(find.byKey(const ValueKey('devck-check-r1')), findsOneWidget);
  });

  // #4: a long header title must stay fully visible in a short/narrow cell by
  // scaling down (FittedBox), not clip vertically or truncate horizontally.
  testWidgets('fillWidget: header title scales to fit its cell (FittedBox)',
      (tester) async {
    final c = DeviceChecklistControl();
    final cell = Cell(
        id: 'd', col: 0, row: 0, colSpan: 4, rowSpan: 5,
        type: 'deviceChecklist', props: c.defaultProps());
    await tester.pumpWidget(_host(c.fillWidget(cell, null, (_) {})));
    expect(
        find.ancestor(
            of: find.text('Type of device to install'),
            matching: find.byType(FittedBox)),
        findsOneWidget);
  });

  // #5: property editor exposes Number/Remark column-width steppers.
  testWidgets('propEditor: number/remark column steppers adjust props', (tester) async {
    final c = DeviceChecklistControl();
    final cell = Cell(
        id: 'd', col: 0, row: 0, colSpan: 6, rowSpan: 5,
        type: 'deviceChecklist', props: c.defaultProps()); // number 1, remark 2, name 3
    Map<String, dynamic>? captured;
    await tester.pumpWidget(_host(SingleChildScrollView(
        child: c.propEditor(cell, (p) => captured = p))));
    await tester.tap(find.byKey(const ValueKey('devck-numbercols-inc')));
    expect(captured!['numberCols'], 2);
    captured = null;
    await tester.tap(find.byKey(const ValueKey('devck-remarkcols-inc')));
    expect(captured!['remarkCols'], 3);
  });

  // #5 guard: cannot grow a column past the point where the name column < 1.
  testWidgets('propEditor: column stepper inc disabled when name column would drop below 1',
      (tester) async {
    final c = DeviceChecklistControl();
    // colSpan 6, number 3, remark 2 → name = 6-3-2 = 1 (at the floor)
    final cell = Cell(
        id: 'd', col: 0, row: 0, colSpan: 6, rowSpan: 5, type: 'deviceChecklist',
        props: {...c.defaultProps(), 'numberCols': 3, 'remarkCols': 2});
    await tester.pumpWidget(_host(SingleChildScrollView(
        child: c.propEditor(cell, (_) {}))));
    final incBtn = tester.widget<IconButton>(
        find.byKey(const ValueKey('devck-numbercols-inc')));
    expect(incBtn.onPressed, isNull);
  });
}
