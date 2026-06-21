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

  test('copyWith(colWidthsMm:) derives cols from new track lengths', () {
    final g = GridFrame.uniform(
        xMm: 1, yMm: 2, cols: 2, rows: 3, colWidthMm: 10, rowHeightMm: 5);
    final modified = g.copyWith(colWidthsMm: [10, 20, 30]);
    expect(modified.cols, 3);
    expect(modified.frameWidthMm, 60);
    expect(modified.xMm, 1);
    expect(modified.yMm, 2);
    expect(modified.rows, 3);
    expect(modified.rowHeightsMm, [5, 5, 5]);
  });

  test('copyWith(xMm:) preserves cols, rows, and both track lists', () {
    final g = GridFrame.uniform(
        xMm: 10, yMm: 12, cols: 3, rows: 4, colWidthMm: 20, rowHeightMm: 8);
    final modified = g.copyWith(xMm: 5);
    expect(modified.cols, 3);
    expect(modified.rows, 4);
    expect(modified.xMm, 5);
    expect(modified.yMm, 12);
    expect(modified.colWidthsMm, [20, 20, 20]);
    expect(modified.rowHeightsMm, [8, 8, 8, 8]);
  });
}
