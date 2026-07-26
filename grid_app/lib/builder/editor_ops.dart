import '../controls/registry.dart';
import '../grid/tracks.dart';
import '../grid/validation.dart';
import '../model/cell.dart';
import '../model/template.dart';

// Page-level edits take and return a [TemplatePage] (plus the shared
// [PageSize] where the page bounds matter); the builder wraps the result back
// into the template with `Template.withPage`. Cross-page invariants (unique
// data keys, whole-template validity, page management) stay Template-level.

/// The cell covering grid coordinate (col,row), or null if that cell is empty.
Cell? cellAtCoord(TemplatePage p, int col, int row) {
  for (final c in p.cells) {
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
int? firstFreeRow(TemplatePage p) {
  for (var row = 0; row < p.grid.rows; row++) {
    var free = true;
    for (var col = 0; col < p.grid.cols; col++) {
      if (cellAtCoord(p, col, row) != null) {
        free = false;
        break;
      }
    }
    if (free) return row;
  }
  return null;
}

TemplatePage addCell(TemplatePage p, Cell c) =>
    p.copyWith(cells: [...p.cells, c]);

TemplatePage removeCell(TemplatePage p, String id) =>
    p.copyWith(cells: p.cells.where((c) => c.id != id).toList());

TemplatePage updateCell(TemplatePage p, String id, Cell Function(Cell) f) =>
    p.copyWith(cells: p.cells.map((c) => c.id == id ? f(c) : c).toList());

/// Set the column count (uniform new columns). Returns null if growing would
/// push the frame past the page's right edge.
TemplatePage? setCols(TemplatePage p, PageSize page, int cols) {
  if (cols < 1) return null;
  var widths = List<double>.from(p.grid.colWidthsMm);
  while (widths.length < cols) {
    final w = widths.isNotEmpty ? widths.last : 15.0;
    final next = addTrack(widths, w, p.grid.xMm, page.widthMm);
    if (next == null) return null;
    widths = next;
  }
  while (widths.length > cols) {
    widths = removeTrack(widths, widths.length - 1);
  }
  return p.copyWith(grid: p.grid.copyWith(colWidthsMm: widths));
}

/// Set the row count (uniform new rows). Returns null if growing would push the
/// frame past the page's bottom edge.
TemplatePage? setRows(TemplatePage p, PageSize page, int rows) {
  if (rows < 1) return null;
  var heights = List<double>.from(p.grid.rowHeightsMm);
  while (heights.length < rows) {
    final h = heights.isNotEmpty ? heights.last : 8.0;
    final next = addTrack(heights, h, p.grid.yMm, page.heightMm);
    if (next == null) return null;
    heights = next;
  }
  while (heights.length > rows) {
    heights = removeTrack(heights, heights.length - 1);
  }
  return p.copyWith(grid: p.grid.copyWith(rowHeightsMm: heights));
}

/// Keep the grid frame horizontally centered on its page: xMm is derived
/// from the total column width, so the side margins stay symmetric as
/// columns are added, removed, or resized. Vertically the frame stays put —
/// rows grow downward from the top margin by design. A frame wider than the
/// page passes through unchanged (the add/resize guards reject it).
TemplatePage centerGridX(TemplatePage p, PageSize page) {
  final x = (page.widthMm - p.grid.frameWidthMm) / 2;
  if (x < 0 || (x - p.grid.xMm).abs() < 1e-9) return p;
  return p.copyWith(grid: p.grid.copyWith(xMm: x));
}

/// True if [t] is a valid layout (no overlap, no out-of-bounds cells, on any
/// page).
bool isValid(Template t) => validateLayout(t).isEmpty;

/// The first empty grid cell in row-major order, or null if the grid is full.
({int col, int row})? firstFreeCell(TemplatePage p) {
  for (var row = 0; row < p.grid.rows; row++) {
    for (var col = 0; col < p.grid.cols; col++) {
      if (cellAtCoord(p, col, row) == null) return (col: col, row: row);
    }
  }
  return null;
}

/// Number of consecutive empty columns starting at (col,row), going right until
/// an occupied cell or the grid's right edge. 0 if (col,row) itself is occupied.
int freeRunWidth(TemplatePage p, int col, int row) {
  var w = 0;
  for (var c = col; c < p.grid.cols; c++) {
    if (cellAtCoord(p, c, row) != null) break;
    w++;
  }
  return w;
}

/// Move the cell [id] so its top-left is at grid coordinate (col,row), clamped
/// so the cell (with its current span) stays inside the grid — e.g. a full-width
/// cell can only change rows, never slide off the right edge.
TemplatePage moveCell(TemplatePage p, String id, int col, int row) =>
    updateCell(p, id, (c) {
      final maxCol = p.grid.cols - c.colSpan;
      final maxRow = p.grid.rows - c.rowSpan;
      return c.copyWith(
        col: col.clamp(0, maxCol < 0 ? 0 : maxCol),
        row: row.clamp(0, maxRow < 0 ? 0 : maxRow),
      );
    });

/// Set the cell [id]'s column and row span.
TemplatePage setSpan(TemplatePage p, String id, int colSpan, int rowSpan) =>
    updateCell(p, id, (c) => c.copyWith(colSpan: colSpan, rowSpan: rowSpan));

/// A data key not already used by any cell on any page of [t]. Returns [base]
/// if free, else the first free `${base}_$n` (n from 1). Survey answers are
/// one map for the whole template, so keys must be unique across pages.
String uniqueKey(Template t, String base) {
  final used =
      t.allCells.map((c) => c.props['key']).whereType<String>().toSet();
  if (!used.contains(base)) return base;
  var n = 1;
  while (used.contains('${base}_$n')) {
    n++;
  }
  return '${base}_$n';
}

/// After a geometry edit, let the cell's control restore its internal
/// invariant (default no-op for controls without a `reconcile` override).
TemplatePage reconcileCell(TemplatePage p, String id, ControlRegistry r) =>
    updateCell(p, id, (c) => r.specFor(c.type)?.reconcile(c) ?? c);

/// Sync a cell's rowSpan to its control's `requiredRowSpan` (when the control
/// declares one), e.g. after the property editor changed the device-row list.
TemplatePage syncRowSpan(TemplatePage p, String id, ControlRegistry r) =>
    updateCell(p, id, (c) {
      final want = r.specFor(c.type)?.requiredRowSpan(c);
      return want == null ? c : c.copyWith(rowSpan: want);
    });

/// A new page appended after [index], inheriting that page's grid structure
/// (rows/cols/track sizes) but empty of controls — continuity without
/// duplicated content.
Template addPageAfter(Template t, int index) {
  final source = t.pages[index];
  final next = [...t.pages];
  next.insert(index + 1, TemplatePage(grid: source.grid, cells: const []));
  return t.copyWith(pages: next);
}

/// Remove page [index]. Refused (returns null) for the last remaining page.
Template? removePage(Template t, int index) {
  if (t.pages.length <= 1) return null;
  final next = [...t.pages]..removeAt(index);
  return t.copyWith(pages: next);
}