import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/model/grid_frame.dart';
import 'package:scss_grid/grid/hit_test.dart';

void main() {
  final g = GridFrame.uniform(
      xMm: 10, yMm: 20, cols: 4, rows: 3, colWidthMm: 25, rowHeightMm: 10);

  test('point inside the first cell maps to (0,0)', () {
    expect(cellCoordAtMm(g, 11, 21), (col: 0, row: 0));
  });

  test('point inside a later cell maps to its coord', () {
    // x: 10 + 25*2 = 60..85 is col 2; y: 20 + 10 = 30..40 is row 1
    expect(cellCoordAtMm(g, 70, 35), (col: 2, row: 1));
  });

  test('a track boundary belongs to the cell on its right/below', () {
    // x exactly 35 = start of col 1; y exactly 30 = start of row 1
    expect(cellCoordAtMm(g, 35, 30), (col: 1, row: 1));
  });

  test('point outside the frame is null', () {
    expect(cellCoordAtMm(g, 5, 5), isNull); // left/above
    expect(cellCoordAtMm(g, 200, 35), isNull); // right of frame
    expect(cellCoordAtMm(g, 70, 100), isNull); // below frame
  });
}
