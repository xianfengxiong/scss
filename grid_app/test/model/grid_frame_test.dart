import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/model/grid_frame.dart';

void main() {
  test('uniform builds equal tracks and derives frame size', () {
    final g = GridFrame.uniform(
        xMm: 10, yMm: 12, cols: 3, rows: 4, colWidthMm: 20, rowHeightMm: 8);
    expect(g.colWidthsMm, [20, 20, 20]);
    expect(g.rowHeightsMm, [8, 8, 8, 8]);
    expect(g.frameWidthMm, 60);
    expect(g.frameHeightMm, 32);
  });

  test('json round-trips', () {
    final g = GridFrame.uniform(
        xMm: 5, yMm: 6, cols: 2, rows: 2, colWidthMm: 10, rowHeightMm: 9);
    final back = GridFrame.fromJson(g.toJson());
    expect(back.toJson(), g.toJson());
  });
}
