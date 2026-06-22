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
  test('returns the base when unused', () {
    expect(uniqueKey(_tpl(const []), 'text'), 'text');
  });

  test('suffixes _1 when only the base is taken', () {
    final t = _tpl(const [
      Cell(id: 'a', col: 0, row: 0, type: 'text', props: {'key': 'text'}),
    ]);
    expect(uniqueKey(t, 'text'), 'text_1');
  });

  test('suffixes to avoid collisions', () {
    final t = _tpl(const [
      Cell(id: 'a', col: 0, row: 0, type: 'text', props: {'key': 'text'}),
      Cell(id: 'b', col: 0, row: 1, type: 'text', props: {'key': 'text_1'}),
    ]);
    expect(uniqueKey(t, 'text'), 'text_2');
  });
}
