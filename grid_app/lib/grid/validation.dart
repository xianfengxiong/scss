import '../model/template.dart';

class LayoutViolation {
  final String cellId;
  final String reason;
  const LayoutViolation(this.cellId, this.reason);

  @override
  bool operator ==(Object other) =>
      other is LayoutViolation &&
      other.cellId == cellId &&
      other.reason == reason;

  @override
  int get hashCode => Object.hash(cellId, reason);

  @override
  String toString() => 'LayoutViolation($cellId, $reason)';
}

/// Returns one violation per offending cell. Empty list means a valid layout:
/// every cell is in-bounds and no two cells overlap.
List<LayoutViolation> validateLayout(Template t) {
  final violations = <LayoutViolation>[];
  final occupied = <String>{}; // "col,row" units already taken

  for (final c in t.cells) {
    final inBounds = c.col >= 0 &&
        c.row >= 0 &&
        c.colSpan >= 1 &&
        c.rowSpan >= 1 &&
        c.col + c.colSpan <= t.grid.cols &&
        c.row + c.rowSpan <= t.grid.rows;
    if (!inBounds) {
      violations.add(LayoutViolation(c.id, 'out-of-bounds'));
      continue; // don't mark occupancy for an out-of-bounds cell
    }

    var overlaps = false;
    final claimed = <String>[];
    for (var x = c.col; x < c.col + c.colSpan; x++) {
      for (var y = c.row; y < c.row + c.rowSpan; y++) {
        final key = '$x,$y';
        if (occupied.contains(key)) {
          overlaps = true;
        } else {
          claimed.add(key);
        }
      }
    }
    if (overlaps) {
      violations.add(LayoutViolation(c.id, 'overlap'));
    }
    occupied.addAll(claimed);
  }
  return violations;
}
