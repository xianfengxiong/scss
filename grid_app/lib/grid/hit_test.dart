import '../model/grid_frame.dart';

/// The (col,row) grid coordinate the point [xMm],[yMm] falls in, or null if the
/// point is outside the frame. A track boundary belongs to the cell to its
/// right / below (half-open intervals), matching `cellRectMm`.
({int col, int row})? cellCoordAtMm(GridFrame g, double xMm, double yMm) {
  if (xMm < g.xMm || yMm < g.yMm) return null;
  if (xMm >= g.xMm + g.frameWidthMm || yMm >= g.yMm + g.frameHeightMm) {
    return null;
  }
  var acc = g.xMm;
  var col = 0;
  while (col < g.cols && xMm >= acc + g.colWidthsMm[col]) {
    acc += g.colWidthsMm[col];
    col++;
  }
  acc = g.yMm;
  var row = 0;
  while (row < g.rows && yMm >= acc + g.rowHeightsMm[row]) {
    acc += g.rowHeightsMm[row];
    row++;
  }
  if (col >= g.cols || row >= g.rows) return null;
  return (col: col, row: row);
}
