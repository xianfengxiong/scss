import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/controls/multi_image_control.dart';
import 'package:scss_grid/model/cell.dart';

Cell _cell({int rows = 2, int cols = 3, int min = 3}) => Cell(
      id: 'm',
      col: 0,
      row: 0,
      colSpan: 6,
      rowSpan: 4,
      type: 'multiImage',
      props: {'key': 'photos', 'rows': rows, 'cols': cols, 'min': min},
    );

void main() {
  test('rowsForCount = ceil(count/cols), 0 → 0', () {
    expect(rowsForCount(0, 3), 0);
    expect(rowsForCount(1, 3), 1);
    expect(rowsForCount(3, 3), 1); // 第二行全空 → 1 行（占满整高）
    expect(rowsForCount(4, 3), 2); // 进入第二行 → 2 行
    expect(rowsForCount(6, 3), 2);
  });

  test('type, defaultProps, dataKey', () {
    final c = MultiImageControl();
    expect(c.type, 'multiImage');
    expect(c.defaultProps(),
        {'key': 'images', 'rows': 2, 'cols': 3, 'min': 3});
    expect(c.dataKey(_cell()), 'photos');
  });

  test('validate: <min, in-range, >cap', () {
    final c = MultiImageControl();
    expect(c.validate(_cell(), null), '至少 3 张，当前 0');
    expect(c.validate(_cell(), ['a', 'b']), '至少 3 张，当前 2');
    expect(c.validate(_cell(), ['a', 'b', 'c']), isNull);
    expect(c.validate(_cell(), ['a', 'b', 'c', 'd', 'e', 'f']), isNull);
    expect(c.validate(_cell(), ['a', 'b', 'c', 'd', 'e', 'f', 'g']),
        '最多 6 张，当前 7'); // cap = rows2*cols3 = 6
  });
}
