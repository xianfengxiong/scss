import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/builder/border_layer.dart';
import 'package:scss_grid/grid/cell_borders.dart';

void main() {
  test('borderLineWidgets renders one Positioned per edge, centered', () {
    const edges = [
      GridEdge(vertical: true, atMm: 30, fromMm: 10, toMm: 20),
      GridEdge(vertical: false, atMm: 10, fromMm: 30, toMm: 70),
    ];
    final w = borderLineWidgets(edges, 2.0, thickness: 1.0);
    expect(w.length, 2);
    final vert = w[0] as Positioned;
    // vertical line at x=30mm*2 = 60, centered → left = 60 - 0.5 = 59.5; width = 1
    expect(vert.left, 59.5);
    expect(vert.width, 1.0);
    expect(vert.top, 20.0); // 10mm*2
    expect(vert.height, 20.0); // (20-10)*2
    final horiz = w[1] as Positioned;
    // horizontal at y=10mm*2=20, centered → top = 20 - 0.5 = 19.5; height = 1
    expect(horiz.top, 19.5);
    expect(horiz.height, 1.0);
    expect(horiz.left, 60.0); // 30mm*2
    expect(horiz.width, 80.0); // (70-30)*2
  });
}
