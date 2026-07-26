import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/model/cell.dart';
import 'package:scss_grid/model/grid_frame.dart';
import 'package:scss_grid/model/template.dart';

GridFrame _grid() => GridFrame.uniform(
    xMm: 15, yMm: 10, cols: 12, rows: 16, colWidthMm: 15, rowHeightMm: 8);

void main() {
  test('multi-page template round-trips through JSON', () {
    final t = Template(
      id: 'tpl_x',
      name: 'T',
      page: const PageSize.a4(),
      pages: [
        TemplatePage(grid: _grid(), cells: const [
          Cell(id: 'a', col: 0, row: 0, colSpan: 3, type: 'text',
              props: {'key': 'k1', 'hint': ''}),
        ]),
        TemplatePage(grid: _grid(), cells: const [
          Cell(id: 'b', col: 0, row: 0, colSpan: 3, type: 'text',
              props: {'key': 'k2', 'hint': ''}),
        ]),
      ],
    );
    final back = Template.fromJson(t.toJson());
    expect(back.pages.length, 2);
    expect(back.pages[0].cells.single.id, 'a');
    expect(back.pages[1].cells.single.id, 'b');
    expect(back.allCells.length, 2);
  });

  test('legacy single-page JSON (top-level grid/cells) reads as one page', () {
    // The exact shape templates were saved in before multi-page existed.
    final legacy = {
      'id': 'tpl_old',
      'name': 'Old',
      'page': {'widthMm': 210.0, 'heightMm': 297.0},
      'grid': _grid().toJson(),
      'cells': [
        const Cell(id: 'a', col: 0, row: 0, colSpan: 3, type: 'text',
                props: {'key': 'k', 'hint': ''})
            .toJson(),
      ],
    };
    final t = Template.fromJson(legacy);
    expect(t.pages.length, 1);
    expect(t.pages[0].cells.single.id, 'a');
    expect(t.pages[0].grid.cols, 12);
    // Re-serializing writes the new format.
    expect(t.toJson().containsKey('pages'), isTrue);
    expect(t.toJson().containsKey('grid'), isFalse);
  });

  test('withPage replaces exactly one page', () {
    final t = Template(
      id: 't',
      name: 'T',
      page: const PageSize.a4(),
      pages: [
        TemplatePage(grid: _grid(), cells: const []),
        TemplatePage(grid: _grid(), cells: const []),
      ],
    );
    final updated = t.withPage(
        1,
        TemplatePage(grid: _grid(), cells: const [
          Cell(id: 'x', col: 0, row: 0, colSpan: 1, type: 'title',
              props: {'text': 'X'}),
        ]));
    expect(updated.pages[0].cells, isEmpty);
    expect(updated.pages[1].cells.single.id, 'x');
    expect(t.pages[1].cells, isEmpty, reason: 'original untouched');
  });
}
