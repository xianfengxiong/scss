import '../model/cell.dart';
import '../model/grid_frame.dart';
import '../model/rect_mm.dart';

double _sum(List<double> xs, int start, int end) {
  var s = 0.0;
  for (var i = start; i < end; i++) {
    s += xs[i];
  }
  return s;
}

/// The mm rectangle a [cell] occupies inside [grid], from track prefix sums.
/// Shared by builder, fill and PDF so all three are pixel-identical (WYSIWYG).
RectMm cellRectMm(GridFrame grid, Cell cell) {
  final left = grid.xMm + _sum(grid.colWidthsMm, 0, cell.col);
  final top = grid.yMm + _sum(grid.rowHeightsMm, 0, cell.row);
  final width = _sum(grid.colWidthsMm, cell.col, cell.col + cell.colSpan);
  final height = _sum(grid.rowHeightsMm, cell.row, cell.row + cell.rowSpan);
  return RectMm(leftMm: left, topMm: top, widthMm: width, heightMm: height);
}
