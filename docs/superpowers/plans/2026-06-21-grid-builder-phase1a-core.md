# Grid Template Builder — Phase 1A (Core) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the pure, UI-free core of the A4 grid template builder — data model, grid geometry, track math, layout invariants, a pluggable control registry, and a single-page PDF renderer — so a template defined in code can be validated, measured, and rendered to a one-page A4 PDF.

**Architecture:** A `Template` holds a `GridFrame` (rows/cols with explicit per-track mm sizes) and a list of `Cell`s (each a typed rectangle on the grid). Pure functions compute each cell's mm rectangle from track prefix-sums, validate the layout, and resize tracks. Controls are plugins implementing `ControlSpec`, kept in a `ControlRegistry`; the PDF renderer positions each cell by its mm rect and delegates drawing to the cell's `ControlSpec.paintPdf`. No Flutter UI in this phase — everything is unit-testable.

**Tech Stack:** Flutter (Dart) project; `pdf` package for PDF generation; `flutter_test` for tests. No device plugins, no database, no UI widgets in Phase 1A.

## Global Constraints

- A4 portrait only: page = **210 × 297 mm**. No pagination — a template is always exactly one page.
- `Cell.type` is a **String** id; `Cell.props` is a free-form `Map<String, dynamic>`. Adding a control must require **no** model/schema change.
- mm → PDF points conversion constant: **`mmToPt = 72.0 / 25.4`** (≈ 2.834645…). Use this exact expression everywhere.
- All public geometry/validation/track functions are **pure** (no I/O, no Flutter widgets) so they unit-test without a widget harness.
- Quality gate every task: `flutter analyze` reports **0 issues** and `flutter test` is **all green** before commit.
- Chinese font embedding (NotoSansSC) is **out of scope for 1A** (Phase 5). Tests use ASCII text only.
- New project lives in **`grid_app/`** (repo root). Old `app/` is untouched legacy reference.

---

### Task 1: Scaffold the Flutter project and add `pdf`

**Files:**
- Create: `grid_app/` (via `flutter create`)
- Modify: `grid_app/pubspec.yaml`
- Modify: `grid_app/test/widget_test.dart` (delete default content)

- [ ] **Step 1: Create the project**

Run from repo root `/Users/xxf/Desktop/scss`:
```bash
flutter create --project-name scss_grid grid_app
```
Expected: project created under `grid_app/`.

- [ ] **Step 2: Add the `pdf` dependency**

Run:
```bash
cd grid_app && flutter pub add pdf
```
Expected: `pdf` appears under `dependencies:` in `grid_app/pubspec.yaml`.

- [ ] **Step 3: Remove the default widget test (it references the demo app we will delete later)**

Replace the entire contents of `grid_app/test/widget_test.dart` with:
```dart
// Placeholder test file. Real tests live in test/model, test/grid, test/controls, test/pdf.
void main() {}
```

- [ ] **Step 4: Verify the toolchain runs**

Run:
```bash
cd grid_app && flutter analyze && flutter test
```
Expected: analyze reports `No issues found!`; test run reports `All tests passed!` (0 tests is fine).

- [ ] **Step 5: Commit**

```bash
cd grid_app && git init -q 2>/dev/null; cd /Users/xxf/Desktop/scss
git -C grid_app add -A 2>/dev/null || true
# repo is not git-tracked at root; if grid_app has its own .git this commits there, otherwise skip
git -C grid_app commit -q -m "chore: scaffold grid_app Flutter project with pdf dep" 2>/dev/null || echo "(no git; snapshot skipped)"
```

> Note: the repo root is not a git repository. If you want version control, `git init` inside `grid_app/` (Step 5 attempts this). Otherwise commits are no-ops; proceed regardless.

---

### Task 2: `GridFrame` model

**Files:**
- Create: `grid_app/lib/model/grid_frame.dart`
- Test: `grid_app/test/model/grid_frame_test.dart`

**Interfaces:**
- Produces: `class GridFrame { double xMm, yMm; int cols, rows; List<double> colWidthsMm, rowHeightsMm; double get frameWidthMm; double get frameHeightMm; GridFrame.uniform({xMm,yMm,cols,rows,colWidthMm,rowHeightMm}); Map<String,dynamic> toJson(); GridFrame.fromJson(json); GridFrame copyWith({...}); }`

- [ ] **Step 1: Write the failing test**

Create `grid_app/test/model/grid_frame_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/model/grid_frame.dart';

void main() {
  test('uniform builds equal tracks and derives frame size', () {
    final g = GridFrame.uniform(
        xMm: 10, yMm: 12, cols: 3, rows: 4, colWidthMm: 20, rowHeightMm: 8);
    expect(g.colWidthsMm, [20, 20, 20]);
    expect(g.rowHeightsMm, [8, 8, 8, 8]);
    expect(g.frameWidthMm, 60);
    expect(g.frameHeightMm, 32);
  });

  test('json round-trips', () {
    final g = GridFrame.uniform(
        xMm: 5, yMm: 6, cols: 2, rows: 2, colWidthMm: 10, rowHeightMm: 9);
    final back = GridFrame.fromJson(g.toJson());
    expect(back.toJson(), g.toJson());
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd grid_app && flutter test test/model/grid_frame_test.dart`
Expected: FAIL (`scss_grid/model/grid_frame.dart` not found).

- [ ] **Step 3: Write minimal implementation**

Create `grid_app/lib/model/grid_frame.dart`:
```dart
class GridFrame {
  final double xMm;
  final double yMm;
  final int cols;
  final int rows;
  final List<double> colWidthsMm;
  final List<double> rowHeightsMm;

  GridFrame({
    required this.xMm,
    required this.yMm,
    required this.cols,
    required this.rows,
    required this.colWidthsMm,
    required this.rowHeightsMm,
  })  : assert(colWidthsMm.length == cols),
        assert(rowHeightsMm.length == rows);

  factory GridFrame.uniform({
    required double xMm,
    required double yMm,
    required int cols,
    required int rows,
    required double colWidthMm,
    required double rowHeightMm,
  }) =>
      GridFrame(
        xMm: xMm,
        yMm: yMm,
        cols: cols,
        rows: rows,
        colWidthsMm: List<double>.filled(cols, colWidthMm),
        rowHeightsMm: List<double>.filled(rows, rowHeightMm),
      );

  double get frameWidthMm => colWidthsMm.fold(0.0, (a, b) => a + b);
  double get frameHeightMm => rowHeightsMm.fold(0.0, (a, b) => a + b);

  GridFrame copyWith({
    double? xMm,
    double? yMm,
    int? cols,
    int? rows,
    List<double>? colWidthsMm,
    List<double>? rowHeightsMm,
  }) =>
      GridFrame(
        xMm: xMm ?? this.xMm,
        yMm: yMm ?? this.yMm,
        cols: cols ?? this.cols,
        rows: rows ?? this.rows,
        colWidthsMm: colWidthsMm ?? this.colWidthsMm,
        rowHeightsMm: rowHeightsMm ?? this.rowHeightsMm,
      );

  Map<String, dynamic> toJson() => {
        'xMm': xMm,
        'yMm': yMm,
        'cols': cols,
        'rows': rows,
        'colWidthsMm': colWidthsMm,
        'rowHeightsMm': rowHeightsMm,
      };

  factory GridFrame.fromJson(Map<String, dynamic> j) => GridFrame(
        xMm: (j['xMm'] as num).toDouble(),
        yMm: (j['yMm'] as num).toDouble(),
        cols: j['cols'] as int,
        rows: j['rows'] as int,
        colWidthsMm: (j['colWidthsMm'] as List)
            .map((e) => (e as num).toDouble())
            .toList(),
        rowHeightsMm: (j['rowHeightsMm'] as List)
            .map((e) => (e as num).toDouble())
            .toList(),
      );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd grid_app && flutter test test/model/grid_frame_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git -C grid_app add -A && git -C grid_app commit -q -m "feat(model): GridFrame with per-track mm sizes + json" 2>/dev/null || echo "(no git)"
```

---

### Task 3: `Cell` model

**Files:**
- Create: `grid_app/lib/model/cell.dart`
- Test: `grid_app/test/model/cell_test.dart`

**Interfaces:**
- Produces: `class Cell { String id; int col, row, colSpan, rowSpan; String type; Map<String,dynamic> props; toJson(); Cell.fromJson(json); copyWith({...}); }`

- [ ] **Step 1: Write the failing test**

Create `grid_app/test/model/cell_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/model/cell.dart';

void main() {
  test('defaults span to 1 and json round-trips with props', () {
    final c = Cell(id: 'a', col: 1, row: 2, type: 'title', props: {'text': 'Hi'});
    expect(c.colSpan, 1);
    expect(c.rowSpan, 1);
    final back = Cell.fromJson(c.toJson());
    expect(back.toJson(), c.toJson());
    expect(back.props['text'], 'Hi');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd grid_app && flutter test test/model/cell_test.dart`
Expected: FAIL (file not found).

- [ ] **Step 3: Write minimal implementation**

Create `grid_app/lib/model/cell.dart`:
```dart
class Cell {
  final String id;
  final int col;
  final int row;
  final int colSpan;
  final int rowSpan;
  final String type;
  final Map<String, dynamic> props;

  const Cell({
    required this.id,
    required this.col,
    required this.row,
    this.colSpan = 1,
    this.rowSpan = 1,
    required this.type,
    this.props = const {},
  });

  Cell copyWith({
    String? id,
    int? col,
    int? row,
    int? colSpan,
    int? rowSpan,
    String? type,
    Map<String, dynamic>? props,
  }) =>
      Cell(
        id: id ?? this.id,
        col: col ?? this.col,
        row: row ?? this.row,
        colSpan: colSpan ?? this.colSpan,
        rowSpan: rowSpan ?? this.rowSpan,
        type: type ?? this.type,
        props: props ?? this.props,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'col': col,
        'row': row,
        'colSpan': colSpan,
        'rowSpan': rowSpan,
        'type': type,
        'props': props,
      };

  factory Cell.fromJson(Map<String, dynamic> j) => Cell(
        id: j['id'] as String,
        col: j['col'] as int,
        row: j['row'] as int,
        colSpan: (j['colSpan'] as int?) ?? 1,
        rowSpan: (j['rowSpan'] as int?) ?? 1,
        type: j['type'] as String,
        props: Map<String, dynamic>.from(j['props'] as Map? ?? const {}),
      );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd grid_app && flutter test test/model/cell_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git -C grid_app add -A && git -C grid_app commit -q -m "feat(model): Cell (typed grid rectangle) + json" 2>/dev/null || echo "(no git)"
```

---

### Task 4: `Template` + `PageSize` model

**Files:**
- Create: `grid_app/lib/model/template.dart`
- Test: `grid_app/test/model/template_test.dart`

**Interfaces:**
- Consumes: `GridFrame` (Task 2), `Cell` (Task 3)
- Produces: `class PageSize { double widthMm, heightMm; const PageSize.a4(); toJson(); PageSize.fromJson(json); }` and `class Template { String id, name; PageSize page; GridFrame grid; List<Cell> cells; toJson(); Template.fromJson(json); copyWith({...}); }`

- [ ] **Step 1: Write the failing test**

Create `grid_app/test/model/template_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/model/template.dart';
import 'package:scss_grid/model/grid_frame.dart';
import 'package:scss_grid/model/cell.dart';

void main() {
  test('template round-trips through json', () {
    final t = Template(
      id: 't1',
      name: 'Survey',
      page: const PageSize.a4(),
      grid: GridFrame.uniform(
          xMm: 10, yMm: 10, cols: 12, rows: 4, colWidthMm: 15, rowHeightMm: 8),
      cells: [
        const Cell(id: 'c1', col: 0, row: 0, colSpan: 12, type: 'title',
            props: {'text': 'Site Survey'}),
      ],
    );
    final back = Template.fromJson(t.toJson());
    expect(back.toJson(), t.toJson());
    expect(back.page.widthMm, 210);
    expect(back.page.heightMm, 297);
    expect(back.cells.single.colSpan, 12);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd grid_app && flutter test test/model/template_test.dart`
Expected: FAIL (file not found).

- [ ] **Step 3: Write minimal implementation**

Create `grid_app/lib/model/template.dart`:
```dart
import 'cell.dart';
import 'grid_frame.dart';

class PageSize {
  final double widthMm;
  final double heightMm;
  const PageSize({required this.widthMm, required this.heightMm});
  const PageSize.a4()
      : widthMm = 210,
        heightMm = 297;

  Map<String, dynamic> toJson() => {'widthMm': widthMm, 'heightMm': heightMm};
  factory PageSize.fromJson(Map<String, dynamic> j) => PageSize(
        widthMm: (j['widthMm'] as num).toDouble(),
        heightMm: (j['heightMm'] as num).toDouble(),
      );
}

class Template {
  final String id;
  final String name;
  final PageSize page;
  final GridFrame grid;
  final List<Cell> cells;

  const Template({
    required this.id,
    required this.name,
    required this.page,
    required this.grid,
    required this.cells,
  });

  Template copyWith({
    String? id,
    String? name,
    PageSize? page,
    GridFrame? grid,
    List<Cell>? cells,
  }) =>
      Template(
        id: id ?? this.id,
        name: name ?? this.name,
        page: page ?? this.page,
        grid: grid ?? this.grid,
        cells: cells ?? this.cells,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'page': page.toJson(),
        'grid': grid.toJson(),
        'cells': cells.map((c) => c.toJson()).toList(),
      };

  factory Template.fromJson(Map<String, dynamic> j) => Template(
        id: j['id'] as String,
        name: j['name'] as String,
        page: PageSize.fromJson(j['page'] as Map<String, dynamic>),
        grid: GridFrame.fromJson(j['grid'] as Map<String, dynamic>),
        cells: (j['cells'] as List)
            .map((e) => Cell.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd grid_app && flutter test test/model/template_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git -C grid_app add -A && git -C grid_app commit -q -m "feat(model): Template + PageSize composing grid and cells" 2>/dev/null || echo "(no git)"
```

---

### Task 5: `RectMm` + cell geometry

**Files:**
- Create: `grid_app/lib/model/rect_mm.dart`
- Create: `grid_app/lib/grid/geometry.dart`
- Test: `grid_app/test/grid/geometry_test.dart`

**Interfaces:**
- Consumes: `GridFrame` (Task 2), `Cell` (Task 3)
- Produces: `class RectMm { double leftMm, topMm, widthMm, heightMm; double get rightMm; double get bottomMm; ==/hashCode; }` and `RectMm cellRectMm(GridFrame g, Cell c)`

- [ ] **Step 1: Write the failing test**

Create `grid_app/test/grid/geometry_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/model/rect_mm.dart';
import 'package:scss_grid/model/grid_frame.dart';
import 'package:scss_grid/model/cell.dart';
import 'package:scss_grid/grid/geometry.dart';

void main() {
  final grid = GridFrame.uniform(
      xMm: 10, yMm: 20, cols: 4, rows: 3, colWidthMm: 25, rowHeightMm: 10);

  test('single cell rect at origin of grid', () {
    final r = cellRectMm(grid, const Cell(id: 'a', col: 0, row: 0, type: 'x'));
    expect(r, const RectMm(leftMm: 10, topMm: 20, widthMm: 25, heightMm: 10));
  });

  test('spanning cell sums tracks and offsets by prior tracks', () {
    final r = cellRectMm(
        grid, const Cell(id: 'b', col: 1, row: 1, colSpan: 2, rowSpan: 2, type: 'x'));
    // left = 10 + 25, top = 20 + 10, width = 25+25, height = 10+10
    expect(r, const RectMm(leftMm: 35, topMm: 30, widthMm: 50, heightMm: 20));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd grid_app && flutter test test/grid/geometry_test.dart`
Expected: FAIL (files not found).

- [ ] **Step 3: Write minimal implementations**

Create `grid_app/lib/model/rect_mm.dart`:
```dart
class RectMm {
  final double leftMm;
  final double topMm;
  final double widthMm;
  final double heightMm;

  const RectMm({
    required this.leftMm,
    required this.topMm,
    required this.widthMm,
    required this.heightMm,
  });

  double get rightMm => leftMm + widthMm;
  double get bottomMm => topMm + heightMm;

  @override
  bool operator ==(Object other) =>
      other is RectMm &&
      other.leftMm == leftMm &&
      other.topMm == topMm &&
      other.widthMm == widthMm &&
      other.heightMm == heightMm;

  @override
  int get hashCode => Object.hash(leftMm, topMm, widthMm, heightMm);

  @override
  String toString() =>
      'RectMm(l:$leftMm, t:$topMm, w:$widthMm, h:$heightMm)';
}
```

Create `grid_app/lib/grid/geometry.dart`:
```dart
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd grid_app && flutter test test/grid/geometry_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git -C grid_app add -A && git -C grid_app commit -q -m "feat(grid): RectMm + cellRectMm geometry from track prefix sums" 2>/dev/null || echo "(no git)"
```

---

### Task 6: Layout validation (bounds + overlap)

**Files:**
- Create: `grid_app/lib/grid/validation.dart`
- Test: `grid_app/test/grid/validation_test.dart`

**Interfaces:**
- Consumes: `Template` (Task 4)
- Produces: `class LayoutViolation { String cellId; String reason; }` and `List<LayoutViolation> validateLayout(Template t)` (empty list = valid)

- [ ] **Step 1: Write the failing test**

Create `grid_app/test/grid/validation_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/model/template.dart';
import 'package:scss_grid/model/grid_frame.dart';
import 'package:scss_grid/model/cell.dart';
import 'package:scss_grid/grid/validation.dart';

Template _tpl(List<Cell> cells) => Template(
      id: 't',
      name: 'n',
      page: const PageSize.a4(),
      grid: GridFrame.uniform(
          xMm: 0, yMm: 0, cols: 4, rows: 4, colWidthMm: 10, rowHeightMm: 10),
      cells: cells,
    );

void main() {
  test('valid non-overlapping in-bounds layout has no violations', () {
    final v = validateLayout(_tpl(const [
      Cell(id: 'a', col: 0, row: 0, colSpan: 2, type: 'x'),
      Cell(id: 'b', col: 2, row: 0, colSpan: 2, type: 'x'),
    ]));
    expect(v, isEmpty);
  });

  test('out-of-bounds cell is flagged', () {
    final v = validateLayout(_tpl(const [
      Cell(id: 'a', col: 3, row: 0, colSpan: 2, type: 'x'), // 3+2 > 4
    ]));
    expect(v.map((e) => e.cellId), contains('a'));
    expect(v.single.reason, contains('out-of-bounds'));
  });

  test('overlapping cells are flagged', () {
    final v = validateLayout(_tpl(const [
      Cell(id: 'a', col: 0, row: 0, colSpan: 2, type: 'x'),
      Cell(id: 'b', col: 1, row: 0, colSpan: 2, type: 'x'),
    ]));
    expect(v.map((e) => e.cellId), contains('b'));
    expect(v.any((e) => e.reason.contains('overlap')), isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd grid_app && flutter test test/grid/validation_test.dart`
Expected: FAIL (file not found).

- [ ] **Step 3: Write minimal implementation**

Create `grid_app/lib/grid/validation.dart`:
```dart
import '../model/template.dart';

class LayoutViolation {
  final String cellId;
  final String reason;
  const LayoutViolation(this.cellId, this.reason);
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd grid_app && flutter test test/grid/validation_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git -C grid_app add -A && git -C grid_app commit -q -m "feat(grid): validateLayout bounds+overlap checks" 2>/dev/null || echo "(no git)"
```

---

### Task 7: Track math — drag a grid line (`resizeBoundary`)

**Files:**
- Create: `grid_app/lib/grid/tracks.dart`
- Test: `grid_app/test/grid/tracks_resize_test.dart`

**Interfaces:**
- Produces: `List<double> resizeBoundary(List<double> sizes, int boundary, double deltaMm, {double minMm = 5})` — moves the line between track `boundary-1` and `boundary` by `deltaMm`, taking from one and giving to the other; sum is preserved; neither track drops below `minMm`.

- [ ] **Step 1: Write the failing test**

Create `grid_app/test/grid/tracks_resize_test.dart`:
```dart
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
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd grid_app && flutter test test/grid/tracks_resize_test.dart`
Expected: FAIL (file not found).

- [ ] **Step 3: Write minimal implementation**

Create `grid_app/lib/grid/tracks.dart`:
```dart
/// Move the grid line between track [boundary]-1 and [boundary] by [deltaMm].
/// Positive delta grows the left/upper track and shrinks the right/lower one.
/// The total is preserved; neither adjacent track goes below [minMm].
List<double> resizeBoundary(
  List<double> sizes,
  int boundary,
  double deltaMm, {
  double minMm = 5,
}) {
  assert(boundary >= 1 && boundary < sizes.length);
  final out = List<double>.from(sizes);
  final maxGrow = out[boundary] - minMm; // how much we can take from the right
  final maxShrink = out[boundary - 1] - minMm; // how much we can take from left
  final d = deltaMm.clamp(-maxShrink, maxGrow);
  out[boundary - 1] += d;
  out[boundary] -= d;
  return out;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd grid_app && flutter test test/grid/tracks_resize_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git -C grid_app add -A && git -C grid_app commit -q -m "feat(grid): resizeBoundary track drag (sum-preserving, min-clamped)" 2>/dev/null || echo "(no git)"
```

---

### Task 8: Track math — add/remove a track with A4 cap

**Files:**
- Modify: `grid_app/lib/grid/tracks.dart`
- Test: `grid_app/test/grid/tracks_count_test.dart`

**Interfaces:**
- Consumes: `resizeBoundary` file (Task 7)
- Produces: `List<double>? addTrack(List<double> sizes, double newSizeMm, double offsetMm, double pageLimitMm)` (returns `null` if appending would push past the page edge) and `List<double> removeTrack(List<double> sizes, int index)`

- [ ] **Step 1: Write the failing test**

Create `grid_app/test/grid/tracks_count_test.dart`:
```dart
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
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd grid_app && flutter test test/grid/tracks_count_test.dart`
Expected: FAIL (`addTrack`/`removeTrack` not defined).

- [ ] **Step 3: Add the implementations to `tracks.dart`**

Append to `grid_app/lib/grid/tracks.dart`:
```dart
/// Append a new track of [newSizeMm]. [offsetMm] is the frame's x (for columns)
/// or y (for rows); [pageLimitMm] is the page width or height. Returns null if
/// the new track would push the frame past the page edge (A4 cap — no overflow).
List<double>? addTrack(
  List<double> sizes,
  double newSizeMm,
  double offsetMm,
  double pageLimitMm,
) {
  final sum = sizes.fold(0.0, (a, b) => a + b);
  if (offsetMm + sum + newSizeMm > pageLimitMm + 1e-9) return null;
  return [...sizes, newSizeMm];
}

/// Remove the track at [index].
List<double> removeTrack(List<double> sizes, int index) =>
    [...sizes]..removeAt(index);
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd grid_app && flutter test test/grid/tracks_count_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git -C grid_app add -A && git -C grid_app commit -q -m "feat(grid): addTrack(A4-capped)/removeTrack" 2>/dev/null || echo "(no git)"
```

---

### Task 9: `ControlSpec` interface + `ControlRegistry`

**Files:**
- Create: `grid_app/lib/controls/control_spec.dart`
- Create: `grid_app/lib/controls/registry.dart`
- Test: `grid_app/test/controls/registry_test.dart`

**Interfaces:**
- Consumes: `Cell` (Task 3)
- Produces:
  - `abstract class ControlSpec { String get type; String get label; IconData get icon; Map<String,dynamic> defaultProps(); pw.Widget paintPdf(Cell cell, Map<String,dynamic> data); Widget previewWidget(Cell cell); Widget propEditor(Cell cell, void Function(Map<String,dynamic>) onChanged); Widget fillWidget(Cell cell, dynamic value, void Function(dynamic) onChanged); String? validate(Cell cell, dynamic value); }` — the four widget/validate members have default no-op implementations so Phase 1A subclasses only implement `type/label/icon/defaultProps/paintPdf`; Phase 1B overrides the UI members.
  - `class ControlRegistry { void register(ControlSpec s); ControlSpec? specFor(String type); List<ControlSpec> get all; bool get isEmpty; }`

- [ ] **Step 1: Write the failing test**

Create `grid_app/test/controls/registry_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:scss_grid/model/cell.dart';
import 'package:scss_grid/controls/control_spec.dart';
import 'package:scss_grid/controls/registry.dart';

class _FakeControl extends ControlSpec {
  @override
  String get type => 'fake';
  @override
  String get label => 'Fake';
  @override
  IconData get icon => Icons.crop_square;
  @override
  Map<String, dynamic> defaultProps() => {'x': 1};
  @override
  pw.Widget paintPdf(Cell cell, Map<String, dynamic> data) => pw.SizedBox();
}

void main() {
  test('register, lookup by type, and list all', () {
    final r = ControlRegistry();
    expect(r.isEmpty, isTrue);
    r.register(_FakeControl());
    expect(r.isEmpty, isFalse);
    expect(r.specFor('fake'), isA<_FakeControl>());
    expect(r.specFor('missing'), isNull);
    expect(r.all.single.label, 'Fake');
  });

  test('defaultProps is provided by the spec', () {
    expect(_FakeControl().defaultProps(), {'x': 1});
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd grid_app && flutter test test/controls/registry_test.dart`
Expected: FAIL (files not found).

- [ ] **Step 3: Write minimal implementations**

Create `grid_app/lib/controls/control_spec.dart`:
```dart
import 'package:flutter/widgets.dart';
import 'package:pdf/widgets.dart' as pw;

import '../model/cell.dart';

/// One control type, self-contained: palette metadata, default props, PDF
/// drawing, and (in Phase 1B) its builder/fill widgets. Adding a control =
/// add one subclass + register it. No switch statements elsewhere.
abstract class ControlSpec {
  String get type;
  String get label;
  IconData get icon;

  /// Initial props when the control is dropped onto the grid.
  Map<String, dynamic> defaultProps();

  /// Draw the cell's content for PDF. Sized/positioned by the renderer.
  pw.Widget paintPdf(Cell cell, Map<String, dynamic> data);

  // ---- UI members: default no-ops; Phase 1B overrides these. ----

  /// Placeholder shown on the builder canvas (design mode).
  Widget previewWidget(Cell cell) => const SizedBox.shrink();

  /// Property editor shown in the builder's inspector.
  Widget propEditor(
          Cell cell, void Function(Map<String, dynamic> props) onChanged) =>
      const SizedBox.shrink();

  /// Real input shown in fill mode.
  Widget fillWidget(
          Cell cell, Object? value, void Function(Object? value) onChanged) =>
      const SizedBox.shrink();

  /// Fill-time validation rule (e.g. multiImage min/max). null = valid.
  String? validate(Cell cell, Object? value) => null;
}
```

Create `grid_app/lib/controls/registry.dart`:
```dart
import 'control_spec.dart';

class ControlRegistry {
  final Map<String, ControlSpec> _byType = {};

  void register(ControlSpec spec) => _byType[spec.type] = spec;

  ControlSpec? specFor(String type) => _byType[type];

  List<ControlSpec> get all => _byType.values.toList(growable: false);

  bool get isEmpty => _byType.isEmpty;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd grid_app && flutter test test/controls/registry_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git -C grid_app add -A && git -C grid_app commit -q -m "feat(controls): ControlSpec interface + ControlRegistry" 2>/dev/null || echo "(no git)"
```

---

### Task 10: First two controls (`title`, `field`) + default registry

**Files:**
- Create: `grid_app/lib/controls/title_control.dart`
- Create: `grid_app/lib/controls/field_control.dart`
- Create: `grid_app/lib/controls/default_controls.dart`
- Test: `grid_app/test/controls/default_controls_test.dart`

**Interfaces:**
- Consumes: `ControlSpec` (Task 9), `ControlRegistry` (Task 9), `Cell` (Task 3)
- Produces: `class TitleControl extends ControlSpec`, `class FieldControl extends ControlSpec`, and `ControlRegistry buildDefaultRegistry()` that registers both.

- [ ] **Step 1: Write the failing test**

Create `grid_app/test/controls/default_controls_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/controls/default_controls.dart';

void main() {
  test('default registry has title and field', () {
    final r = buildDefaultRegistry();
    expect(r.specFor('title'), isNotNull);
    expect(r.specFor('field'), isNotNull);
    expect(r.specFor('title')!.defaultProps()['text'], 'Title');
    expect(r.specFor('field')!.defaultProps()['valueType'], 'text');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd grid_app && flutter test test/controls/default_controls_test.dart`
Expected: FAIL (files not found).

- [ ] **Step 3: Write minimal implementations**

Create `grid_app/lib/controls/title_control.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;

import '../model/cell.dart';
import 'control_spec.dart';

class TitleControl extends ControlSpec {
  @override
  String get type => 'title';
  @override
  String get label => 'Title';
  @override
  IconData get icon => Icons.title;
  @override
  Map<String, dynamic> defaultProps() => {'text': 'Title', 'align': 'center'};

  @override
  pw.Widget paintPdf(Cell cell, Map<String, dynamic> data) {
    final text = (cell.props['text'] as String?) ?? '';
    return pw.Center(
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
      ),
    );
  }
}
```

Create `grid_app/lib/controls/field_control.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;

import '../model/cell.dart';
import 'control_spec.dart';

class FieldControl extends ControlSpec {
  @override
  String get type => 'field';
  @override
  String get label => 'Field';
  @override
  IconData get icon => Icons.text_fields;
  @override
  Map<String, dynamic> defaultProps() =>
      {'label': 'Label', 'key': 'field', 'valueType': 'text', 'labelCols': 1};

  @override
  pw.Widget paintPdf(Cell cell, Map<String, dynamic> data) {
    final label = (cell.props['label'] as String?) ?? '';
    final key = (cell.props['key'] as String?) ?? '';
    final value = (data[key] ?? '').toString();
    final labelCols = (cell.props['labelCols'] as int?) ?? 1;
    final valueCols = (cell.colSpan - labelCols).clamp(1, cell.colSpan);

    pw.Widget box(String t) => pw.Container(
          padding: const pw.EdgeInsets.all(2),
          decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
          child: pw.Text(t, style: const pw.TextStyle(fontSize: 9)),
        );

    return pw.Row(children: [
      pw.Expanded(flex: labelCols, child: box(label)),
      pw.Expanded(flex: valueCols, child: box(value)),
    ]);
  }
}
```

> Known Phase-1A simplification: the label|value split uses flex `labelCols : (colSpan-labelCols)`, which lands exactly on a grid line only when columns are uniform. Exact non-uniform alignment is a Phase-1B refinement (split at the real column boundary). Documented in spec §6.

Create `grid_app/lib/controls/default_controls.dart`:
```dart
import 'field_control.dart';
import 'registry.dart';
import 'title_control.dart';

/// The app's starting control set. Add new controls by registering them here.
ControlRegistry buildDefaultRegistry() {
  final r = ControlRegistry();
  r.register(TitleControl());
  r.register(FieldControl());
  return r;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd grid_app && flutter test test/controls/default_controls_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git -C grid_app add -A && git -C grid_app commit -q -m "feat(controls): TitleControl, FieldControl, buildDefaultRegistry" 2>/dev/null || echo "(no git)"
```

---

### Task 11: Single-page PDF renderer

**Files:**
- Create: `grid_app/lib/pdf/template_pdf.dart`
- Test: `grid_app/test/pdf/template_pdf_test.dart`

**Interfaces:**
- Consumes: `Template` (Task 4), `cellRectMm` (Task 5), `ControlRegistry` (Task 9)
- Produces: `const double mmToPt = 72.0 / 25.4;` and `pw.Document renderTemplate(Template t, Map<String, dynamic> data, ControlRegistry registry)`

- [ ] **Step 1: Write the failing test**

Create `grid_app/test/pdf/template_pdf_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/model/template.dart';
import 'package:scss_grid/model/grid_frame.dart';
import 'package:scss_grid/model/cell.dart';
import 'package:scss_grid/controls/default_controls.dart';
import 'package:scss_grid/pdf/template_pdf.dart';

void main() {
  test('renders a single-page non-empty PDF', () async {
    final t = Template(
      id: 't',
      name: 'Survey',
      page: const PageSize.a4(),
      grid: GridFrame.uniform(
          xMm: 10, yMm: 10, cols: 12, rows: 4, colWidthMm: 15, rowHeightMm: 8),
      cells: const [
        Cell(id: 'c1', col: 0, row: 0, colSpan: 12, type: 'title',
            props: {'text': 'Site Survey'}),
        Cell(id: 'c2', col: 0, row: 1, colSpan: 6, type: 'field',
            props: {'label': 'Site Name', 'key': 'site_name', 'labelCols': 3}),
      ],
    );
    final doc = renderTemplate(t, const {'site_name': 'Castle'}, buildDefaultRegistry());
    final bytes = await doc.save();
    expect(bytes, isNotEmpty);
  });

  test('mmToPt converts A4 width to ~595 pt', () {
    expect((210 * mmToPt).round(), 595);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd grid_app && flutter test test/pdf/template_pdf_test.dart`
Expected: FAIL (file not found).

- [ ] **Step 3: Write minimal implementation**

Create `grid_app/lib/pdf/template_pdf.dart`:
```dart
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../controls/registry.dart';
import '../grid/geometry.dart';
import '../model/template.dart';

/// Millimetres → PDF points (1 inch = 25.4 mm = 72 pt).
const double mmToPt = 72.0 / 25.4;

/// Render [t] to a single A4 page. Each cell is absolutely positioned by its
/// mm rectangle and drawn by its control's `paintPdf`. No pagination.
pw.Document renderTemplate(
  Template t,
  Map<String, dynamic> data,
  ControlRegistry registry,
) {
  final doc = pw.Document();
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat(
        t.page.widthMm * mmToPt,
        t.page.heightMm * mmToPt,
      ),
      build: (context) {
        final children = <pw.Widget>[];
        for (final cell in t.cells) {
          final r = cellRectMm(t.grid, cell);
          final spec = registry.specFor(cell.type);
          final content = spec?.paintPdf(cell, data) ?? pw.SizedBox();
          children.add(
            pw.Positioned(
              left: r.leftMm * mmToPt,
              top: r.topMm * mmToPt,
              child: pw.SizedBox(
                width: r.widthMm * mmToPt,
                height: r.heightMm * mmToPt,
                child: content,
              ),
            ),
          );
        }
        return pw.Stack(children: children);
      },
    ),
  );
  return doc;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd grid_app && flutter test test/pdf/template_pdf_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git -C grid_app add -A && git -C grid_app commit -q -m "feat(pdf): single-page renderTemplate positioning cells by mm rect" 2>/dev/null || echo "(no git)"
```

---

### Task 12: End-to-end core test — build → validate → render to a PDF file

**Files:**
- Create: `grid_app/lib/sample/sample_template.dart`
- Test: `grid_app/test/integration/build_to_pdf_test.dart`

**Interfaces:**
- Consumes: everything above.
- Produces: `Template sampleTemplate()` — a representative subset of the real survey form (title + a few fields) used by tests and, later, by the builder as a starting point.

- [ ] **Step 1: Write the failing test**

Create `grid_app/test/integration/build_to_pdf_test.dart`:
```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/sample/sample_template.dart';
import 'package:scss_grid/grid/validation.dart';
import 'package:scss_grid/controls/default_controls.dart';
import 'package:scss_grid/pdf/template_pdf.dart';

void main() {
  test('sample template is valid and renders to a single-page PDF file', () async {
    final t = sampleTemplate();

    // 1. layout is valid (in-bounds, no overlaps)
    expect(validateLayout(t), isEmpty);

    // 2. frame fits within the A4 page
    expect(t.grid.xMm + t.grid.frameWidthMm, lessThanOrEqualTo(t.page.widthMm));
    expect(t.grid.yMm + t.grid.frameHeightMm, lessThanOrEqualTo(t.page.heightMm));

    // 3. renders to a real PDF file
    final doc = renderTemplate(t, const {
      'site_name': 'Gjirokaster Castle',
      'site_city': 'Gjirokaster',
    }, buildDefaultRegistry());
    final bytes = await doc.save();
    final out = File('${Directory.systemTemp.path}/scss_sample.pdf');
    await out.writeAsBytes(bytes);
    expect(await out.length(), greaterThan(0));
    // PDF magic header
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd grid_app && flutter test test/integration/build_to_pdf_test.dart`
Expected: FAIL (`sample_template.dart` not found).

- [ ] **Step 3: Write minimal implementation**

Create `grid_app/lib/sample/sample_template.dart`:
```dart
import '../model/cell.dart';
import '../model/grid_frame.dart';
import '../model/template.dart';

/// A small, valid starter template (subset of the real survey form):
/// a title band plus two label|value fields, on a 12-col grid.
Template sampleTemplate() => Template(
      id: 'sample',
      name: 'Site Survey (sample)',
      page: const PageSize.a4(),
      grid: GridFrame.uniform(
        xMm: 10,
        yMm: 10,
        cols: 12,
        rows: 16,
        colWidthMm: 15, // 12 * 15 = 180mm <= (210 - 10) usable
        rowHeightMm: 8, // 16 * 8 = 128mm <= (297 - 10) usable
      ),
      cells: const [
        Cell(id: 'title', col: 0, row: 0, colSpan: 12, type: 'title',
            props: {'text': 'Site Survey Form', 'align': 'center'}),
        Cell(id: 'name', col: 0, row: 1, colSpan: 12, type: 'field',
            props: {'label': 'Site Name', 'key': 'site_name', 'labelCols': 3}),
        Cell(id: 'city', col: 0, row: 2, colSpan: 12, type: 'field',
            props: {'label': 'Site City', 'key': 'site_city', 'labelCols': 3}),
      ],
    );
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd grid_app && flutter test test/integration/build_to_pdf_test.dart`
Expected: PASS.

- [ ] **Step 5: Run the full suite + analyze**

Run: `cd grid_app && flutter analyze && flutter test`
Expected: `No issues found!` and `All tests passed!`.

- [ ] **Step 6: Commit**

```bash
git -C grid_app add -A && git -C grid_app commit -q -m "test(core): end-to-end sample template build->validate->PDF" 2>/dev/null || echo "(no git)"
```

---

## Phase 1A — Definition of Done

- `grid_app/` is a Flutter project; `flutter analyze` = 0 issues, `flutter test` = all green.
- A template can be defined in code, validated (bounds + overlap), measured (`cellRectMm`), and rendered to a **single-page A4 PDF** via the control registry.
- Adding a new control requires only a new `ControlSpec` subclass + a `register(...)` line (no model/renderer/switch changes).

## Self-Review (against spec)

**Spec coverage (Phase 1A slice of spec §12.1):**
- §5 data model (Template/GridFrame/Cell, type=String+props map) → Tasks 2–4. ✓
- §5 cell mm rect, shared function → Task 5 (`cellRectMm`). ✓
- §3/§4 track sizes as source, A4 cap, drag-line non-uniform → Tasks 7–8 (`resizeBoundary`, `addTrack` cap). ✓
- §5 invariants (in-bounds, no overlap) → Task 6 (`validateLayout`). ✓
- §10.1 ControlSpec + registry, type-agnostic model → Tasks 9–10. ✓
- §7/§11 single-page PDF via shared rect → Tasks 11–12. ✓
- Deferred to Phase 1B (correctly out of this plan): builder UI, drag/inspector, on-screen PDF preview, Drift persistence. Deferred to later phases: fill mode, device features, NotoSansSC, deviceChecklist/image/multiImage controls, golden tests.

**Placeholder scan:** No TBD/TODO; every code step has complete code; the one simplification (field label split) is explicitly flagged with the deferral.

**Type consistency:** `GridFrame`, `Cell`, `Template`, `RectMm`, `cellRectMm`, `validateLayout`/`LayoutViolation`, `resizeBoundary`/`addTrack`/`removeTrack`, `ControlSpec`/`ControlRegistry`, `TitleControl`/`FieldControl`/`buildDefaultRegistry`, `renderTemplate`/`mmToPt`, `sampleTemplate` — names are used identically across the tasks that produce and consume them. Package import prefix is `scss_grid` (matches `flutter create --project-name scss_grid`).
