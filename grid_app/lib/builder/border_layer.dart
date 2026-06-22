import 'package:flutter/widgets.dart';

import '../grid/cell_borders.dart';

/// Table-border colour and thickness for the cell border layer (canvas side).
const Color kCellBorderColor = Color(0xFF455A64);
const double kCellBorderPx = 1.0;

/// Render [edges] (mm) as fixed-thickness lines CENTERED on each boundary, at
/// [scale] px/mm. Coincident edges (shared by adjacent controls) draw at the
/// same place → single visible width (collapse).
List<Widget> borderLineWidgets(
  List<GridEdge> edges,
  double scale, {
  Color color = kCellBorderColor,
  double thickness = kCellBorderPx,
}) {
  final widgets = <Widget>[];
  for (final e in edges) {
    if (e.vertical) {
      widgets.add(Positioned(
        left: e.atMm * scale - thickness / 2,
        top: e.fromMm * scale,
        width: thickness,
        height: (e.toMm - e.fromMm) * scale,
        child: ColoredBox(color: color),
      ));
    } else {
      widgets.add(Positioned(
        left: e.fromMm * scale,
        top: e.atMm * scale - thickness / 2,
        width: (e.toMm - e.fromMm) * scale,
        height: thickness,
        child: ColoredBox(color: color),
      ));
    }
  }
  return widgets;
}
