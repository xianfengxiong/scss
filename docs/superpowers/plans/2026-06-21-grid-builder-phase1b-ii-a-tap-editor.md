# Grid Template Builder — Phase 1B-ii-a (Tap/Button Editor) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the read-only builder into a working editor without drag gestures: tap a cell to select it, tap a palette item to add a control, edit its props / span / delete it via an inspector, change the grid's rows & cols with steppers — then save and preview.

**Architecture:** All edits are pure `Template → Template` transforms (`editor_ops.dart`), guarded by Phase 1A's `validateLayout` before being committed. The builder screen becomes stateful, holding the working `Template` + selected cell id; tapping the canvas hit-tests (`cellCoordAtMm`) to select. Palette/inspector are separate widgets. Drag manipulation is deferred to Phase 1B-ii-b.

**Tech Stack:** Flutter 3.27.2 / Dart 3.6.1. Builds on Phase 1A (`cellRectMm`, `validateLayout`, `addTrack`/`removeTrack`, `ControlSpec`/registry, `renderTemplate`) and 1B-i (`GridCanvas`, `TemplateStore`, `BuilderScreen`, control `previewWidget`).

## Global Constraints

- A4 page = 210 × 297 mm. Edits must keep the layout valid: `validateLayout(candidate).isEmpty` (no overlap, no out-of-bounds) — reject the edit otherwise. The grid stays within A4 (`addTrack` returns null past the edge).
- All edit operations are pure functions returning a new `Template` (no in-place mutation); the screen owns the mutable state.
- `Cell.type` stays a `String`; `Cell.props` a free-form map. Adding a control type must still need no model change.
- `GridFrame.copyWith(colWidthsMm:/rowHeightsMm:)` derives `cols`/`rows` from the list lengths — set the track lists, never `cols`/`rows` directly.
- NO drag gestures in this phase (drag-to-place, drag-move, span handles, drag grid lines are Phase 1B-ii-b). This phase is tap + steppers + buttons only.
- Quality gate every task: `flutter analyze` = `No issues found!` and `flutter test` all green before commit.
- The editor needs a manual simulator pass at the end (Task 9) — widget tests verify model + wiring, the device pass verifies the real feel.

---

### Task 0: Start a feature branch

**Files:** none (git only)

- [ ] **Step 1**

```bash
cd /Users/xxf/Desktop/scss
git checkout main && git checkout -b feat/grid-builder-phase1b-ii-a
git branch --show-current
```
Expected: `feat/grid-builder-phase1b-ii-a`.

---

### Task 1: Hit-testing — point (mm) → grid coordinate

**Files:**
- Create: `grid_app/lib/grid/hit_test.dart`
- Test: `grid_app/test/grid/hit_test_test.dart`

**Interfaces:**
- Consumes: `GridFrame` (`package:scss_grid/model/grid_frame.dart`)
- Produces: `({int col, int row})? cellCoordAtMm(GridFrame g, double xMm, double yMm)` — the grid coordinate a point falls in, or null if outside the frame. A boundary belongs to the cell to its right / below.

- [ ] **Step 1: Write the failing test**

Create `grid_app/test/grid/hit_test_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/model/grid_frame.dart';
import 'package:scss_grid/grid/hit_test.dart';

void main() {
  final g = GridFrame.uniform(
      xMm: 10, yMm: 20, cols: 4, rows: 3, colWidthMm: 25, rowHeightMm: 10);

  test('point inside the first cell maps to (0,0)', () {
    expect(cellCoordAtMm(g, 11, 21), (col: 0, row: 0));
  });

  test('point inside a later cell maps to its coord', () {
    // x: 10 + 25*2 = 60..85 is col 2; y: 20 + 10 = 30..40 is row 1
    expect(cellCoordAtMm(g, 70, 35), (col: 2, row: 1));
  });

  test('a track boundary belongs to the cell on its right/below', () {
    // x exactly 35 = start of col 1; y exactly 30 = start of row 1
    expect(cellCoordAtMm(g, 35, 30), (col: 1, row: 1));
  });

  test('point outside the frame is null', () {
    expect(cellCoordAtMm(g, 5, 5), isNull); // left/above
    expect(cellCoordAtMm(g, 200, 35), isNull); // right of frame
    expect(cellCoordAtMm(g, 70, 100), isNull); // below frame
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd grid_app && flutter test test/grid/hit_test_test.dart`
Expected: FAIL (file not found).

- [ ] **Step 3: Write minimal implementation**

Create `grid_app/lib/grid/hit_test.dart`:
```dart
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd grid_app && flutter test test/grid/hit_test_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/xxf/Desktop/scss && git add -A && git commit -q -m "feat(grid): cellCoordAtMm hit-test (point mm -> grid coord)"
```

---

### Task 2: Pure edit operations on the Template

**Files:**
- Create: `grid_app/lib/builder/editor_ops.dart`
- Test: `grid_app/test/builder/editor_ops_test.dart`

**Interfaces:**
- Consumes: `Cell`, `GridFrame`, `Template`, `validateLayout` (`package:scss_grid/grid/validation.dart`), `addTrack`/`removeTrack` (`package:scss_grid/grid/tracks.dart`)
- Produces:
  - `Cell? cellAtCoord(Template t, int col, int row)`
  - `int? firstFreeRow(Template t)`
  - `Template addCell(Template t, Cell c)`
  - `Template removeCell(Template t, String id)`
  - `Template updateCell(Template t, String id, Cell Function(Cell) f)`
  - `Template? setCols(Template t, int cols)` (null if growing would exceed A4)
  - `Template? setRows(Template t, int rows)` (null if growing would exceed A4)
  - `bool isValid(Template t)`

- [ ] **Step 1: Write the failing test**

Create `grid_app/test/builder/editor_ops_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/model/cell.dart';
import 'package:scss_grid/model/template.dart';
import 'package:scss_grid/model/grid_frame.dart';
import 'package:scss_grid/builder/editor_ops.dart';

Template _tpl(List<Cell> cells, {int cols = 4, int rows = 4}) => Template(
      id: 't',
      name: 'n',
      page: const PageSize.a4(),
      grid: GridFrame.uniform(
          xMm: 5, yMm: 5, cols: cols, rows: rows, colWidthMm: 20, rowHeightMm: 8),
      cells: cells,
    );

void main() {
  test('cellAtCoord finds the covering cell or null', () {
    final t = _tpl(const [
      Cell(id: 'a', col: 0, row: 0, colSpan: 2, rowSpan: 2, type: 'field'),
    ]);
    expect(cellAtCoord(t, 1, 1)!.id, 'a');
    expect(cellAtCoord(t, 3, 3), isNull);
  });

  test('firstFreeRow returns the first row with no cells', () {
    final t = _tpl(const [
      Cell(id: 'a', col: 0, row: 0, colSpan: 4, type: 'field'),
    ]);
    expect(firstFreeRow(t), 1);
  });

  test('addCell / removeCell / updateCell are pure transforms', () {
    var t = _tpl(const []);
    t = addCell(t, const Cell(id: 'x', col: 0, row: 0, type: 'title'));
    expect(t.cells.single.id, 'x');
    t = updateCell(t, 'x', (c) => c.copyWith(props: {'text': 'Hi'}));
    expect(t.cells.single.props['text'], 'Hi');
    t = removeCell(t, 'x');
    expect(t.cells, isEmpty);
  });

  test('setCols grows/shrinks within A4 and rejects overflow', () {
    final t = _tpl(const []); // cols 4 * 20mm = 80, x 5 -> fits
    expect(setCols(t, 6)!.grid.cols, 6);
    expect(setCols(t, 2)!.grid.cols, 2);
    // 200 cols * 20mm would blow past 210mm page width
    expect(setCols(t, 200), isNull);
  });

  test('setRows grows/shrinks within A4', () {
    final t = _tpl(const []);
    expect(setRows(t, 6)!.grid.rows, 6);
    expect(setRows(t, 2)!.grid.rows, 2);
    expect(setRows(t, 500), isNull);
  });

  test('isValid reflects validateLayout', () {
    final ok = _tpl(const [Cell(id: 'a', col: 0, row: 0, type: 'field')]);
    final bad = _tpl(const [
      Cell(id: 'a', col: 0, row: 0, colSpan: 2, type: 'field'),
      Cell(id: 'b', col: 1, row: 0, colSpan: 2, type: 'field'),
    ]);
    expect(isValid(ok), isTrue);
    expect(isValid(bad), isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd grid_app && flutter test test/builder/editor_ops_test.dart`
Expected: FAIL (file not found).

- [ ] **Step 3: Write minimal implementation**

Create `grid_app/lib/builder/editor_ops.dart`:
```dart
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

/// True if [t] is a valid layout (no overlap, no out-of-bounds cells).
bool isValid(Template t) => validateLayout(t).isEmpty;
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd grid_app && flutter test test/builder/editor_ops_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/xxf/Desktop/scss && git add -A && git commit -q -m "feat(builder): pure Template edit ops (add/remove/update/setCols/setRows)"
```

---

### Task 3: Control `propEditor` for Title and Field

**Files:**
- Modify: `grid_app/lib/controls/title_control.dart`
- Modify: `grid_app/lib/controls/field_control.dart`
- Test: `grid_app/test/controls/prop_editor_test.dart`

**Interfaces:**
- Consumes: `Cell`, `ControlSpec.propEditor` (default no-op from Phase 1A)
- Produces: overridden `Widget propEditor(Cell cell, void Function(Map<String,dynamic> props) onChanged)` on `TitleControl` (edit `text`) and `FieldControl` (edit `label` + `valueType`).

- [ ] **Step 1: Write the failing test**

Create `grid_app/test/controls/prop_editor_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/model/cell.dart';
import 'package:scss_grid/controls/title_control.dart';
import 'package:scss_grid/controls/field_control.dart';

void main() {
  testWidgets('TitleControl.propEditor edits the text prop', (tester) async {
    Map<String, dynamic>? out;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TitleControl().propEditor(
            const Cell(id: 't', col: 0, row: 0, type: 'title',
                props: {'text': 'Old'}),
            (p) => out = p),
      ),
    ));
    await tester.enterText(find.byType(TextFormField), 'New title');
    expect(out!['text'], 'New title');
  });

  testWidgets('FieldControl.propEditor edits the label prop', (tester) async {
    Map<String, dynamic>? out;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: FieldControl().propEditor(
            const Cell(id: 'f', col: 0, row: 0, type: 'field',
                props: {'label': 'Old', 'valueType': 'text'}),
            (p) => out = p),
      ),
    ));
    await tester.enterText(find.byType(TextFormField).first, 'Site Name');
    expect(out!['label'], 'Site Name');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd grid_app && flutter test test/controls/prop_editor_test.dart`
Expected: FAIL — default `propEditor` returns `SizedBox.shrink()`, so no `TextFormField`.

- [ ] **Step 3: Write the implementations**

In `grid_app/lib/controls/title_control.dart`, add inside `TitleControl` (keep existing members):
```dart
  @override
  Widget propEditor(
          Cell cell, void Function(Map<String, dynamic> props) onChanged) =>
      TextFormField(
        initialValue: (cell.props['text'] as String?) ?? '',
        decoration: const InputDecoration(labelText: 'Title text'),
        onChanged: (v) => onChanged({...cell.props, 'text': v}),
      );
```

In `grid_app/lib/controls/field_control.dart`, add inside `FieldControl` (keep existing members):
```dart
  @override
  Widget propEditor(
      Cell cell, void Function(Map<String, dynamic> props) onChanged) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          initialValue: (cell.props['label'] as String?) ?? '',
          decoration: const InputDecoration(labelText: 'Label'),
          onChanged: (v) => onChanged({...cell.props, 'label': v}),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: (cell.props['valueType'] as String?) ?? 'text',
          decoration: const InputDecoration(labelText: 'Value type'),
          items: const ['text', 'number', 'coordinate', 'select', 'date']
              .map((v) => DropdownMenuItem(value: v, child: Text(v)))
              .toList(),
          onChanged: (v) =>
              onChanged({...cell.props, 'valueType': v ?? 'text'}),
        ),
      ],
    );
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd grid_app && flutter test test/controls/prop_editor_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/xxf/Desktop/scss && git add -A && git commit -q -m "feat(controls): propEditor for Title (text) and Field (label/valueType)"
```

---

### Task 4: GridCanvas — selection highlight + unknown-control placeholder

**Files:**
- Modify: `grid_app/lib/builder/grid_canvas.dart`
- Test: `grid_app/test/builder/grid_canvas_select_test.dart`

**Interfaces:**
- Consumes: existing `GridCanvas`
- Produces: `GridCanvas` gains `final String? selectedId;` (default null) — the cell with that id gets a highlight border. An unregistered `cell.type` renders a visible `?type` placeholder (not an empty box).

- [ ] **Step 1: Write the failing test**

Create `grid_app/test/builder/grid_canvas_select_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/builder/grid_canvas.dart';
import 'package:scss_grid/controls/registry.dart';
import 'package:scss_grid/controls/default_controls.dart';
import 'package:scss_grid/model/cell.dart';
import 'package:scss_grid/model/grid_frame.dart';
import 'package:scss_grid/model/template.dart';

Template _tpl(List<Cell> cells) => Template(
      id: 't',
      name: 'n',
      page: const PageSize.a4(),
      grid: GridFrame.uniform(
          xMm: 5, yMm: 5, cols: 4, rows: 4, colWidthMm: 20, rowHeightMm: 8),
      cells: cells,
    );

void main() {
  testWidgets('unknown control type renders a visible placeholder',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 300,
          child: GridCanvas(
            template: _tpl(const [
              Cell(id: 'u', col: 0, row: 0, colSpan: 4, type: 'mystery'),
            ]),
            registry: ControlRegistry(), // empty -> 'mystery' unregistered
          ),
        ),
      ),
    ));
    expect(find.textContaining('mystery'), findsOneWidget);
  });

  testWidgets('selectedId draws exactly one highlight', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 300,
          child: GridCanvas(
            template: _tpl(const [
              Cell(id: 'a', col: 0, row: 0, colSpan: 4, type: 'field',
                  props: {'label': 'L', 'key': 'k'}),
            ]),
            registry: buildDefaultRegistry(),
            selectedId: 'a',
          ),
        ),
      ),
    ));
    expect(find.byKey(const ValueKey('cell-highlight')), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd grid_app && flutter test test/builder/grid_canvas_select_test.dart`
Expected: FAIL (`selectedId` param undefined / no placeholder / no highlight key).

- [ ] **Step 3: Modify GridCanvas**

In `grid_app/lib/builder/grid_canvas.dart`, add the `selectedId` field and update `_cell`. Replace the constructor and `_cell` method:

Add field + constructor param (alongside `showGridLines`):
```dart
  /// The cell to highlight as selected (Phase 1B-ii-a), or null.
  final String? selectedId;

  const GridCanvas({
    super.key,
    required this.template,
    required this.registry,
    this.showGridLines = true,
    this.selectedId,
  });
```

Replace `_cell`:
```dart
  Widget _cell(Cell cell, double scale) {
    final r = cellRectMm(template.grid, cell);
    final spec = registry.specFor(cell.type);
    final Widget content = spec?.previewWidget(cell) ??
        Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
              border: Border.all(color: Colors.red),
              color: const Color(0x11FF0000)),
          child: Text('?${cell.type}',
              style: const TextStyle(fontSize: 9, color: Colors.red)),
        );
    return Positioned(
      left: r.leftMm * scale,
      top: r.topMm * scale,
      width: r.widthMm * scale,
      height: r.heightMm * scale,
      child: cell.id == selectedId
          ? Container(
              key: const ValueKey('cell-highlight'),
              decoration: BoxDecoration(
                  border: Border.all(color: Colors.blue, width: 2)),
              child: content,
            )
          : content,
    );
  }
```
(Remove the old `assert(spec != null, ...)` line — an unregistered type is now a visible placeholder, not an assert.)

- [ ] **Step 4: Run test to verify it passes**

Run: `cd grid_app && flutter test test/builder/grid_canvas_select_test.dart test/builder/grid_canvas_test.dart`
Expected: PASS (both files).

- [ ] **Step 5: Commit**

```bash
cd /Users/xxf/Desktop/scss && git add -A && git commit -q -m "feat(builder): GridCanvas selection highlight + unknown-control placeholder"
```

---

### Task 5: ControlPalette widget

**Files:**
- Create: `grid_app/lib/builder/control_palette.dart`
- Test: `grid_app/test/builder/control_palette_test.dart`

**Interfaces:**
- Consumes: `ControlRegistry`, `ControlSpec`
- Produces: `class ControlPalette extends StatelessWidget { final ControlRegistry registry; final void Function(ControlSpec spec) onPick; }` — a horizontal strip of the registry's controls (icon + label); tapping one calls `onPick`.

- [ ] **Step 1: Write the failing test**

Create `grid_app/test/builder/control_palette_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/builder/control_palette.dart';
import 'package:scss_grid/controls/default_controls.dart';
import 'package:scss_grid/controls/control_spec.dart';

void main() {
  testWidgets('palette lists controls and reports the picked one',
      (tester) async {
    ControlSpec? picked;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ControlPalette(
            registry: buildDefaultRegistry(), onPick: (s) => picked = s),
      ),
    ));
    expect(find.text('Title'), findsOneWidget);
    expect(find.text('Field'), findsOneWidget);
    await tester.tap(find.text('Field'));
    expect(picked!.type, 'field');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd grid_app && flutter test test/builder/control_palette_test.dart`
Expected: FAIL (file not found).

- [ ] **Step 3: Write minimal implementation**

Create `grid_app/lib/builder/control_palette.dart`:
```dart
import 'package:flutter/material.dart';

import '../controls/control_spec.dart';
import '../controls/registry.dart';

/// A horizontal strip of the registry's controls. Tapping one adds it to the
/// template (Phase 1B-ii-a: tap-to-add; drag-to-place is 1B-ii-b).
class ControlPalette extends StatelessWidget {
  final ControlRegistry registry;
  final void Function(ControlSpec spec) onPick;

  const ControlPalette(
      {super.key, required this.registry, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        children: [
          for (final spec in registry.all)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: InkWell(
                onTap: () => onPick(spec),
                child: Container(
                  width: 84,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFCFD8DC)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(spec.icon, size: 22),
                      const SizedBox(height: 2),
                      Text(spec.label,
                          style: const TextStyle(fontSize: 11),
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd grid_app && flutter test test/builder/control_palette_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/xxf/Desktop/scss && git add -A && git commit -q -m "feat(builder): ControlPalette (tap a control to add)"
```

---

### Task 6: CellInspector widget

**Files:**
- Create: `grid_app/lib/builder/cell_inspector.dart`
- Test: `grid_app/test/builder/cell_inspector_test.dart`

**Interfaces:**
- Consumes: `Cell`, `ControlSpec` (its `propEditor`, `label`), `Template` (for `cols`/`rows` bounds)
- Produces: `class CellInspector extends StatelessWidget { final Cell cell; final ControlSpec spec; final int maxColSpan; final void Function(Map<String,dynamic> props) onPropsChanged; final void Function(int colSpan) onColSpanChanged; final VoidCallback onDelete; }` — a panel showing the control's `propEditor`, a colSpan stepper (1..maxColSpan), and a Delete button.

- [ ] **Step 1: Write the failing test**

Create `grid_app/test/builder/cell_inspector_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/builder/cell_inspector.dart';
import 'package:scss_grid/controls/field_control.dart';
import 'package:scss_grid/model/cell.dart';

void main() {
  testWidgets('inspector shows propEditor, steps colSpan, and deletes',
      (tester) async {
    int? newSpan;
    var deleted = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CellInspector(
          cell: const Cell(id: 'f', col: 0, row: 0, colSpan: 2, type: 'field',
              props: {'label': 'L', 'valueType': 'text'}),
          spec: FieldControl(),
          maxColSpan: 4,
          onPropsChanged: (_) {},
          onColSpanChanged: (v) => newSpan = v,
          onDelete: () => deleted = true,
        ),
      ),
    ));
    expect(find.byType(TextFormField), findsOneWidget); // field label editor
    expect(find.text('Width: 2'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('colspan-inc')));
    expect(newSpan, 3);

    await tester.tap(find.byKey(const ValueKey('cell-delete')));
    expect(deleted, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd grid_app && flutter test test/builder/cell_inspector_test.dart`
Expected: FAIL (file not found).

- [ ] **Step 3: Write minimal implementation**

Create `grid_app/lib/builder/cell_inspector.dart`:
```dart
import 'package:flutter/material.dart';

import '../controls/control_spec.dart';
import '../model/cell.dart';

/// Edits the selected cell: its control props (via the control's `propEditor`),
/// its width in columns (colSpan stepper), and a delete action. Move, rowSpan
/// and drag come in Phase 1B-ii-b.
class CellInspector extends StatelessWidget {
  final Cell cell;
  final ControlSpec spec;
  final int maxColSpan;
  final void Function(Map<String, dynamic> props) onPropsChanged;
  final void Function(int colSpan) onColSpanChanged;
  final VoidCallback onDelete;

  const CellInspector({
    super.key,
    required this.cell,
    required this.spec,
    required this.maxColSpan,
    required this.onPropsChanged,
    required this.onColSpanChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(spec.label,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                key: const ValueKey('cell-delete'),
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                tooltip: 'Delete',
                onPressed: onDelete,
              ),
            ],
          ),
          spec.propEditor(cell, onPropsChanged),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('Width: ${cell.colSpan}'),
              const Spacer(),
              IconButton(
                key: const ValueKey('colspan-dec'),
                icon: const Icon(Icons.remove),
                onPressed: cell.colSpan > 1
                    ? () => onColSpanChanged(cell.colSpan - 1)
                    : null,
              ),
              IconButton(
                key: const ValueKey('colspan-inc'),
                icon: const Icon(Icons.add),
                onPressed: cell.col + cell.colSpan < maxColSpan
                    ? () => onColSpanChanged(cell.colSpan + 1)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```
> Note: the inc button enables while `cell.col + cell.colSpan < maxColSpan` (room to the right within the grid). `maxColSpan` is passed as `template.grid.cols`.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd grid_app && flutter test test/builder/cell_inspector_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/xxf/Desktop/scss && git add -A && git commit -q -m "feat(builder): CellInspector (propEditor + colSpan stepper + delete)"
```

---

### Task 7: Make BuilderScreen an editor (tap-select, palette-add, inspector, grid steppers)

**Files:**
- Rewrite: `grid_app/lib/builder/builder_screen.dart`
- Modify: `grid_app/test/builder/builder_screen_test.dart`

**Interfaces:**
- Consumes: `editor_ops.dart` (all), `cellCoordAtMm`, `cellRectMm`, `GridCanvas` (with `selectedId`), `ControlPalette`, `CellInspector`, `TemplateStore`, `PdfPreviewScreen`, `DateTime` for new cell ids.
- Produces: `BuilderScreen` becomes a `StatefulWidget` holding the working `Template` + `selectedId`. Tap canvas → select/deselect; palette → add a full-width control at `firstFreeRow`; inspector → edit props / colSpan / delete; grid `+`/`-` steppers change rows & cols; Save persists; Preview unchanged.

- [ ] **Step 1: Write the failing test**

Replace `grid_app/test/builder/builder_screen_test.dart` entirely:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/builder/builder_screen.dart';
import 'package:scss_grid/builder/grid_canvas.dart';
import 'package:scss_grid/builder/control_palette.dart';
import 'package:scss_grid/controls/default_controls.dart';
import 'package:scss_grid/data/template_store.dart';
import 'package:scss_grid/model/cell.dart';
import 'package:scss_grid/model/grid_frame.dart';
import 'package:scss_grid/model/template.dart';

Template _empty() => Template(
      id: 'e',
      name: 'Empty',
      page: const PageSize.a4(),
      grid: GridFrame.uniform(
          xMm: 10, yMm: 10, cols: 12, rows: 16, colWidthMm: 15, rowHeightMm: 8),
      cells: const [],
    );

void main() {
  testWidgets('shows name, grid size, canvas; Save persists', (tester) async {
    final store = InMemoryTemplateStore();
    final t = _empty();
    await tester.pumpWidget(MaterialApp(
      home: BuilderScreen(
          template: t, registry: buildDefaultRegistry(), store: store),
    ));
    expect(find.text('Empty'), findsOneWidget);
    expect(find.byType(GridCanvas), findsOneWidget);
    expect(find.byType(ControlPalette), findsOneWidget);

    await tester.tap(find.byTooltip('Save'));
    await tester.pump();
    expect((await store.get(t.id))!.id, t.id);
  });

  testWidgets('tapping a palette control adds a cell to the template',
      (tester) async {
    final store = InMemoryTemplateStore();
    await tester.pumpWidget(MaterialApp(
      home: BuilderScreen(
          template: _empty(), registry: buildDefaultRegistry(), store: store),
    ));
    await tester.tap(find.text('Field')); // palette item
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Save'));
    await tester.pump();
    final saved = await store.get('e');
    expect(saved!.cells.length, 1);
    expect(saved.cells.single.type, 'field');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd grid_app && flutter test test/builder/builder_screen_test.dart`
Expected: FAIL (BuilderScreen still stateless / no ControlPalette / no add behavior).

- [ ] **Step 3: Rewrite BuilderScreen**

Replace `grid_app/lib/builder/builder_screen.dart` entirely:
```dart
import 'package:flutter/material.dart';

import '../controls/control_spec.dart';
import '../controls/registry.dart';
import '../data/template_store.dart';
import '../grid/geometry.dart';
import '../grid/hit_test.dart';
import '../model/cell.dart';
import '../model/template.dart';
import 'cell_inspector.dart';
import 'control_palette.dart';
import 'editor_ops.dart';
import 'grid_canvas.dart';
import 'pdf_preview_screen.dart';

/// Tap-based template editor (Phase 1B-ii-a): add controls from the palette,
/// tap a cell to select, edit it in the inspector, change grid rows/cols.
/// Drag manipulation arrives in Phase 1B-ii-b.
class BuilderScreen extends StatefulWidget {
  final Template template;
  final ControlRegistry registry;
  final TemplateStore store;

  const BuilderScreen({
    super.key,
    required this.template,
    required this.registry,
    required this.store,
  });

  @override
  State<BuilderScreen> createState() => _BuilderScreenState();
}

class _BuilderScreenState extends State<BuilderScreen> {
  late Template _t = widget.template;
  String? _selectedId;
  int _seq = 0;

  String _newId(String type) => '${type}_${DateTime.now().microsecondsSinceEpoch}_${_seq++}';

  void _commit(Template? candidate) {
    if (candidate == null || !isValid(candidate)) return;
    setState(() => _t = candidate);
  }

  void _addControl(ControlSpec spec) {
    final row = firstFreeRow(_t);
    if (row == null) return; // grid full
    final cell = Cell(
      id: _newId(spec.type),
      col: 0,
      row: row,
      colSpan: _t.grid.cols,
      type: spec.type,
      props: spec.defaultProps(),
    );
    final candidate = addCell(_t, cell);
    if (isValid(candidate)) {
      setState(() {
        _t = candidate;
        _selectedId = cell.id;
      });
    }
  }

  void _onCanvasTap(Offset localPos, double scale) {
    final xMm = localPos.dx / scale;
    final yMm = localPos.dy / scale;
    final coord = cellCoordAtMm(_t.grid, xMm, yMm);
    final hit = coord == null ? null : cellAtCoord(_t, coord.col, coord.row);
    setState(() => _selectedId = hit?.id);
  }

  Cell? get _selected =>
      _selectedId == null ? null : _t.cells.where((c) => c.id == _selectedId).firstOrNull;

  Future<void> _save() async {
    await widget.store.upsert(_t);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Template saved.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_t.name),
            Text('${_t.grid.cols} × ${_t.grid.rows} grid',
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.normal)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Preview',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) =>
                  PdfPreviewScreen(template: _t, registry: widget.registry),
            )),
          ),
          IconButton(
              icon: const Icon(Icons.save_outlined),
              tooltip: 'Save',
              onPressed: _save),
        ],
      ),
      body: Column(
        children: [
          _gridControls(),
          ControlPalette(registry: widget.registry, onPick: _addControl),
          const Divider(height: 1),
          Expanded(child: _canvasArea()),
          if (selected != null)
            Material(
              elevation: 8,
              child: CellInspector(
                cell: selected,
                spec: widget.registry.specFor(selected.type)!,
                maxColSpan: _t.grid.cols,
                onPropsChanged: (props) => _commit(
                    updateCell(_t, selected.id, (c) => c.copyWith(props: props))),
                onColSpanChanged: (span) => _commit(updateCell(
                    _t, selected.id, (c) => c.copyWith(colSpan: span))),
                onDelete: () => setState(() {
                  _t = removeCell(_t, selected.id);
                  _selectedId = null;
                }),
              ),
            ),
        ],
      ),
    );
  }

  Widget _gridControls() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          children: [
            const Text('Cols'),
            _step(() => _commit(setCols(_t, _t.grid.cols - 1)),
                () => _commit(setCols(_t, _t.grid.cols + 1)), 'cols'),
            const SizedBox(width: 16),
            const Text('Rows'),
            _step(() => _commit(setRows(_t, _t.grid.rows - 1)),
                () => _commit(setRows(_t, _t.grid.rows + 1)), 'rows'),
          ],
        ),
      );

  Widget _step(VoidCallback dec, VoidCallback inc, String key) => Row(
        children: [
          IconButton(
              key: ValueKey('$key-dec'),
              icon: const Icon(Icons.remove),
              onPressed: dec),
          IconButton(
              key: ValueKey('$key-inc'),
              icon: const Icon(Icons.add),
              onPressed: inc),
        ],
      );

  Widget _canvasArea() => LayoutBuilder(
        builder: (context, constraints) {
          // The canvas width drives the scale; mirror GridCanvas's own math.
          const pad = 12.0;
          final canvasWidth = constraints.maxWidth - pad * 2;
          final scale = canvasWidth / _t.page.widthMm;
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(pad),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (d) => _onCanvasTap(d.localPosition, scale),
                child: GridCanvas(
                  template: _t,
                  registry: widget.registry,
                  selectedId: _selectedId,
                ),
              ),
            ),
          );
        },
      );
}
```
> The `firstOrNull` getter is from `dart:core`'s `Iterable` extension via `package:collection`? No — `firstOrNull` is available on `Iterable` since Dart 3 via the SDK (`package:collection`'s `IterableExtension`). To avoid a dependency, replace `_selected`'s body with a manual lookup:
```dart
  Cell? get _selected {
    for (final c in _t.cells) {
      if (c.id == _selectedId) return c;
    }
    return null;
  }
```
Use that manual version (no `firstOrNull`).

- [ ] **Step 4: Run test to verify it passes (and the canvas tests still pass)**

Run: `cd grid_app && flutter test test/builder/builder_screen_test.dart`
Expected: PASS.

- [ ] **Step 5: Run analyze + full suite**

Run: `cd grid_app && flutter analyze && flutter test`
Expected: `No issues found!` and all green.

- [ ] **Step 6: Commit**

```bash
cd /Users/xxf/Desktop/scss && git add -A && git commit -q -m "feat(builder): tap-based editor (palette add, select, inspector, grid steppers)"
```

---

### Task 8: Deferred polish — list ordering, PDF unknown-control placeholder, canvas golden

**Files:**
- Modify: `grid_app/lib/data/app_database.dart`
- Modify: `grid_app/lib/pdf/template_pdf.dart`
- Test: `grid_app/test/data/store_order_test.dart`
- Test: `grid_app/test/builder/grid_canvas_golden_test.dart`
- Create (generated by the golden run): `grid_app/test/builder/goldens/grid_canvas_sample.png`

**Interfaces:**
- Consumes: `DriftTemplateStore`, `renderTemplate`, `GridCanvas`, `sampleTemplate`
- Produces: `DriftTemplateStore.all()` returns templates ordered by `name`; `renderTemplate` draws a visible placeholder for unregistered cell types; a golden locks the GridCanvas render.

- [ ] **Step 1: Write the failing ordering test**

Create `grid_app/test/data/store_order_test.dart`:
```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/data/app_database.dart';
import 'package:scss_grid/sample/sample_template.dart';

void main() {
  test('all() returns templates ordered by name', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final store = DriftTemplateStore(db);
    await store.upsert(sampleTemplate().copyWith(id: 'b', name: 'Beta'));
    await store.upsert(sampleTemplate().copyWith(id: 'a', name: 'Alpha'));
    final names = (await store.all()).map((t) => t.name).toList();
    expect(names, ['Alpha', 'Beta']);
    await db.close();
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `cd grid_app && flutter test test/data/store_order_test.dart`
Expected: FAIL (insertion order `Beta, Alpha`, not name order).

- [ ] **Step 3: Add ORDER BY to `all()`**

In `grid_app/lib/data/app_database.dart`, change `DriftTemplateStore.all()` to order by name:
```dart
  @override
  Future<List<Template>> all() async {
    final query = db.select(db.templateRows)
      ..orderBy([(r) => OrderingTerm(expression: r.name)]);
    final rows = await query.get();
    return rows
        .map((r) => Template.fromJson(jsonDecode(r.json) as Map<String, dynamic>))
        .toList();
  }
```

- [ ] **Step 4: Run it to verify it passes**

Run: `cd grid_app && flutter test test/data/store_order_test.dart`
Expected: PASS.

- [ ] **Step 5: PDF unknown-control placeholder**

In `grid_app/lib/pdf/template_pdf.dart`, replace the content fallback so an unregistered type prints a visible marker instead of nothing. Change the cell content line:
```dart
        final spec = registry.specFor(cell.type);
        final content = spec?.paintPdf(cell, data) ??
            pw.Container(
              alignment: pw.Alignment.center,
              decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.red, width: 0.5)),
              child: pw.Text('?${cell.type}',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.red)),
            );
```
(Ensure `PdfColors` is available — it comes from `package:pdf/pdf.dart`, already imported in this file.)

- [ ] **Step 6: Write the golden test**

Create `grid_app/test/builder/grid_canvas_golden_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/builder/grid_canvas.dart';
import 'package:scss_grid/controls/default_controls.dart';
import 'package:scss_grid/sample/sample_template.dart';

void main() {
  testWidgets('GridCanvas matches its golden for the sample template',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 400,
            child: GridCanvas(
                template: sampleTemplate(), registry: buildDefaultRegistry()),
          ),
        ),
      ),
    ));
    await expectLater(
      find.byType(GridCanvas),
      matchesGoldenFile('goldens/grid_canvas_sample.png'),
    );
  });
}
```

- [ ] **Step 7: Generate the golden, then verify**

Run (first generate the baseline image, then re-run to verify it matches):
```bash
cd grid_app && flutter test --update-goldens test/builder/grid_canvas_golden_test.dart
flutter test test/builder/grid_canvas_golden_test.dart
```
Expected: the second run PASSES against the committed baseline.
> Goldens are host-rendered; this baseline is for this dev machine's Flutter. If CI on another OS is added later, regenerate or mark the golden CI-skip. Commit the generated `goldens/grid_canvas_sample.png`.

- [ ] **Step 8: Run analyze + full suite + commit**

Run: `cd grid_app && flutter analyze && flutter test`
Expected: `No issues found!` and all green.

```bash
cd /Users/xxf/Desktop/scss && git add -A && git commit -q -m "chore: order templates by name, PDF unknown-control placeholder, GridCanvas golden"
```

---

### Task 9: Manual simulator pass (controller, not a subagent)

**Files:** none

- [ ] **Step 1: Run the editor on the emulator and verify by observation**

```bash
flutter emulators --launch Medium_Phone_API_35
cd /Users/xxf/Desktop/scss/grid_app && flutter run -d emulator-5554
```
Verify and report what you see (not just "passed"):
1. New template → the editor shows the palette, grid steppers, and the canvas with grid lines.
2. Tap **Field** in the palette → a full-width field row is added at the first free row and becomes selected (blue highlight); the inspector appears.
3. In the inspector, edit the label → the canvas updates live; step the width down/up → the cell resizes; tap delete → it's removed.
4. Step **Cols**/**Rows** → the grid lines and "N × M grid" update; growing past A4 is blocked (no change).
5. Tap **Preview** → the PDF reflects the added control(s).
6. Save → returns to the list; reopen → edits persisted.

If anything misbehaves, report it as DONE_WITH_CONCERNS with specifics.

---

## Phase 1B-ii-a — Definition of Done

- A template can be edited without drag: add controls (palette), select (tap), edit props / width / delete (inspector), change grid rows & cols (steppers) — all guarded by `validateLayout`, all within A4.
- Unknown control types are visible (not silently dropped) on both canvas and PDF; the template list is name-ordered; a GridCanvas golden guards visual regressions.
- `flutter analyze` = 0 issues; `flutter test` all green; manual simulator pass confirms the feel.
- Drag (drag-to-place, drag-move, span handles, drag grid lines) is Phase 1B-ii-b.

## Self-Review (against spec)

**Spec coverage (Phase 1B-ii-a slice of spec §7 / §10.1 / deferred items):**
- §7 "点 cell 改 props" → Tasks 3, 6, 7 (propEditor + inspector + wiring). ✓
- §7 add controls to the grid (tap-to-add; drag is 1B-ii-b) → Tasks 5, 7. ✓
- §7 change rows/cols → Task 2 (`setCols`/`setRows`) + Task 7 steppers. ✓
- §3/§4 stays within A4, valid layout → `isValid`/`validateLayout` guard on every commit (Tasks 2, 7). ✓
- §10.1 control-agnostic (palette/inspector iterate the registry; propEditor on the spec) → Tasks 5, 6. ✓
- Deferred items (unknown-control placeholder, list ORDER BY, canvas golden) → Task 8. ✓
- Explicitly deferred to Phase 1B-ii-b: drag-to-place, drag-move, span-handle drag, drag grid lines (track size). Deferred further: rowSpan editing, per-cell move UI (steppers/drag), Cell.props immutability, valueType→enum.

**Placeholder scan:** No TBD/TODO; every code step has complete code. Task 9 is an explicit manual-observation step with concrete checks.

**Type consistency:** `cellCoordAtMm` (record `({int col,int row})`), `cellAtCoord`/`firstFreeRow`/`addCell`/`removeCell`/`updateCell`/`setCols`/`setRows`/`isValid`, `GridCanvas(selectedId:)`, `ControlPalette(registry:,onPick:)`, `CellInspector(cell:,spec:,maxColSpan:,onPropsChanged:,onColSpanChanged:,onDelete:)`, `BuilderScreen` (stateful) — names match across producing/consuming tasks. Reused 1A/1B-i names (`cellRectMm`, `validateLayout`, `addTrack`/`removeTrack`, `GridFrame.copyWith`, `renderTemplate`, `DriftTemplateStore`, `sampleTemplate`) are used as defined.
