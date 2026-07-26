import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/model/cell.dart';
import 'package:scss_grid/model/template.dart';
import 'package:scss_grid/model/grid_frame.dart';
import 'package:scss_grid/builder/editor_ops.dart';

Template _tpl(List<Cell> cells, {int cols = 4, int rows = 4}) => Template(
      id: 't',
      name: 'n',
      page: const PageSize.a4(),
      pages: [
        TemplatePage(
          grid: GridFrame.uniform(
              xMm: 5,
              yMm: 5,
              cols: cols,
              rows: rows,
              colWidthMm: 20,
              rowHeightMm: 8),
          cells: cells,
        ),
      ],
    );

void main() {
  test('cellAtCoord finds the covering cell or null', () {
    final t = _tpl(const [
      Cell(id: 'a', col: 0, row: 0, colSpan: 2, rowSpan: 2, type: 'text'),
    ]);
    expect(cellAtCoord(t.pages[0], 1, 1)!.id, 'a');
    expect(cellAtCoord(t.pages[0], 3, 3), isNull);
  });

  test('firstFreeRow returns the first row with no cells', () {
    final t = _tpl(const [
      Cell(id: 'a', col: 0, row: 0, colSpan: 4, type: 'text'),
    ]);
    expect(firstFreeRow(t.pages[0]), 1);
  });

  test('addCell / removeCell / updateCell are pure transforms', () {
    var p = _tpl(const []).pages[0];
    p = addCell(p, const Cell(id: 'x', col: 0, row: 0, type: 'title'));
    expect(p.cells.single.id, 'x');
    p = updateCell(p, 'x', (c) => c.copyWith(props: {'text': 'Hi'}));
    expect(p.cells.single.props['text'], 'Hi');
    p = removeCell(p, 'x');
    expect(p.cells, isEmpty);
  });

  test('setCols grows/shrinks within A4 and rejects overflow', () {
    final t = _tpl(const []); // cols 4 * 20mm = 80, x 5 -> fits
    expect(setCols(t.pages[0], t.page, 6)!.grid.cols, 6);
    expect(setCols(t.pages[0], t.page, 2)!.grid.cols, 2);
    // 200 cols * 20mm would blow past 210mm page width
    expect(setCols(t.pages[0], t.page, 200), isNull);
  });

  test('setRows grows/shrinks within A4', () {
    final t = _tpl(const []);
    expect(setRows(t.pages[0], t.page, 6)!.grid.rows, 6);
    expect(setRows(t.pages[0], t.page, 2)!.grid.rows, 2);
    expect(setRows(t.pages[0], t.page, 500), isNull);
  });

  test('isValid reflects validateLayout', () {
    final ok = _tpl(const [Cell(id: 'a', col: 0, row: 0, type: 'text')]);
    final bad = _tpl(const [
      Cell(id: 'a', col: 0, row: 0, colSpan: 2, type: 'text'),
      Cell(id: 'b', col: 1, row: 0, colSpan: 2, type: 'text'),
    ]);
    expect(isValid(ok), isTrue);
    expect(isValid(bad), isFalse);
  });
}
