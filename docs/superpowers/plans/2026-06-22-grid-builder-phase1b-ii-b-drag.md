# Grid Template Builder — Phase 1B-ii-b (Drag Direct Manipulation) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add drag editing to the builder: drag a selected cell to move it, drag handles on its right/bottom edge to resize colSpan/rowSpan, and drag handles on the grid's top/left edge to resize a column's width / row's height — all snapping to the grid and guarded so the layout stays valid and within A4.

**Architecture:** A new `EditableCanvas` (StatefulWidget) wraps `GridCanvas` and owns all gestures. It converts a gesture's `globalPosition` to a grid coordinate via its own `RenderBox` (a `GlobalKey`) + `cellCoordAtMm`, and reports edits through callbacks (`onSelect`/`onMove`/`onSpan`/`onResizeCol`/`onResizeRow`). `BuilderScreen` turns those callbacks into pure `Template` transforms (`moveCell`/`setSpan`/`resizeColBoundary`/`resizeRowBoundary`) committed through its existing `_commit` (which gates on `isValid`). No new model concepts.

**Tech Stack:** Flutter 3.27.2 / Dart 3.6.1. Reuses Phase 1A/1B-i/1B-ii-a: `cellCoordAtMm`, `cellAtCoord`, `updateCell`, `isValid`, `resizeBoundary`, `cellRectMm`, `GridCanvas`, `BuilderScreen`, `ControlPalette`, `CellInspector`.

## Global Constraints

- A4 page = 210 × 297 mm. Every drag edit must keep the layout valid (`isValid`/`validateLayout`) and within A4; reject (no-op) otherwise — done by routing through `BuilderScreen._commit`.
- All edit transforms are pure `Template→Template` (no mutation); the screen owns state.
- Gesture→grid math uses ONE scale: `pageScale(widthPx, page.widthMm)`. `EditableCanvas` derives grid coords from its own `RenderBox.globalToLocal`, so it never drifts from how `GridCanvas` renders.
- `GridFrame.copyWith(colWidthsMm:/rowHeightsMm:)` derives `cols`/`rows` from list length — set the track lists.
- Keep tap-to-add (palette) and the inspector from Phase 1B-ii-a working. Drag-from-palette-to-place is NOT in this phase.
- Quality gate every task: `flutter analyze` = `No issues found!` and `flutter test` all green before commit.
- Manual simulator pass at the end (Task 6, controller) — drag gestures need a device check.

---

### Task 0: Start a feature branch

**Files:** none (git only)

- [ ] **Step 1**

```bash
cd /Users/xxf/Desktop/scss
git checkout main && git checkout -b feat/grid-builder-phase1b-ii-b
git branch --show-current
```
Expected: `feat/grid-builder-phase1b-ii-b`.

---

### Task 1: Shared canvas metrics (single source of scale)

**Files:**
- Create: `grid_app/lib/builder/canvas_metrics.dart`
- Modify: `grid_app/lib/builder/grid_canvas.dart` (use `pageScale`)
- Test: `grid_app/test/builder/canvas_metrics_test.dart`

**Interfaces:**
- Produces: `const double kCanvasPad = 12;` and `double pageScale(double widthPx, double pageWidthMm) => widthPx / pageWidthMm;`

- [ ] **Step 1: Write the failing test**

Create `grid_app/test/builder/canvas_metrics_test.dart`:
```dart
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd grid_app && flutter test test/builder/canvas_metrics_test.dart`
Expected: FAIL (file not found).

- [ ] **Step 3: Write implementation + use it in GridCanvas**

Create `grid_app/lib/builder/canvas_metrics.dart`:
```dart
/// Shared canvas geometry so the renderer and the gesture layer never drift.
library;

/// Padding around the A4 page inside the builder body.
const double kCanvasPad = 12;

/// Pixels-per-mm to render an A4 page of [pageWidthMm] in [widthPx] of space.
double pageScale(double widthPx, double pageWidthMm) => widthPx / pageWidthMm;
```

In `grid_app/lib/builder/grid_canvas.dart`, add the import and replace the inline scale. Add at the top with the other imports:
```dart
import 'canvas_metrics.dart';
```
Then change the `scale` line inside `build`'s `LayoutBuilder` from:
```dart
        final scale = constraints.maxWidth / page.widthMm;
```
to:
```dart
        final scale = pageScale(constraints.maxWidth, page.widthMm);
```

- [ ] **Step 4: Run test + existing canvas tests**

Run: `cd grid_app && flutter test test/builder/canvas_metrics_test.dart test/builder/grid_canvas_test.dart`
Expected: PASS (both).

- [ ] **Step 5: Commit**

```bash
cd /Users/xxf/Desktop/scss && git add -A && git commit -q -m "feat(builder): shared canvas_metrics (pageScale, kCanvasPad)"
```

---

### Task 2: Move + span pure ops

**Files:**
- Modify: `grid_app/lib/builder/editor_ops.dart`
- Test: `grid_app/test/builder/editor_ops_move_test.dart`

**Interfaces:**
- Consumes: `updateCell` (already in editor_ops), `Cell.copyWith`
- Produces: `Template moveCell(Template t, String id, int col, int row)` and `Template setSpan(Template t, String id, int colSpan, int rowSpan)`

- [ ] **Step 1: Write the failing test**

Create `grid_app/test/builder/editor_ops_move_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/model/cell.dart';
import 'package:scss_grid/model/template.dart';
import 'package:scss_grid/model/grid_frame.dart';
import 'package:scss_grid/builder/editor_ops.dart';

Template _tpl(List<Cell> cells) => Template(
      id: 't',
      name: 'n',
      page: const PageSize.a4(),
      grid: GridFrame.uniform(
          xMm: 0, yMm: 0, cols: 6, rows: 6, colWidthMm: 20, rowHeightMm: 8),
      cells: cells,
    );

void main() {
  test('moveCell sets new col/row, leaving spans intact', () {
    final t = _tpl(const [
      Cell(id: 'a', col: 0, row: 0, colSpan: 2, rowSpan: 1, type: 'field'),
    ]);
    final m = moveCell(t, 'a', 3, 2);
    final c = m.cells.single;
    expect([c.col, c.row, c.colSpan, c.rowSpan], [3, 2, 2, 1]);
  });

  test('setSpan sets colSpan/rowSpan, leaving position intact', () {
    final t = _tpl(const [
      Cell(id: 'a', col: 1, row: 1, type: 'field'),
    ]);
    final s = setSpan(t, 'a', 3, 2);
    final c = s.cells.single;
    expect([c.col, c.row, c.colSpan, c.rowSpan], [1, 1, 3, 2]);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd grid_app && flutter test test/builder/editor_ops_move_test.dart`
Expected: FAIL (`moveCell`/`setSpan` not defined).

- [ ] **Step 3: Add the ops to `editor_ops.dart`**

Append to `grid_app/lib/builder/editor_ops.dart`:
```dart
/// Move the cell [id] so its top-left is at grid coordinate (col,row).
Template moveCell(Template t, String id, int col, int row) =>
    updateCell(t, id, (c) => c.copyWith(col: col, row: row));

/// Set the cell [id]'s column and row span.
Template setSpan(Template t, String id, int colSpan, int rowSpan) =>
    updateCell(t, id, (c) => c.copyWith(colSpan: colSpan, rowSpan: rowSpan));
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd grid_app && flutter test test/builder/editor_ops_move_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/xxf/Desktop/scss && git add -A && git commit -q -m "feat(builder): moveCell + setSpan pure ops"
```

---

### Task 3: Grid-frame track resize ops

**Files:**
- Create: `grid_app/lib/grid/grid_resize.dart`
- Test: `grid_app/test/grid/grid_resize_test.dart`

**Interfaces:**
- Consumes: `resizeBoundary` (`package:scss_grid/grid/tracks.dart`), `GridFrame.copyWith`
- Produces: `GridFrame resizeColBoundary(GridFrame g, int boundary, double deltaMm, {double minMm = 5})` and `GridFrame resizeRowBoundary(GridFrame g, int boundary, double deltaMm, {double minMm = 5})`

- [ ] **Step 1: Write the failing test**

Create `grid_app/test/grid/grid_resize_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/model/grid_frame.dart';
import 'package:scss_grid/grid/grid_resize.dart';

void main() {
  final g = GridFrame.uniform(
      xMm: 0, yMm: 0, cols: 3, rows: 3, colWidthMm: 20, rowHeightMm: 10);

  test('resizeColBoundary moves a vertical line, preserving frame width', () {
    final r = resizeColBoundary(g, 1, 5); // boundary between col 0 and 1
    expect(r.colWidthsMm, [25, 15, 20]);
    expect(r.frameWidthMm, g.frameWidthMm); // total preserved
    expect(r.cols, 3);
  });

  test('resizeRowBoundary moves a horizontal line, preserving frame height', () {
    final r = resizeRowBoundary(g, 2, -3); // boundary between row 1 and 2
    expect(r.rowHeightsMm, [10, 7, 13]);
    expect(r.frameHeightMm, g.frameHeightMm);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd grid_app && flutter test test/grid/grid_resize_test.dart`
Expected: FAIL (file not found).

- [ ] **Step 3: Write minimal implementation**

Create `grid_app/lib/grid/grid_resize.dart`:
```dart
import '../model/grid_frame.dart';
import 'tracks.dart';

/// Move the vertical grid line at column [boundary] (between col boundary-1 and
/// boundary) by [deltaMm]. Frame width is preserved; tracks stay >= minMm.
GridFrame resizeColBoundary(GridFrame g, int boundary, double deltaMm,
        {double minMm = 5}) =>
    g.copyWith(
        colWidthsMm:
            resizeBoundary(g.colWidthsMm, boundary, deltaMm, minMm: minMm));

/// Move the horizontal grid line at row [boundary] by [deltaMm]. Frame height
/// is preserved; tracks stay >= minMm.
GridFrame resizeRowBoundary(GridFrame g, int boundary, double deltaMm,
        {double minMm = 5}) =>
    g.copyWith(
        rowHeightsMm:
            resizeBoundary(g.rowHeightsMm, boundary, deltaMm, minMm: minMm));
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd grid_app && flutter test test/grid/grid_resize_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/xxf/Desktop/scss && git add -A && git commit -q -m "feat(grid): resizeColBoundary/resizeRowBoundary GridFrame ops"
```

---

### Task 4: `EditableCanvas` — move, span handles, grid-line handles

**Files:**
- Create: `grid_app/lib/builder/editable_canvas.dart`
- Test: `grid_app/test/builder/editable_canvas_test.dart`

**Interfaces:**
- Consumes: `GridCanvas`, `cellRectMm`, `cellCoordAtMm`, `cellAtCoord`, `pageScale`, `Template`, `ControlRegistry`.
- Produces:
  ```dart
  class EditableCanvas extends StatefulWidget {
    final Template template;
    final ControlRegistry registry;
    final String? selectedId;
    final void Function(String? id) onSelect;        // tap
    final void Function(String id, int col, int row) onMove;
    final void Function(String id, int colSpan, int rowSpan) onSpan;
    final void Function(int boundary, double deltaMm) onResizeCol;
    final void Function(int boundary, double deltaMm) onResizeRow;
  }
  ```
  Layout: a `Stack` (keyed by a stable `GlobalKey`) containing `GridCanvas`, a full-bleed gesture layer (tap = select, pan = move the selected cell to the pointer's grid coord), two span handles on the selected cell (right → colSpan, bottom → rowSpan), and grid-line handles on the frame's top edge (column boundaries → `onResizeCol`) and left edge (row boundaries → `onResizeRow`). All gestures convert `globalPosition` to grid coords through the Stack's `RenderBox`.

- [ ] **Step 1: Write the failing test**

Create `grid_app/test/builder/editable_canvas_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/builder/editable_canvas.dart';
import 'package:scss_grid/controls/default_controls.dart';
import 'package:scss_grid/model/cell.dart';
import 'package:scss_grid/model/grid_frame.dart';
import 'package:scss_grid/model/template.dart';

// 210mm wide canvas at 210px -> scale 1px/mm. Grid: x0 y0, 6 cols * 35mm, 6 rows * 30mm.
Template _tpl(List<Cell> cells) => Template(
      id: 't',
      name: 'n',
      page: const PageSize.a4(),
      grid: GridFrame.uniform(
          xMm: 0, yMm: 0, cols: 6, rows: 6, colWidthMm: 35, rowHeightMm: 30),
      cells: cells,
    );

Widget _host(Widget child) => MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: 210, height: 297, child: child),
        ),
      ),
    );

void main() {
  testWidgets('tap selects the cell under the pointer', (tester) async {
    String? selected;
    await tester.pumpWidget(_host(EditableCanvas(
      template: _tpl(const [
        Cell(id: 'a', col: 0, row: 0, colSpan: 2, type: 'field',
            props: {'label': 'L', 'key': 'k'}),
      ]),
      registry: buildDefaultRegistry(),
      selectedId: null,
      onSelect: (id) => selected = id,
      onMove: (_, __, ___) {},
      onSpan: (_, __, ___) {},
      onResizeCol: (_, __) {},
      onResizeRow: (_, __) {},
    )));
    // cell 'a' covers x 0..70mm, y 0..30mm -> tap at (10,10)px is inside it
    await tester.tapAt(const Offset(10, 10));
    expect(selected, 'a');
  });

  testWidgets('dragging the selected cell body reports a move to the pointer coord',
      (tester) async {
    int? mc, mr;
    await tester.pumpWidget(_host(EditableCanvas(
      template: _tpl(const [
        Cell(id: 'a', col: 0, row: 0, colSpan: 1, type: 'field',
            props: {'label': 'L', 'key': 'k'}),
      ]),
      registry: buildDefaultRegistry(),
      selectedId: 'a',
      onSelect: (_) {},
      onMove: (id, c, r) { mc = c; mr = r; },
      onSpan: (_, __, ___) {},
      onResizeCol: (_, __) {},
      onResizeRow: (_, __) {},
    )));
    // drag from inside cell 'a' (5,5) to (110,95)px -> col 3 (105..140), row 3 (90..120)
    await tester.dragFrom(const Offset(5, 5), const Offset(105, 90));
    expect([mc, mr], [3, 3]);
  });

  testWidgets('dragging the right span handle reports a larger colSpan',
      (tester) async {
    int? cs;
    await tester.pumpWidget(_host(EditableCanvas(
      template: _tpl(const [
        Cell(id: 'a', col: 0, row: 0, colSpan: 1, type: 'field',
            props: {'label': 'L', 'key': 'k'}),
      ]),
      registry: buildDefaultRegistry(),
      selectedId: 'a',
      onSelect: (_) {},
      onMove: (_, __, ___) {},
      onSpan: (id, colSpan, rowSpan) => cs = colSpan,
      onResizeCol: (_, __) {},
      onResizeRow: (_, __) {},
    )));
    // right handle sits at the cell's right edge (x ~35, y ~15). Drag to x ~110 (col 3) -> colSpan 4
    await tester.drag(
        find.byKey(const ValueKey('span-right')), const Offset(80, 0));
    expect(cs, 4);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd grid_app && flutter test test/builder/editable_canvas_test.dart`
Expected: FAIL (file not found).

- [ ] **Step 3: Write `EditableCanvas`**

Create `grid_app/lib/builder/editable_canvas.dart`:
```dart
import 'package:flutter/material.dart';

import '../controls/registry.dart';
import '../grid/geometry.dart';
import '../grid/hit_test.dart';
import '../model/cell.dart';
import '../model/template.dart';
import 'canvas_metrics.dart';
import 'editor_ops.dart';
import 'grid_canvas.dart';

/// Wraps [GridCanvas] with drag editing: tap to select, drag the selected cell
/// to move it, drag its right/bottom handles to resize its span, and drag the
/// frame's top/left edge handles to resize a column width / row height.
/// All gestures convert globalPosition -> grid coord via this widget's RenderBox.
class EditableCanvas extends StatefulWidget {
  final Template template;
  final ControlRegistry registry;
  final String? selectedId;
  final void Function(String? id) onSelect;
  final void Function(String id, int col, int row) onMove;
  final void Function(String id, int colSpan, int rowSpan) onSpan;
  final void Function(int boundary, double deltaMm) onResizeCol;
  final void Function(int boundary, double deltaMm) onResizeRow;

  const EditableCanvas({
    super.key,
    required this.template,
    required this.registry,
    required this.selectedId,
    required this.onSelect,
    required this.onMove,
    required this.onSpan,
    required this.onResizeCol,
    required this.onResizeRow,
  });

  @override
  State<EditableCanvas> createState() => _EditableCanvasState();
}

class _EditableCanvasState extends State<EditableCanvas> {
  final _key = GlobalKey();

  double get _scale {
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || box.size.width == 0) return 1;
    return pageScale(box.size.width, widget.template.page.widthMm);
  }

  ({int col, int row})? _coordAt(Offset globalPos) {
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return null;
    final local = box.globalToLocal(globalPos);
    final s = _scale;
    return cellCoordAtMm(
        widget.template.grid, local.dx / s, local.dy / s);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.template;
    final selected = widget.selectedId == null
        ? null
        : _cellById(widget.selectedId!);
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = pageScale(constraints.maxWidth, t.page.widthMm);
        return SizedBox(
          width: t.page.widthMm * scale,
          height: t.page.heightMm * scale,
          child: Stack(
            key: _key,
            children: [
              // 1. render
              GridCanvas(
                  template: t, registry: widget.registry,
                  selectedId: widget.selectedId),
              // 2. tap-select + drag-move (full bleed, under the handles)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTapUp: (d) {
                    final c = _coordAt(d.globalPosition);
                    final hit = c == null
                        ? null
                        : cellAtCoord(t, c.col, c.row);
                    widget.onSelect(hit?.id);
                  },
                  onPanUpdate: (d) {
                    final id = widget.selectedId;
                    if (id == null) return;
                    final c = _coordAt(d.globalPosition);
                    if (c != null) widget.onMove(id, c.col, c.row);
                  },
                ),
              ),
              // 3. column-boundary handles on the frame top edge
              for (var i = 1; i < t.grid.cols; i++)
                _colHandle(i, scale),
              // 4. row-boundary handles on the frame left edge
              for (var j = 1; j < t.grid.rows; j++)
                _rowHandle(j, scale),
              // 5. span handles on the selected cell
              if (selected != null) ..._spanHandles(selected, scale),
            ],
          ),
        );
      },
    );
  }

  Cell? _cellById(String id) {
    for (final c in widget.template.cells) {
      if (c.id == id) return c;
    }
    return null;
  }

  double _colX(int boundary) {
    var x = widget.template.grid.xMm;
    for (var i = 0; i < boundary; i++) {
      x += widget.template.grid.colWidthsMm[i];
    }
    return x;
  }

  double _rowY(int boundary) {
    var y = widget.template.grid.yMm;
    for (var j = 0; j < boundary; j++) {
      y += widget.template.grid.rowHeightsMm[j];
    }
    return y;
  }

  Widget _colHandle(int boundary, double scale) {
    final x = _colX(boundary) * scale;
    final yTop = widget.template.grid.yMm * scale;
    return Positioned(
      left: x - 8,
      top: yTop - 14,
      width: 16,
      height: 16,
      child: GestureDetector(
        key: ValueKey('col-handle-$boundary'),
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (d) => widget.onResizeCol(boundary, d.delta.dx / scale),
        child: const _Knob(color: Colors.deepOrange),
      ),
    );
  }

  Widget _rowHandle(int boundary, double scale) {
    final y = _rowY(boundary) * scale;
    final xLeft = widget.template.grid.xMm * scale;
    return Positioned(
      left: xLeft - 14,
      top: y - 8,
      width: 16,
      height: 16,
      child: GestureDetector(
        key: ValueKey('row-handle-$boundary'),
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (d) => widget.onResizeRow(boundary, d.delta.dy / scale),
        child: const _Knob(color: Colors.deepOrange),
      ),
    );
  }

  List<Widget> _spanHandles(Cell cell, double scale) {
    final r = cellRectMm(widget.template.grid, cell);
    final rightX = r.rightMm * scale;
    final bottomY = r.bottomMm * scale;
    final midY = (r.topMm + r.heightMm / 2) * scale;
    final midX = (r.leftMm + r.widthMm / 2) * scale;
    return [
      Positioned(
        left: rightX - 8,
        top: midY - 8,
        width: 16,
        height: 16,
        child: GestureDetector(
          key: const ValueKey('span-right'),
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (d) {
            final c = _coordAt(d.globalPosition);
            if (c == null) return;
            final span = (c.col - cell.col + 1).clamp(1, widget.template.grid.cols);
            widget.onSpan(cell.id, span, cell.rowSpan);
          },
          child: const _Knob(color: Colors.blue),
        ),
      ),
      Positioned(
        left: midX - 8,
        top: bottomY - 8,
        width: 16,
        height: 16,
        child: GestureDetector(
          key: const ValueKey('span-bottom'),
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (d) {
            final c = _coordAt(d.globalPosition);
            if (c == null) return;
            final span = (c.row - cell.row + 1).clamp(1, widget.template.grid.rows);
            widget.onSpan(cell.id, cell.colSpan, span);
          },
          child: const _Knob(color: Colors.blue),
        ),
      ),
    ];
  }
}

class _Knob extends StatelessWidget {
  final Color color;
  const _Knob({required this.color});
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
        ),
      );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd grid_app && flutter test test/builder/editable_canvas_test.dart`
Expected: PASS (tap-select, drag-move, span-right).

- [ ] **Step 5: Run analyze**

Run: `cd grid_app && flutter analyze`
Expected: `No issues found!` (fix the `dynamic`→`Cell` typing per the note if needed).

- [ ] **Step 6: Commit**

```bash
cd /Users/xxf/Desktop/scss && git add -A && git commit -q -m "feat(builder): EditableCanvas (drag move, span handles, grid-line handles)"
```

---

### Task 5: Wire `EditableCanvas` into `BuilderScreen`

**Files:**
- Modify: `grid_app/lib/builder/builder_screen.dart`
- Test: `grid_app/test/builder/builder_screen_drag_test.dart`

**Interfaces:**
- Consumes: `EditableCanvas`, `moveCell`, `setSpan`, `resizeColBoundary`, `resizeRowBoundary`, `_commit` (existing).
- Produces: `_canvasArea` returns an `EditableCanvas` whose callbacks apply the pure ops through `_commit`.

- [ ] **Step 1: Write the failing test**

Create `grid_app/test/builder/builder_screen_drag_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/builder/builder_screen.dart';
import 'package:scss_grid/builder/editable_canvas.dart';
import 'package:scss_grid/controls/default_controls.dart';
import 'package:scss_grid/data/template_store.dart';
import 'package:scss_grid/model/cell.dart';
import 'package:scss_grid/model/grid_frame.dart';
import 'package:scss_grid/model/template.dart';

Template _one() => Template(
      id: 'o',
      name: 'One',
      page: const PageSize.a4(),
      grid: GridFrame.uniform(
          xMm: 0, yMm: 0, cols: 6, rows: 6, colWidthMm: 30, rowHeightMm: 30),
      cells: const [
        Cell(id: 'a', col: 0, row: 0, colSpan: 1, type: 'field',
            props: {'label': 'L', 'key': 'k'}),
      ],
    );

void main() {
  testWidgets('the builder uses an EditableCanvas', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: BuilderScreen(
          template: _one(),
          registry: buildDefaultRegistry(),
          store: InMemoryTemplateStore()),
    ));
    expect(find.byType(EditableCanvas), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd grid_app && flutter test test/builder/builder_screen_drag_test.dart`
Expected: FAIL (BuilderScreen still uses the plain GridCanvas/GestureDetector).

- [ ] **Step 3: Replace `_canvasArea` (and add the drag handlers) in BuilderScreen**

In `grid_app/lib/builder/builder_screen.dart`:
1. Add imports near the top (with the other `import` lines):
```dart
import '../grid/grid_resize.dart';
import 'canvas_metrics.dart';
import 'editable_canvas.dart';
```
2. Replace the entire `_canvasArea()` method with:
```dart
  Widget _canvasArea() => SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(kCanvasPad),
          child: EditableCanvas(
            template: _t,
            registry: widget.registry,
            selectedId: _selectedId,
            onSelect: (id) => setState(() => _selectedId = id),
            onMove: (id, col, row) => _commit(moveCell(_t, id, col, row)),
            onSpan: (id, colSpan, rowSpan) =>
                _commit(setSpan(_t, id, colSpan, rowSpan)),
            onResizeCol: (boundary, deltaMm) => _commit(
                _t.copyWith(grid: resizeColBoundary(_t.grid, boundary, deltaMm))),
            onResizeRow: (boundary, deltaMm) => _commit(
                _t.copyWith(grid: resizeRowBoundary(_t.grid, boundary, deltaMm))),
          ),
        ),
      );
```
3. Remove the now-unused imports if `flutter analyze` flags them: the old `_canvasArea` used `grid_canvas.dart`, `hit_test.dart`, and `geometry.dart` (via `cellCoordAtMm`) directly. After this change `BuilderScreen` no longer references `GridCanvas`/`cellCoordAtMm`/`_onCanvasTap` directly — DELETE the `_onCanvasTap` method and remove the `import 'grid_canvas.dart';` and `import '../grid/hit_test.dart';` lines if analyze reports them as unused. (Keep `editor_ops.dart`, `cell_inspector.dart`, `control_palette.dart`, `pdf_preview_screen.dart`, `model/*` imports.)

- [ ] **Step 4: Run test + full suite + analyze**

Run: `cd grid_app && flutter analyze && flutter test`
Expected: `No issues found!` and all green (the existing `builder_screen_test.dart` add/delete/save flows still pass — `EditableCanvas` contains a `GridCanvas`, so `find.byType(GridCanvas)` still finds one).

- [ ] **Step 5: Commit**

```bash
cd /Users/xxf/Desktop/scss && git add -A && git commit -q -m "feat(builder): wire EditableCanvas drag editing into BuilderScreen"
```

---

### Task 6: Manual simulator pass (controller, not a subagent)

**Files:** none

- [ ] **Step 1: Run the editor on the emulator and verify drag by observation**

```bash
flutter emulators --launch Medium_Phone_API_35
cd /Users/xxf/Desktop/scss/grid_app && flutter run -d emulator-5554
```
Verify and report what you see:
1. New template → tap a cell → it selects (blue highlight) and shows blue right/bottom span knobs; the frame shows orange knobs along its top and left edges.
2. Drag the selected cell's body → it moves to a new grid position (snaps; invalid drops are ignored).
3. Drag the right blue knob → the cell widens by columns; drag the bottom knob → it grows by rows.
4. Drag an orange top-edge knob left/right → that column boundary moves (one column narrows, its neighbour widens); drag a left-edge knob → a row boundary moves.
5. Preview/Save still work; reopen → edits persisted.

If a gesture misbehaves, report DONE_WITH_CONCERNS with specifics.

---

## Phase 1B-ii-b — Definition of Done

- The builder supports drag: move a selected cell, resize its span via right/bottom handles, and resize a column width / row height via top/left edge handles — all snapped to the grid, gated by `isValid`, and within A4.
- The gesture layer derives grid coords from the canvas RenderBox via the single shared `pageScale`, so it can't drift from the renderer.
- `flutter analyze` = 0 issues; `flutter test` all green; manual simulator pass confirms the gestures.
- Drag-from-palette-to-place remains deferred (tap-to-add covers adding controls); rowSpan/colSpan also still adjustable via the inspector stepper from Phase 1B-ii-a.

## Self-Review (against spec)

**Spec coverage (Phase 1B-ii-b slice of spec §7):**
- §7 "拖控件边缘改 colSpan/rowSpan" → Tasks 2 (`setSpan`) + 4 (span handles). ✓
- §7 "拖网格线改行高/列宽" → Tasks 3 (`resizeColBoundary`/`resizeRowBoundary`) + 4 (edge handles). ✓
- §7 move a placed control (drag) → Tasks 2 (`moveCell`) + 4 (body pan). ✓
- §3/§4 valid + within A4 → all drag edits route through `_commit`→`isValid` (Task 5). ✓
- Final-review recommendation (shared scale, no drift) → Task 1 (`pageScale`) + `EditableCanvas` deriving coords from its own RenderBox. ✓
- Explicitly deferred: drag-from-palette-to-place (tap-to-add works); grab-offset-preserving move (this phase snaps the cell's top-left to the pointer coord).

**Placeholder scan:** No TBD/TODO; every code step has complete code. Task 6 is an explicit manual-observation step with concrete checks. The `dynamic`→`Cell` typing note in Task 4 is a real instruction (prefer the typed form), not a placeholder.

**Type consistency:** `pageScale`/`kCanvasPad`, `moveCell`/`setSpan`, `resizeColBoundary`/`resizeRowBoundary`, `EditableCanvas({template,registry,selectedId,onSelect,onMove,onSpan,onResizeCol,onResizeRow})`, handle keys (`span-right`/`span-bottom`/`col-handle-N`/`row-handle-N`), and reused names (`cellRectMm`, `cellCoordAtMm`, `cellAtCoord`, `isValid`, `resizeBoundary`, `GridFrame.copyWith`) are consistent across producing/consuming tasks.
