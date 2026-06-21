import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/model/cell.dart';
import 'package:scss_grid/model/template.dart';
import 'package:scss_grid/model/grid_frame.dart';
import 'package:scss_grid/builder/editor_ops.dart';

Template _tpl(List<Cell> cells, {int cols = 4, int rows = 4}) => Template(
      id: 't',
      name: 'n',
      page: const PageSize.a4(),
      grid: GridFrame.uniform(
          xMm: 5, yMm: 5, cols: cols, rows: rows, colWidthMm: 20, rowHeightMm: 8),
      cells: cells,
    );

void main() {
  test('cellAtCoord finds the covering cell or null', () {
    final t = _tpl(const [
      Cell(id: 'a', col: 0, row: 0, colSpan: 2, rowSpan: 2, type: 'field'),
    ]);
    expect(cellAtCoord(t, 1, 1)!.id, 'a');
    expect(cellAtCoord(t, 3, 3), isNull);
  });

  test('firstFreeRow returns the first row with no cells', () {
    final t = _tpl(const [
      Cell(id: 'a', col: 0, row: 0, colSpan: 4, type: 'field'),
    ]);
    expect(firstFreeRow(t), 1);
  });

  test('addCell / removeCell / updateCell are pure transforms', () {
    var t = _tpl(const []);
    t = addCell(t, const Cell(id: 'x', col: 0, row: 0, type: 'title'));
    expect(t.cells.single.id, 'x');
    t = updateCell(t, 'x', (c) => c.copyWith(props: {'text': 'Hi'}));
    expect(t.cells.single.props['text'], 'Hi');
    t = removeCell(t, 'x');
    expect(t.cells, isEmpty);
  });

  test('setCols grows/shrinks within A4 and rejects overflow', () {
    final t = _tpl(const []); // cols 4 * 20mm = 80, x 5 -> fits
    expect(setCols(t, 6)!.grid.cols, 6);
    expect(setCols(t, 2)!.grid.cols, 2);
    // 200 cols * 20mm would blow past 210mm page width
    expect(setCols(t, 200), isNull);
  });

  test('setRows grows/shrinks within A4', () {
    final t = _tpl(const []);
    expect(setRows(t, 6)!.grid.rows, 6);
    expect(setRows(t, 2)!.grid.rows, 2);
    expect(setRows(t, 500), isNull);
  });

  test('isValid reflects validateLayout', () {
    final ok = _tpl(const [Cell(id: 'a', col: 0, row: 0, type: 'field')]);
    final bad = _tpl(const [
      Cell(id: 'a', col: 0, row: 0, colSpan: 2, type: 'field'),
      Cell(id: 'b', col: 1, row: 0, colSpan: 2, type: 'field'),
    ]);
    expect(isValid(ok), isTrue);
    expect(isValid(bad), isFalse);
  });
}
