import '../controls/registry.dart';
import '../grid/tracks.dart';
import '../grid/validation.dart';
import '../model/cell.dart';
import '../model/template.dart';

/// The cell covering grid coordinate (col,row), or null if that cell is empty.
Cell? cellAtCoord(Template t, int col, int row) {
  for (final c in t.cells) {
    if (col >= c.col &&
        col < c.col + c.colSpan &&
        row >= c.row &&
        row < c.row + c.rowSpan) {
      return c;
    }
  }
  return null;
}

/// The first grid row with no cell on it, or null if every row is occupied.
int? firstFreeRow(Template t) {
  for (var row = 0; row < t.grid.rows; row++) {
    var free = true;
    for (var col = 0; col < t.grid.cols; col++) {
      if (cellAtCoord(t, col, row) != null) {
        free = false;
        break;
      }
    }
    if (free) return row;
  }
  return null;
}

Template addCell(Template t, Cell c) =>
    t.copyWith(cells: [...t.cells, c]);

Template removeCell(Template t, String id) =>
    t.copyWith(cells: t.cells.where((c) => c.id != id).toList());

Template updateCell(Template t, String id, Cell Function(Cell) f) =>
    t.copyWith(cells: t.cells.map((c) => c.id == id ? f(c) : c).toList());

/// Set the column count (uniform new columns). Returns null if growing would
/// push the frame past the A4 right edge.
Template? setCols(Template t, int cols) {
  if (cols < 1) return null;
  var widths = List<double>.from(t.grid.colWidthsMm);
  while (widths.length < cols) {
    final w = widths.isNotEmpty ? widths.last : 15.0;
    final next = addTrack(widths, w, t.grid.xMm, t.page.widthMm);
    if (next == null) return null;
    widths = next;
  }
  while (widths.length > cols) {
    widths = removeTrack(widths, widths.length - 1);
  }
  return t.copyWith(grid: t.grid.copyWith(colWidthsMm: widths));
}

/// Set the row count (uniform new rows). Returns null if growing would push the
/// frame past the A4 bottom edge.
Template? setRows(Template t, int rows) {
  if (rows < 1) return null;
  var heights = List<double>.from(t.grid.rowHeightsMm);
  while (heights.length < rows) {
    final h = heights.isNotEmpty ? heights.last : 8.0;
    final next = addTrack(heights, h, t.grid.yMm, t.page.heightMm);
    if (next == null) return null;
    heights = next;
  }
  while (heights.length > rows) {
    heights = removeTrack(heights, heights.length - 1);
  }
  return t.copyWith(grid: t.grid.copyWith(rowHeightsMm: heights));
}

/// Keep the grid frame horizontally centered on its page: xMm is derived
/// from the total column width, so the side margins stay symmetric as
/// columns are added, removed, or resized. Vertically the frame stays put —
/// rows grow downward from the top margin by design. A frame wider than the
/// page passes through unchanged (the add/resize guards reject it).
Template centerGridX(Template t) {
  final x = (t.page.widthMm - t.grid.frameWidthMm) / 2;
  if (x < 0 || (x - t.grid.xMm).abs() < 1e-9) return t;
  return t.copyWith(grid: t.grid.copyWith(xMm: x));
}

/// True if [t] is a valid layout (no overlap, no out-of-bounds cells).
bool isValid(Template t) => validateLayout(t).isEmpty;

/// The first empty grid cell in row-major order, or null if the grid is full.
({int col, int row})? firstFreeCell(Template t) {
  for (var row = 0; row < t.grid.rows; row++) {
    for (var col = 0; col < t.grid.cols; col++) {
      if (cellAtCoord(t, col, row) == null) return (col: col, row: row);
    }
  }
  return null;
}

/// Number of consecutive empty columns starting at (col,row), going right until
/// an occupied cell or the grid's right edge. 0 if (col,row) itself is occupied.
int freeRunWidth(Template t, int col, int row) {
  var w = 0;
  for (var c = col; c < t.grid.cols; c++) {
    if (cellAtCoord(t, c, row) != null) break;
    w++;
  }
  return w;
}

/// Move the cell [id] so its top-left is at grid coordinate (col,row), clamped
/// so the cell (with its current span) stays inside the grid — e.g. a full-width
/// cell can only change rows, never slide off the right edge.
Template moveCell(Template t, String id, int col, int row) =>
    updateCell(t, id, (c) {
      final maxCol = t.grid.cols - c.colSpan;
      final maxRow = t.grid.rows - c.rowSpan;
      return c.copyWith(
        col: col.clamp(0, maxCol < 0 ? 0 : maxCol),
        row: row.clamp(0, maxRow < 0 ? 0 : maxRow),
      );
    });

/// Set the cell [id]'s column and row span.
Template setSpan(Template t, String id, int colSpan, int rowSpan) =>
    updateCell(t, id, (c) => c.copyWith(colSpan: colSpan, rowSpan: rowSpan));

/// A data key not already used by any cell in [t]. Returns [base] if free, else
/// the first free `${base}_$n` (n from 1). Used when placing a value control so
/// keys never collide in the survey data map.
String uniqueKey(Template t, String base) {
  final used = t.cells
      .map((c) => c.props['key'])
      .whereType<String>()
      .toSet();
  if (!used.contains(base)) return base;
  var n = 1;
  while (used.contains('${base}_$n')) {
    n++;
  }
  return '${base}_$n';
}

/// After a geometry edit, let the cell's control restore its internal
/// invariant (default no-op for controls without a `reconcile` override).
Template reconcileCell(Template t, String id, ControlRegistry r) =>
    updateCell(t, id, (c) => r.specFor(c.type)?.reconcile(c) ?? c);

/// Sync a cell's rowSpan to its control's `requiredRowSpan` (when the control
/// declares one), e.g. after the property editor changed the device-row list.
Template syncRowSpan(Template t, String id, ControlRegistry r) =>
    updateCell(t, id, (c) {
      final want = r.specFor(c.type)?.requiredRowSpan(c);
      return want == null ? c : c.copyWith(rowSpan: want);
    });
