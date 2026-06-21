import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/model/cell.dart';
import 'package:scss_grid/model/template.dart';
import 'package:scss_grid/model/grid_frame.dart';
import 'package:scss_grid/builder/editor_ops.dart';

Template _tpl(List<Cell> cells) => Template(
      id: 't',
      name: 'n',
      page: const PageSize.a4(),
      grid: GridFrame.uniform(
          xMm: 0, yMm: 0, cols: 6, rows: 6, colWidthMm: 20, rowHeightMm: 8),
      cells: cells,
    );

void main() {
  test('moveCell sets new col/row, leaving spans intact', () {
    final t = _tpl(const [
      Cell(id: 'a', col: 0, row: 0, colSpan: 2, rowSpan: 1, type: 'field'),
    ]);
    final m = moveCell(t, 'a', 3, 2);
    final c = m.cells.single;
    expect([c.col, c.row, c.colSpan, c.rowSpan], [3, 2, 2, 1]);
  });

  test('setSpan sets colSpan/rowSpan, leaving position intact', () {
    final t = _tpl(const [
      Cell(id: 'a', col: 1, row: 1, type: 'field'),
    ]);
    final s = setSpan(t, 'a', 3, 2);
    final c = s.cells.single;
    expect([c.col, c.row, c.colSpan, c.rowSpan], [1, 1, 3, 2]);
  });
}
