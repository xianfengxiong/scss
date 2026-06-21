import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/grid/tracks.dart';

void main() {
  test('moving a boundary preserves the total', () {
    final out = resizeBoundary([20, 20, 20], 1, 5);
    expect(out, [25, 15, 20]);
    expect(out.fold(0.0, (a, b) => a + b), 60);
  });

  test('clamps so neither adjacent track drops below minMm', () {
    final out = resizeBoundary([20, 20, 20], 1, 100, minMm: 5);
    // track[1] cannot go below 5, so max transferable = 15
    expect(out, [35, 5, 20]);
  });

  test('negative delta shifts the other way, still clamped', () {
    final out = resizeBoundary([20, 20, 20], 1, -100, minMm: 5);
    expect(out, [5, 35, 20]);
  });

  test('resizeBoundary throws RangeError on an invalid boundary index', () {
    expect(() => resizeBoundary([20, 20], 0, 5), throwsRangeError);
    expect(() => resizeBoundary([20, 20], 2, 5), throwsRangeError);
  });
}
