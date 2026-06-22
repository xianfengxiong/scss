import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/grid/cell_borders.dart';
import 'package:scss_grid/model/cell.dart';
import 'package:scss_grid/model/grid_frame.dart';
import 'package:scss_grid/model/template.dart';

Template _tpl(List<Cell> cells) => Template(
      id: 't',
      name: 'n',
      page: const PageSize.a4(),
      grid: GridFrame.uniform(
          xMm: 10, yMm: 10, cols: 4, rows: 4, colWidthMm: 20, rowHeightMm: 10),
      cells: cells,
    );

void main() {
  test('a single cell yields its 4 edges at the right mm positions', () {
    // cell at col1,row0, colSpan2 -> x 30..70mm, y 10..20mm
    final t = _tpl(const [
      Cell(id: 'a', col: 1, row: 0, colSpan: 2, type: 'text'),
    ]);
    final e = controlOutlineEdges(t);
    expect(e.length, 4);
    // left vertical at x=30, y 10..20
    expect(e.any((g) => g.vertical && g.atMm == 30 && g.fromMm == 10 && g.toMm == 20), isTrue);
    // right vertical at x=70
    expect(e.any((g) => g.vertical && g.atMm == 70 && g.fromMm == 10 && g.toMm == 20), isTrue);
    // top horizontal at y=10, x 30..70
    expect(e.any((g) => !g.vertical && g.atMm == 10 && g.fromMm == 30 && g.toMm == 70), isTrue);
    // bottom horizontal at y=20
    expect(e.any((g) => !g.vertical && g.atMm == 20 && g.fromMm == 30 && g.toMm == 70), isTrue);
  });

  test('adjacent cells share an edge coordinate (collapse precondition)', () {
    // grid xMm=10, colWidth=20: col0..1 spans x10..50, col2..3 spans x50..90
    // both cells have a vertical edge at x=50 (label's right == value's left)
    final t = _tpl(const [
      Cell(id: 'l', col: 0, row: 0, colSpan: 2, type: 'label'),
      Cell(id: 'v', col: 2, row: 0, colSpan: 2, type: 'text'),
    ]);
    final verticalsAt50 =
        controlOutlineEdges(t).where((g) => g.vertical && g.atMm == 50).toList();
    // label's right edge AND value's left edge — same coordinate (drawn as coincident lines)
    expect(verticalsAt50.length, 2);
  });

  test('empty template yields no edges', () {
    expect(controlOutlineEdges(_tpl(const [])), isEmpty);
  });
}
