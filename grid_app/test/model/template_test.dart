import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/model/template.dart';
import 'package:scss_grid/model/grid_frame.dart';
import 'package:scss_grid/model/cell.dart';

void main() {
  test('template round-trips through json', () {
    final t = Template(
      id: 't1',
      name: 'Survey',
      page: const PageSize.a4(),
      grid: GridFrame.uniform(
          xMm: 10, yMm: 10, cols: 12, rows: 4, colWidthMm: 15, rowHeightMm: 8),
      cells: [
        const Cell(id: 'c1', col: 0, row: 0, colSpan: 12, type: 'title',
            props: {'text': 'Site Survey'}),
      ],
    );
    final back = Template.fromJson(t.toJson());
    expect(back.toJson(), t.toJson());
    expect(back.page.widthMm, 210);
    expect(back.page.heightMm, 297);
    expect(back.cells.single.colSpan, 12);
  });
}
