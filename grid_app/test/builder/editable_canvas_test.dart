import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/builder/editable_canvas.dart';
import 'package:scss_grid/controls/default_controls.dart';
import 'package:scss_grid/model/cell.dart';
import 'package:scss_grid/model/grid_frame.dart';
import 'package:scss_grid/model/template.dart';

// 210mm wide canvas at 210px -> scale 1px/mm. Grid: x0 y0, 6 cols * 35mm, 6 rows * 30mm.
Template _tpl(List<Cell> cells) => Template(
      id: 't',
      name: 'n',
      page: const PageSize.a4(),
      grid: GridFrame.uniform(
          xMm: 0, yMm: 0, cols: 6, rows: 6, colWidthMm: 35, rowHeightMm: 30),
      cells: cells,
    );

Widget _host(Widget child) => MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: 210, height: 297, child: child),
        ),
      ),
    );

void main() {
  testWidgets('tap selects the cell under the pointer', (tester) async {
    String? selected;
    await tester.pumpWidget(_host(EditableCanvas(
      template: _tpl(const [
        Cell(id: 'a', col: 0, row: 0, colSpan: 2, type: 'field',
            props: {'label': 'L', 'key': 'k'}),
      ]),
      registry: buildDefaultRegistry(),
      selectedId: null,
      onSelect: (id) => selected = id,
      onMove: (_, __, ___) {},
      onSpan: (_, __, ___) {},
      onResizeCol: (_, __) {},
      onResizeRow: (_, __) {},
    )));
    // cell 'a' covers x 0..70mm, y 0..30mm -> tap at (10,10)px is inside it
    await tester.tapAt(const Offset(10, 10));
    expect(selected, 'a');
  });

  testWidgets('dragging the selected cell body reports a move to the pointer coord',
      (tester) async {
    int? mc, mr;
    await tester.pumpWidget(_host(EditableCanvas(
      template: _tpl(const [
        Cell(id: 'a', col: 0, row: 0, colSpan: 1, type: 'field',
            props: {'label': 'L', 'key': 'k'}),
      ]),
      registry: buildDefaultRegistry(),
      selectedId: 'a',
      onSelect: (_) {},
      onMove: (id, c, r) { mc = c; mr = r; },
      onSpan: (_, __, ___) {},
      onResizeCol: (_, __) {},
      onResizeRow: (_, __) {},
    )));
    // drag from inside cell 'a' (5,5) to (110,95)px -> col 3 (105..140), row 3 (90..120)
    await tester.dragFrom(const Offset(5, 5), const Offset(105, 90));
    expect([mc, mr], [3, 3]);
  });

  testWidgets('dragging the right span handle reports a larger colSpan',
      (tester) async {
    int? cs;
    await tester.pumpWidget(_host(EditableCanvas(
      template: _tpl(const [
        Cell(id: 'a', col: 0, row: 0, colSpan: 1, type: 'field',
            props: {'label': 'L', 'key': 'k'}),
      ]),
      registry: buildDefaultRegistry(),
      selectedId: 'a',
      onSelect: (_) {},
      onMove: (_, __, ___) {},
      onSpan: (id, colSpan, rowSpan) => cs = colSpan,
      onResizeCol: (_, __) {},
      onResizeRow: (_, __) {},
    )));
    // right handle sits at the cell's right edge (x ~35, y ~15). Drag to x ~110 (col 3) -> colSpan 4
    await tester.drag(
        find.byKey(const ValueKey('span-right')), const Offset(80, 0));
    expect(cs, 4);
  });

  testWidgets('dragging the bottom span handle reports a larger rowSpan',
      (tester) async {
    int? rs;
    await tester.pumpWidget(_host(EditableCanvas(
      template: _tpl(const [
        Cell(id: 'a', col: 0, row: 0, colSpan: 1, type: 'field',
            props: {'label': 'L', 'key': 'k'}),
      ]),
      registry: buildDefaultRegistry(),
      selectedId: 'a',
      onSelect: (_) {},
      onMove: (_, __, ___) {},
      onSpan: (id, colSpan, rowSpan) => rs = rowSpan,
      onResizeCol: (_, __) {},
      onResizeRow: (_, __) {},
    )));
    // bottom handle at cell bottom (y~30). drag down to y~90 (row 3) -> rowSpan 4
    await tester.drag(
        find.byKey(const ValueKey('span-bottom')), const Offset(0, 60));
    expect(rs, 4);
  });

  testWidgets('dragging a column edge handle reports an accumulated mm delta',
      (tester) async {
    int? boundary;
    var total = 0.0;
    await tester.pumpWidget(_host(EditableCanvas(
      template: _tpl(const []),
      registry: buildDefaultRegistry(),
      selectedId: null,
      onSelect: (_) {},
      onMove: (_, __, ___) {},
      onSpan: (_, __, ___) {},
      onResizeCol: (b, d) { boundary = b; total += d; },
      onResizeRow: (_, __) {},
    )));
    await tester.drag(
        find.byKey(const ValueKey('col-handle-1')), const Offset(20, 0));
    expect(boundary, 1);
    expect(total, closeTo(20, 1));
  });
}
