# Builder — Free Placement (drag-to-place + remaining-width) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let controls be placed anywhere in the grid. Drag a control from the palette onto a target cell to drop it there (sized to the row's remaining free width); tapping a palette control adds it to the first free cell (not the whole next empty row); and fix the inspector so its property editor refreshes when you select a different control.

**Architecture:** Three independent pieces. (1) `CellInspector` wraps the control's `propEditor` in a `KeyedSubtree(key: ValueKey(cell.id))` so selecting a different cell rebuilds the editor fresh (the current `TextFormField(initialValue:)` keeps stale text because `initialValue` only seeds once). (2) Two pure placement ops in `editor_ops.dart` — `firstFreeCell` (row-major first empty cell) and `freeRunWidth` (free columns to the right) — and `BuilderScreen._addControl` uses them so tap-add fills the first free cell with the row's remaining width. (3) Palette items become `LongPressDraggable<ControlSpec>`, `EditableCanvas` wraps its canvas in a `DragTarget<ControlSpec>` that converts the drop position to a grid coord via its existing `RenderBox`/`_coordAt`, and `BuilderScreen` places the dropped control at that cell with the remaining-width span — all gated by the existing `isValid` guard. No model/persistence/PDF changes; this is builder-only and works on the current control set.

**Tech Stack:** Flutter 3.27.2 / Dart 3.6.1. Reuses: `cellAtCoord`/`addCell`/`isValid` (`editor_ops.dart`), `cellCoordAtMm` (`hit_test.dart`), `pageScale` (`canvas_metrics.dart`), `EditableCanvas`, `ControlPalette`, `CellInspector`, `ControlSpec`/`ControlRegistry`.

## Global Constraints

- **Grid is the unit.** Placement is in grid coordinates (`col`/`row`/`colSpan`); a dropped control snaps to the cell under the drop and spans whole columns. No sub-cell positioning.
- **Every placement stays valid + within A4.** All adds/places route through `addCell` then `isValid` (no overlap, in-bounds); invalid placements are no-ops. A drop on an occupied cell or with zero free width is a no-op.
- **Single scale source.** Drop-position→grid-coord uses the same `pageScale` + `cellCoordAtMm` the rest of the canvas uses (via `EditableCanvas`'s `RenderBox`), so it can't drift from the renderer.
- **Backward compatible.** Tap-to-add still works; on an empty template it still fills row 0 full width (`firstFreeCell`=(0,0), `freeRunWidth`=grid.cols). Existing builder tests stay green.
- **Builder-only.** No changes to the data model, persistence, fill mode, or PDF. The current `{Title, Field}` control set is unchanged (control decomposition is a later plan).
- Quality gate every code task: from `grid_app/`, `flutter analyze` = `No issues found!` and `flutter test` all green.
- Manual simulator pass at the end (Task 5, controller) — the drag-to-place gesture needs a device check.

---

### Task 0: Start a feature branch

**Files:** none (git only)

- [ ] **Step 1**

```bash
cd /Users/xxf/Desktop/scss
git checkout main && git checkout -b feat/builder-free-placement
git branch --show-current
```
Expected: `feat/builder-free-placement`.

---

### Task 1: Inspector property editor refreshes on cell change

**Files:**
- Modify: `grid_app/lib/builder/cell_inspector.dart`
- Test: `grid_app/test/builder/cell_inspector_refresh_test.dart`

**Interfaces:**
- Consumes: `CellInspector`, `FieldControl`.
- Produces: `CellInspector` wraps `spec.propEditor(...)` in a `KeyedSubtree(key: ValueKey(cell.id))` so the editor subtree is rebuilt fresh when the selected cell's id changes.

- [ ] **Step 1: Write the failing test**

Create `grid_app/test/builder/cell_inspector_refresh_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/builder/cell_inspector.dart';
import 'package:scss_grid/controls/field_control.dart';
import 'package:scss_grid/model/cell.dart';

// Host that can swap which cell the inspector shows, to mimic selecting a
// different control on the canvas.
class _Host extends StatefulWidget {
  const _Host();
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  Cell _cell = const Cell(id: 'a', col: 0, row: 0, colSpan: 12, type: 'field',
      props: {'label': 'Site Name', 'key': 'site_name', 'valueType': 'text'});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            TextButton(
              onPressed: () => setState(() {
                _cell = const Cell(id: 'b', col: 0, row: 1, colSpan: 12,
                    type: 'field',
                    props: {'label': 'Site City', 'key': 'site_city',
                        'valueType': 'text'});
              }),
              child: const Text('select-b'),
            ),
            CellInspector(
              cell: _cell,
              spec: FieldControl(),
              maxColSpan: 12,
              onPropsChanged: (_) {},
              onColSpanChanged: (_) {},
              onDelete: () {},
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  testWidgets('property editor shows the newly selected cell\'s label',
      (tester) async {
    await tester.pumpWidget(const _Host());
    // Inspector shows cell A's label in the editable field.
    expect(find.widgetWithText(TextFormField, 'Site Name'), findsOneWidget);

    // Select cell B.
    await tester.tap(find.text('select-b'));
    await tester.pumpAndSettle();

    // The editor must now show B's label, not A's stale text.
    expect(find.widgetWithText(TextFormField, 'Site City'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Site Name'), findsNothing);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd grid_app && flutter test test/builder/cell_inspector_refresh_test.dart`
Expected: FAIL — the editor still shows "Site Name" after selecting B (stale `TextFormField` controller).

- [ ] **Step 3: Wrap the propEditor in a keyed subtree**

In `grid_app/lib/builder/cell_inspector.dart`, replace:
```dart
          spec.propEditor(cell, onPropsChanged),
```
with:
```dart
          // Key by cell id so selecting a different control rebuilds the editor
          // subtree fresh — otherwise a TextFormField keeps its stale text
          // (initialValue only seeds the controller once).
          KeyedSubtree(
            key: ValueKey('propeditor-${cell.id}'),
            child: spec.propEditor(cell, onPropsChanged),
          ),
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd grid_app && flutter test test/builder/cell_inspector_refresh_test.dart`
Expected: PASS.

- [ ] **Step 5: Run existing inspector tests + analyze**

Run: `cd grid_app && flutter test test/builder/cell_inspector_test.dart && flutter analyze`
Expected: PASS and `No issues found!` (editing the same cell keeps the same id → key stable → typing not disrupted).

- [ ] **Step 6: Commit**

```bash
cd /Users/xxf/Desktop/scss && git add -A && git commit -q -m "fix(builder): inspector property editor refreshes on cell change"
```

---

### Task 2: Placement pure ops — `firstFreeCell` + `freeRunWidth`

**Files:**
- Modify: `grid_app/lib/builder/editor_ops.dart`
- Test: `grid_app/test/builder/placement_ops_test.dart`

**Interfaces:**
- Consumes: `cellAtCoord` (existing in `editor_ops.dart`), `Template`.
- Produces:
  - `({int col, int row})? firstFreeCell(Template t)` — first empty cell in row-major order, or null if the grid is full.
  - `int freeRunWidth(Template t, int col, int row)` — number of consecutive empty columns starting at `(col,row)` going right, stopping at an occupied cell or the grid edge; 0 if `(col,row)` itself is occupied.

- [ ] **Step 1: Write the failing test**

Create `grid_app/test/builder/placement_ops_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/builder/editor_ops.dart';
import 'package:scss_grid/model/cell.dart';
import 'package:scss_grid/model/grid_frame.dart';
import 'package:scss_grid/model/template.dart';

Template _tpl(List<Cell> cells) => Template(
      id: 't',
      name: 'n',
      page: const PageSize.a4(),
      grid: GridFrame.uniform(
          xMm: 0, yMm: 0, cols: 6, rows: 4, colWidthMm: 20, rowHeightMm: 10),
      cells: cells,
    );

void main() {
  test('firstFreeCell is (0,0) on an empty grid', () {
    expect(firstFreeCell(_tpl(const [])), (col: 0, row: 0));
  });

  test('firstFreeCell skips occupied cells row-major', () {
    // A 3-wide cell on row 0 -> first free is (3,0).
    final t = _tpl(const [
      Cell(id: 'a', col: 0, row: 0, colSpan: 3, type: 'field'),
    ]);
    expect(firstFreeCell(t), (col: 3, row: 0));
  });

  test('firstFreeCell returns null when the grid is full', () {
    final t = _tpl(const [
      Cell(id: 'a', col: 0, row: 0, colSpan: 6, rowSpan: 4, type: 'field'),
    ]);
    expect(firstFreeCell(t), isNull);
  });

  test('freeRunWidth counts free columns to the right', () {
    // cols 0..2 occupied; from (3,0) there are 3 free cols (3,4,5).
    final t = _tpl(const [
      Cell(id: 'a', col: 0, row: 0, colSpan: 3, type: 'field'),
    ]);
    expect(freeRunWidth(t, 3, 0), 3);
    expect(freeRunWidth(t, 0, 0), 0); // (0,0) is occupied
    expect(freeRunWidth(t, 0, 1), 6); // empty row -> full width
  });

  test('freeRunWidth stops at the next occupied cell', () {
    // col 0 free, cols 2..3 occupied -> from (0,0) only 2 free (0,1).
    final t = _tpl(const [
      Cell(id: 'a', col: 2, row: 0, colSpan: 2, type: 'field'),
    ]);
    expect(freeRunWidth(t, 0, 0), 2);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd grid_app && flutter test test/builder/placement_ops_test.dart`
Expected: FAIL (`firstFreeCell`/`freeRunWidth` not defined).

- [ ] **Step 3: Add the ops to `editor_ops.dart`**

Append to `grid_app/lib/builder/editor_ops.dart`:
```dart
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd grid_app && flutter test test/builder/placement_ops_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
cd /Users/xxf/Desktop/scss && git add -A && git commit -q -m "feat(builder): firstFreeCell + freeRunWidth placement ops"
```

---

### Task 3: Tap-add fills the first free cell (not the whole next row)

**Files:**
- Modify: `grid_app/lib/builder/builder_screen.dart` (`_addControl`)
- Test: `grid_app/test/builder/add_control_placement_test.dart`

**Interfaces:**
- Consumes: `firstFreeCell`, `freeRunWidth`, `addCell`, `isValid` (Task 2 + existing).
- Produces: `_addControl` places the new cell at `firstFreeCell` with `colSpan = freeRunWidth` of that position.

- [ ] **Step 1: Write the failing test**

Create `grid_app/test/builder/add_control_placement_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/builder/builder_screen.dart';
import 'package:scss_grid/controls/default_controls.dart';
import 'package:scss_grid/data/template_store.dart';
import 'package:scss_grid/model/cell.dart';
import 'package:scss_grid/model/grid_frame.dart';
import 'package:scss_grid/model/template.dart';

// A template with row 0 half-occupied (cols 0..5 by a field), so a newly added
// control should land at (6,0) spanning the remaining 6 columns — NOT on row 1.
Template _partial() => Template(
      id: 'p',
      name: 'Partial',
      page: const PageSize.a4(),
      grid: GridFrame.uniform(
          xMm: 10, yMm: 10, cols: 12, rows: 16, colWidthMm: 15, rowHeightMm: 8),
      cells: const [
        Cell(id: 'a', col: 0, row: 0, colSpan: 6, type: 'field',
            props: {'label': 'L', 'key': 'k', 'valueType': 'text'}),
      ],
    );

void main() {
  testWidgets('tapping a palette control fills the first free cell on the row',
      (tester) async {
    final store = InMemoryTemplateStore();
    await tester.pumpWidget(MaterialApp(
      home: BuilderScreen(
          template: _partial(),
          registry: buildDefaultRegistry(),
          store: store),
    ));
    await tester.tap(find.text('Field')); // palette item
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Save'));
    await tester.pump();

    final saved = await store.get('p');
    expect(saved!.cells.length, 2);
    final added = saved.cells.firstWhere((c) => c.id != 'a');
    expect([added.col, added.row, added.colSpan], [6, 0, 6]);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd grid_app && flutter test test/builder/add_control_placement_test.dart`
Expected: FAIL — the current `_addControl` adds on row 1 full width (uses `firstFreeRow` + `grid.cols`), so the added cell is at `[0, 1, 12]`.

- [ ] **Step 3: Update `_addControl`**

In `grid_app/lib/builder/builder_screen.dart`, replace the whole `_addControl` method:
```dart
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
```
with:
```dart
  void _addControl(ControlSpec spec) {
    final pos = firstFreeCell(_t);
    if (pos == null) return; // grid full
    final span = freeRunWidth(_t, pos.col, pos.row);
    if (span < 1) return;
    final cell = Cell(
      id: _newId(spec.type),
      col: pos.col,
      row: pos.row,
      colSpan: span,
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
```

- [ ] **Step 4: Run the new test + existing builder tests + analyze**

Run: `cd grid_app && flutter test test/builder/add_control_placement_test.dart test/builder/builder_screen_test.dart && flutter analyze`
Expected: PASS (new placement test; existing add/delete/save tests still pass — on an empty template `firstFreeCell`=(0,0), `freeRunWidth`=12, so the first add is still full-width row 0) and `No issues found!`.
Note: `firstFreeRow` may now be unused in `builder_screen.dart`. If `flutter analyze` flags the import or the symbol as unused, leave the `editor_ops.dart` import (other symbols are used) — `firstFreeRow` stays defined in `editor_ops.dart` for its own tests; only remove a `builder_screen.dart` reference if analyze complains, which it will not since it's an imported top-level function, not a local.

- [ ] **Step 5: Commit**

```bash
cd /Users/xxf/Desktop/scss && git add -A && git commit -q -m "feat(builder): tap-add fills the first free cell with remaining width"
```

---

### Task 4: Drag a control from the palette onto the grid to place it

**Files:**
- Modify: `grid_app/lib/builder/control_palette.dart` (items become `LongPressDraggable`)
- Modify: `grid_app/lib/builder/editable_canvas.dart` (add `onDropControl` + a `DragTarget`)
- Modify: `grid_app/lib/builder/builder_screen.dart` (handle the drop → place)
- Test: `grid_app/test/builder/palette_drag_test.dart`

**Interfaces:**
- Consumes: `ControlSpec`, `firstFreeCell`-style placement via `freeRunWidth`, `cellAtCoord`, `addCell`, `isValid`, `EditableCanvas._coordAt` (existing).
- Produces:
  - `ControlPalette` items are `LongPressDraggable<ControlSpec>(data: spec, ...)` and keep their existing `onTap`→`onPick`.
  - `EditableCanvas` gains `final void Function(ControlSpec spec, int col, int row)? onDropControl;` and wraps its canvas in a `DragTarget<ControlSpec>` whose `onAcceptWithDetails` converts the drop's global offset to a grid coord via `_coordAt` and calls `onDropControl`.
  - `BuilderScreen._placeDropped(spec, col, row)`: if the target cell is free, add a cell at `(col,row)` spanning `freeRunWidth(_t, col, row)`, gated by `isValid`.

- [ ] **Step 1: Write the failing test**

Create `grid_app/test/builder/palette_drag_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/builder/control_palette.dart';
import 'package:scss_grid/builder/builder_screen.dart';
import 'package:scss_grid/controls/default_controls.dart';
import 'package:scss_grid/data/template_store.dart';
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
  testWidgets('palette items are draggable', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: BuilderScreen(
          template: _empty(),
          registry: buildDefaultRegistry(),
          store: InMemoryTemplateStore()),
    ));
    // one LongPressDraggable per registered control (Title, Field).
    expect(find.byType(LongPressDraggable<dynamic>),
        findsNWidgets(buildDefaultRegistry().all.length));
  });

  testWidgets('long-press-dragging a palette control onto the grid places it there',
      (tester) async {
    final store = InMemoryTemplateStore();
    await tester.pumpWidget(MaterialApp(
      home: BuilderScreen(
          template: _empty(),
          registry: buildDefaultRegistry(),
          store: store),
    ));
    await tester.pumpAndSettle();

    final fieldItem = find.text('Field');
    final start = tester.getCenter(fieldItem);
    // Target a point inside the canvas, below the title band, in the grid area.
    final canvasCenter = tester.getCenter(find.byType(BuilderScreen));

    final gesture = await tester.startGesture(start);
    await tester.pump(const Duration(milliseconds: 600)); // trigger long-press
    await gesture.moveTo(canvasCenter);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Save'));
    await tester.pump();
    final saved = await store.get('e');
    expect(saved!.cells, isNotEmpty); // a control was placed by the drop
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd grid_app && flutter test test/builder/palette_drag_test.dart`
Expected: FAIL — no `LongPressDraggable` in the palette; the drop does nothing.

- [ ] **Step 3: Make palette items draggable**

In `grid_app/lib/builder/control_palette.dart`, replace the `InkWell(...)` (the `child:` of the `Padding`) with a `LongPressDraggable` wrapping it. Change:
```dart
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
```
to:
```dart
              child: LongPressDraggable<ControlSpec>(
                data: spec,
                dragAnchorStrategy: pointerDragAnchorStrategy,
                feedback: Material(
                  color: Colors.transparent,
                  child: Chip(
                    avatar: Icon(spec.icon, size: 18),
                    label: Text(spec.label),
                  ),
                ),
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
```

- [ ] **Step 4: Add a `DragTarget` to `EditableCanvas`**

In `grid_app/lib/builder/editable_canvas.dart`:

1. Add the import (with the others):
```dart
import '../controls/control_spec.dart';
```
2. Add the callback field + constructor param. After the `onResizeRow` field:
```dart
  final void Function(int boundary, double deltaMm) onResizeRow;

  /// A control was dropped (long-press-dragged from the palette) onto grid
  /// cell (col,row). Null disables drop placement.
  final void Function(ControlSpec spec, int col, int row)? onDropControl;
```
and in the constructor add `this.onDropControl,` (after `required this.onResizeRow,`):
```dart
    required this.onResizeRow,
    this.onDropControl,
  });
```
3. Wrap the whole built canvas in a `DragTarget`. In `build`, change the `return LayoutBuilder(` line to wrap it:
```dart
    return DragTarget<ControlSpec>(
      onAcceptWithDetails: (d) {
        final c = _coordAt(d.offset);
        if (c != null) widget.onDropControl?.call(d.data, c.col, c.row);
      },
      builder: (context, candidate, rejected) => LayoutBuilder(
```
and close the extra paren/brace at the very end of `build` — the existing `LayoutBuilder(...)` ends with `);`. Change that closing to `));` and add the `DragTarget` close. Concretely, the `build` method's final lines change from:
```dart
        );
      },
    );
  }
```
to:
```dart
        );
      },
      ),
    );
  }
```

- [ ] **Step 5: Handle the drop in `BuilderScreen`**

In `grid_app/lib/builder/builder_screen.dart`:

1. Add a placement handler method (next to `_addControl`):
```dart
  void _placeDropped(ControlSpec spec, int col, int row) {
    if (cellAtCoord(_t, col, row) != null) return; // occupied
    final span = freeRunWidth(_t, col, row);
    if (span < 1) return;
    final cell = Cell(
      id: _newId(spec.type),
      col: col,
      row: row,
      colSpan: span,
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
```
2. Wire it into the `EditableCanvas` in `_canvasArea` — add the `onDropControl:` argument:
```dart
            onResizeRow: (boundary, deltaMm) => _commit(
                _t.copyWith(grid: resizeRowBoundary(_t.grid, boundary, deltaMm))),
            onDropControl: _placeDropped,
          ),
```
(`cellAtCoord` is already available via the existing `import 'editor_ops.dart';`.)

- [ ] **Step 6: Run the drag test + full suite + analyze**

Run: `cd grid_app && flutter analyze && flutter test`
Expected: `No issues found!` and ALL green (the new palette-drag tests plus every existing test — `EditableCanvas` still contains a `GridCanvas`, tap-select/drag-move/handles unaffected).
If the long-press-drag test is flaky on timing, adjust the `pump` duration to `const Duration(milliseconds: 700)` (just over the long-press threshold); the placement assertion (`cells` non-empty) is the real check.

- [ ] **Step 7: Commit**

```bash
cd /Users/xxf/Desktop/scss && git add -A && git commit -q -m "feat(builder): drag a control from the palette onto the grid to place it"
```

---

### Task 5: Manual simulator pass (controller, not a subagent)

**Files:** none

- [ ] **Step 1: Run on the emulator and verify placement by observation**

```bash
flutter emulators --launch Medium_Phone_API_35
cd /Users/xxf/Desktop/scss/grid_app && flutter run -d emulator-5554
```
Verify and report what you see:
1. Open a template in the builder. Tap **Field** → it lands in the first free cell (e.g. a fresh row, full width). Select it and shrink its **Width** to ~5. Now tap **Field** again → the second one lands in the SAME row's remaining columns (to the right), not on a new row.
2. **Long-press** a palette item (Title/Field) → a drag chip appears → drag it over an empty area of the grid → release → a control is placed at the cell under the release point, spanning that row's remaining free width.
3. Dropping onto an already-occupied cell does nothing (no overlap created).
4. Select control A (e.g. "Site Name"), then select control B (e.g. "Site City") → the bottom **Label** field now shows B's label (no longer stale).
5. Preview/Save still work; reopen → placements persisted.

If a drag/drop or the inspector refresh misbehaves, report DONE_WITH_CONCERNS with specifics.

---

## Definition of Done

- Controls can be placed anywhere free in the grid: tap-add fills the first free cell with the row's remaining width, and long-press-drag from the palette drops a control at the target cell (remaining-width span). Both are gated by `isValid` (no overlap / within A4).
- The inspector's property editor refreshes when a different control is selected (no stale `Label`).
- Drop-position→grid-coord uses the canvas's own `RenderBox` + shared `pageScale`/`cellCoordAtMm`, so it can't drift from the renderer.
- `flutter analyze` = 0; `flutter test` all green; manual simulator pass confirms tap-add, drag-place, occupied-no-op, and inspector refresh.
- Builder-only: no model/persistence/fill/PDF changes; the `{Title, Field}` control set is unchanged. Control decomposition (label/text/number/coordinate toolbox), content-only + collapsed borders, and per-control rich property sets are the NEXT plan (P2).

## Self-Review (against the agreed design)

**Coverage of the user's requests:**
- "控件可以放在网格的任意地方 / 默认占剩余宽度" → Tasks 2 (`firstFreeCell`/`freeRunWidth`) + 3 (tap-add) + 4 (drag-place), span = remaining width. ✓
- "手机上拖控件更好操作" → Task 4 (`LongPressDraggable` palette + `DragTarget` canvas). ✓
- Problem 1 "Label 不随选择变化" → Task 1 (`KeyedSubtree(ValueKey(cell.id))`). ✓
- "布局完全由网格确定" → placement is in grid coords, snapped to cells, gated by `isValid`. ✓
- Prerequisite for the new model: drag/tap can place multiple controls per row, so a label-cell + value-cell row becomes buildable in P2. ✓

**Placeholder scan:** No TBD/TODO; every code step has complete code. Task 5 is an explicit manual-observation step. The flaky-timing note in Task 4 is a concrete tuning instruction, not a placeholder.

**Type consistency:** `firstFreeCell(Template)→({int col,int row})?`, `freeRunWidth(Template,int,int)→int`, `EditableCanvas.onDropControl(ControlSpec,int,int)`, `LongPressDraggable<ControlSpec>`, `DragTarget<ControlSpec>`, and `_placeDropped(spec,col,row)` are consistent across Tasks 2–4 and the tests.
