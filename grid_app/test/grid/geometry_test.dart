import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/model/rect_mm.dart';
import 'package:scss_grid/model/grid_frame.dart';
import 'package:scss_grid/model/cell.dart';
import 'package:scss_grid/grid/geometry.dart';

void main() {
  final grid = GridFrame.uniform(
      xMm: 10, yMm: 20, cols: 4, rows: 3, colWidthMm: 25, rowHeightMm: 10);

  test('single cell rect at origin of grid', () {
    final r = cellRectMm(grid, const Cell(id: 'a', col: 0, row: 0, type: 'x'));
    expect(r, const RectMm(leftMm: 10, topMm: 20, widthMm: 25, heightMm: 10));
  });

  test('spanning cell sums tracks and offsets by prior tracks', () {
    final r = cellRectMm(
        grid, const Cell(id: 'b', col: 1, row: 1, colSpan: 2, rowSpan: 2, type: 'x'));
    // left = 10 + 25, top = 20 + 10, width = 25+25, height = 10+10
    expect(r, const RectMm(leftMm: 35, topMm: 30, widthMm: 50, heightMm: 20));
  });
}
