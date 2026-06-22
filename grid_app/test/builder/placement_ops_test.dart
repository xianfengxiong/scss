import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/builder/editor_ops.dart';
import 'package:scss_grid/model/cell.dart';
import 'package:scss_grid/model/grid_frame.dart';
import 'package:scss_grid/model/template.dart';

Template _tpl(List<Cell> cells) => Template(
      id: 't',
      name: 'n',
      page: const PageSize.a4(),
      grid: GridFrame.uniform(
          xMm: 0, yMm: 0, cols: 6, rows: 4, colWidthMm: 20, rowHeightMm: 10),
      cells: cells,
    );

void main() {
  test('firstFreeCell is (0,0) on an empty grid', () {
    expect(firstFreeCell(_tpl(const [])), (col: 0, row: 0));
  });

  test('firstFreeCell skips occupied cells row-major', () {
    // A 3-wide cell on row 0 -> first free is (3,0).
    final t = _tpl(const [
      Cell(id: 'a', col: 0, row: 0, colSpan: 3, type: 'text'),
    ]);
    expect(firstFreeCell(t), (col: 3, row: 0));
  });

  test('firstFreeCell returns null when the grid is full', () {
    final t = _tpl(const [
      Cell(id: 'a', col: 0, row: 0, colSpan: 6, rowSpan: 4, type: 'text'),
    ]);
    expect(firstFreeCell(t), isNull);
  });

  test('freeRunWidth counts free columns to the right', () {
    // cols 0..2 occupied; from (3,0) there are 3 free cols (3,4,5).
    final t = _tpl(const [
      Cell(id: 'a', col: 0, row: 0, colSpan: 3, type: 'text'),
    ]);
    expect(freeRunWidth(t, 3, 0), 3);
    expect(freeRunWidth(t, 0, 0), 0); // (0,0) is occupied
    expect(freeRunWidth(t, 0, 1), 6); // empty row -> full width
  });

  test('freeRunWidth stops at the next occupied cell', () {
    // col 0 free, cols 2..3 occupied -> from (0,0) only 2 free (0,1).
    final t = _tpl(const [
      Cell(id: 'a', col: 2, row: 0, colSpan: 2, type: 'text'),
    ]);
    expect(freeRunWidth(t, 0, 0), 2);
  });
}
