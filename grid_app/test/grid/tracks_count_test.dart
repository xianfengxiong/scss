import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/grid/tracks.dart';

void main() {
  test('addTrack appends when it fits within the page', () {
    // offset 10 + sum 30 + new 8 = 48 <= 297
    final out = addTrack([10, 10, 10], 8, 10, 297);
    expect(out, [10, 10, 10, 8]);
  });

  test('addTrack returns null when it would exceed the page', () {
    // offset 290 + sum 5 + new 8 = 303 > 297
    final out = addTrack([5], 8, 290, 297);
    expect(out, isNull);
  });

  test('removeTrack drops the indexed track', () {
    expect(removeTrack([10, 20, 30], 1), [10, 30]);
  });

  test('addTrack allows an exact A4-boundary fit (no float rejection)', () {
    // offset 0 + sum 287 + new 10 = 297 == pageLimit -> must NOT be rejected
    expect(addTrack([287], 10, 0, 297), [287, 10]);
  });
}
