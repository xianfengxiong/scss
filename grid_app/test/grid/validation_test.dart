import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/model/template.dart';
import 'package:scss_grid/model/grid_frame.dart';
import 'package:scss_grid/model/cell.dart';
import 'package:scss_grid/grid/validation.dart';

Template _tpl(List<Cell> cells) => Template(
      id: 't',
      name: 'n',
      page: const PageSize.a4(),
      pages: [
        TemplatePage(
          grid: GridFrame.uniform(
              xMm: 0, yMm: 0, cols: 4, rows: 4, colWidthMm: 10, rowHeightMm: 10),
          cells: cells,
        ),
      ],
    );

void main() {
  test('valid non-overlapping in-bounds layout has no violations', () {
    final v = validateLayout(_tpl(const [
      Cell(id: 'a', col: 0, row: 0, colSpan: 2, type: 'x'),
      Cell(id: 'b', col: 2, row: 0, colSpan: 2, type: 'x'),
    ]));
    expect(v, isEmpty);
  });

  test('out-of-bounds cell is flagged', () {
    final v = validateLayout(_tpl(const [
      Cell(id: 'a', col: 3, row: 0, colSpan: 2, type: 'x'), // 3+2 > 4
    ]));
    expect(v.map((e) => e.cellId), contains('a'));
    expect(v.single.reason, contains('out-of-bounds'));
  });

  test('overlapping cells are flagged', () {
    final v = validateLayout(_tpl(const [
      Cell(id: 'a', col: 0, row: 0, colSpan: 2, type: 'x'),
      Cell(id: 'b', col: 1, row: 0, colSpan: 2, type: 'x'),
    ]));
    expect(v.map((e) => e.cellId), contains('b'));
    expect(v.any((e) => e.reason.contains('overlap')), isTrue);
  });

  test('LayoutViolation has value equality', () {
    expect(const LayoutViolation('a', 'overlap'),
        const LayoutViolation('a', 'overlap'));
    expect(const LayoutViolation('a', 'overlap'),
        isNot(const LayoutViolation('b', 'overlap')));
  });
}
