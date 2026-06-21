import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/model/grid_frame.dart';
import 'package:scss_grid/grid/grid_resize.dart';

void main() {
  final g = GridFrame.uniform(
      xMm: 0, yMm: 0, cols: 3, rows: 3, colWidthMm: 20, rowHeightMm: 10);

  test('resizeColBoundary moves a vertical line, preserving frame width', () {
    final r = resizeColBoundary(g, 1, 5); // boundary between col 0 and 1
    expect(r.colWidthsMm, [25, 15, 20]);
    expect(r.frameWidthMm, g.frameWidthMm); // total preserved
    expect(r.cols, 3);
  });

  test('resizeRowBoundary moves a horizontal line, preserving frame height', () {
    final r = resizeRowBoundary(g, 2, -3); // boundary between row 1 and 2
    expect(r.rowHeightsMm, [10, 7, 13]);
    expect(r.frameHeightMm, g.frameHeightMm);
  });
}
