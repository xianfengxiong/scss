import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/builder/canvas_metrics.dart';

void main() {
  test('pageScale is px per mm', () {
    expect(pageScale(420, 210), 2.0);
    expect(pageScale(210, 210), 1.0);
  });

  test('kCanvasPad is the shared canvas padding', () {
    expect(kCanvasPad, 12);
  });
}
