# Grid-Native Controls — P2b (Collapsed Borders + Grid Rendering) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the form a clean table look. Controls stop drawing their own borders; a shared "border layer" outlines every occupied control's cell as lines centered on the grid boundaries — so adjacent controls' shared edges collapse to a single width — drawn identically on the builder canvas, the fill canvas, and the PDF. In the builder, every control gets a visible outline (you can see how many cells it spans, including the title) and the faint placement grid no longer shows through controls (only empty cells keep it).

**Architecture:** A pure helper `controlOutlineEdges(Template)` returns the 4 edges of each control's mm-rect as `GridEdge`s (position + extent in mm). A small Flutter helper `borderLineWidgets(edges, scale, ...)` renders them as fixed-thickness `Positioned` lines centered on each boundary — shared edges land on the same coordinate so they coincide (no double-thickness). The 4 controls (`label`/`text`/`number`/`coordinate`) drop their `Border.all` boxes (content-only). `GridCanvas` fills each control cell with opaque white (covering the faint grid lines under it) and draws the border layer on top; `FillCanvas` draws the border layer over its content; `template_pdf` draws the same edges as thin PDF rectangles. One geometry, three renderers → WYSIWYG.

**Tech Stack:** Flutter 3.27.2 / Dart 3.6.1. Reuses: `cellRectMm` (`grid/geometry.dart`), `RectMm` (`model/rect_mm.dart`, has `rightMm`/`bottomMm`), `pageScale`/`mmToPt`, `GridCanvas`/`FillCanvas`/`renderTemplate`, the P2a controls.

## Global Constraints

- **Collapse via centered lines.** Each control-cell edge is drawn as a fixed-thickness line CENTERED on its mm boundary. Two adjacent controls share a boundary coordinate, so their edges coincide → single visible width. Do NOT use `Border.all` (inset borders double at shared edges).
- **One geometry, three renderers.** `controlOutlineEdges(Template)` is the single source; `GridCanvas`, `FillCanvas`, and `template_pdf` all render those same mm edges (scaled to px / pt). What the builder shows is what the PDF prints.
- **Controls are content-only.** `label`/`text`/`number`/`coordinate` render their content WITHOUT a border box. The border comes from the layer, not the control. (`title` already has no border.)
- **Builder issue 1 (visible span):** the border layer outlines EVERY control (incl. title, incl. unselected ones), so its occupied cells are always visible.
- **Builder issue 2 (no grid through controls):** in `GridCanvas`, each control cell gets an opaque white fill that covers the faint interior grid lines beneath it; the faint grid stays visible only in EMPTY cells. Keep the existing faint full grid (`_gridLines`) under the fills.
- **No model/data/fill-logic changes.** Pure rendering. The survey `data` map, keys, persistence, and PDF data flow are untouched.
- Quality gate every code task: from `grid_app/`, `flutter analyze` = `No issues found!` and `flutter test` green (golden tests regenerate where the render changed — `flutter test --update-goldens <file>` then re-run).
- Manual simulator pass at the end (Task 6, controller).

---

### Task 0: Start a feature branch

**Files:** none (git only)

- [ ] **Step 1**

```bash
cd /Users/xxf/Desktop/scss
git checkout main && git checkout -b feat/grid-native-controls-p2b
git branch --show-current
```
Expected: `feat/grid-native-controls-p2b`.

---

### Task 1: `controlOutlineEdges` geometry helper

**Files:**
- Create: `grid_app/lib/grid/cell_borders.dart`
- Test: `grid_app/test/grid/cell_borders_test.dart`

**Interfaces:**
- Consumes: `cellRectMm` (`grid/geometry.dart`), `Template`, `RectMm`.
- Produces:
  ```dart
  class GridEdge {
    final bool vertical;   // true = vertical line (constant x), false = horizontal
    final double atMm;     // the line's position (x if vertical, y if horizontal)
    final double fromMm;   // start along the other axis
    final double toMm;     // end along the other axis
    const GridEdge({required vertical, required atMm, required fromMm, required toMm});
  }
  List<GridEdge> controlOutlineEdges(Template t); // 4 edges per cell (left,right,top,bottom)
  ```

- [ ] **Step 1: Write the failing test**

Create `grid_app/test/grid/cell_borders_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/grid/cell_borders.dart';
import 'package:scss_grid/model/cell.dart';
import 'package:scss_grid/model/grid_frame.dart';
import 'package:scss_grid/model/template.dart';

Template _tpl(List<Cell> cells) => Template(
      id: 't',
      name: 'n',
      page: const PageSize.a4(),
      grid: GridFrame.uniform(
          xMm: 10, yMm: 10, cols: 4, rows: 4, colWidthMm: 20, rowHeightMm: 10),
      cells: cells,
    );

void main() {
  test('a single cell yields its 4 edges at the right mm positions', () {
    // cell at col1,row0, colSpan2 -> x 30..70mm, y 10..20mm
    final t = _tpl(const [
      Cell(id: 'a', col: 1, row: 0, colSpan: 2, type: 'text'),
    ]);
    final e = controlOutlineEdges(t);
    expect(e.length, 4);
    // left vertical at x=30, y 10..20
    expect(e.any((g) => g.vertical && g.atMm == 30 && g.fromMm == 10 && g.toMm == 20), isTrue);
    // right vertical at x=70
    expect(e.any((g) => g.vertical && g.atMm == 70 && g.fromMm == 10 && g.toMm == 20), isTrue);
    // top horizontal at y=10, x 30..70
    expect(e.any((g) => !g.vertical && g.atMm == 10 && g.fromMm == 30 && g.toMm == 70), isTrue);
    // bottom horizontal at y=20
    expect(e.any((g) => !g.vertical && g.atMm == 20 && g.fromMm == 30 && g.toMm == 70), isTrue);
  });

  test('adjacent cells share an edge coordinate (collapse precondition)', () {
    // label col0..1 (x10..30), value col2..3 (x30..50): both have a vertical edge at x=30
    final t = _tpl(const [
      Cell(id: 'l', col: 0, row: 0, colSpan: 2, type: 'label'),
      Cell(id: 'v', col: 2, row: 0, colSpan: 2, type: 'text'),
    ]);
    final verticalsAt30 =
        controlOutlineEdges(t).where((g) => g.vertical && g.atMm == 30).toList();
    // label's right edge AND value's left edge — same coordinate (drawn as coincident lines)
    expect(verticalsAt30.length, 2);
  });

  test('empty template yields no edges', () {
    expect(controlOutlineEdges(_tpl(const [])), isEmpty);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd grid_app && flutter test test/grid/cell_borders_test.dart`
Expected: FAIL (file not found).

- [ ] **Step 3: Write the helper**

Create `grid_app/lib/grid/cell_borders.dart`:
```dart
import '../model/template.dart';
import 'geometry.dart';

/// One straight edge of a control's cell rectangle, in millimetres. A renderer
/// draws it as a fixed-thickness line CENTERED on [atMm]; adjacent controls
/// share a boundary coordinate, so their coincident edges collapse to a single
/// visible width.
class GridEdge {
  /// true = vertical line at a constant x ([atMm]); false = horizontal at y.
  final bool vertical;
  final double atMm;
  final double fromMm;
  final double toMm;

  const GridEdge({
    required this.vertical,
    required this.atMm,
    required this.fromMm,
    required this.toMm,
  });
}

/// The 4 outline edges (left, right, top, bottom) of every control's mm-rect.
/// Shared by the builder canvas, the fill canvas and the PDF so the table
/// borders are identical (WYSIWYG).
List<GridEdge> controlOutlineEdges(Template t) {
  final edges = <GridEdge>[];
  for (final cell in t.cells) {
    final r = cellRectMm(t.grid, cell);
    edges.add(GridEdge(
        vertical: true, atMm: r.leftMm, fromMm: r.topMm, toMm: r.bottomMm));
    edges.add(GridEdge(
        vertical: true, atMm: r.rightMm, fromMm: r.topMm, toMm: r.bottomMm));
    edges.add(GridEdge(
        vertical: false, atMm: r.topMm, fromMm: r.leftMm, toMm: r.rightMm));
    edges.add(GridEdge(
        vertical: false, atMm: r.bottomMm, fromMm: r.leftMm, toMm: r.rightMm));
  }
  return edges;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd grid_app && flutter test test/grid/cell_borders_test.dart`
Expected: PASS (3 tests). (If `RectMm` lacks `rightMm`/`bottomMm`, they exist — `EditableCanvas` already uses `r.rightMm`/`r.bottomMm`.)

- [ ] **Step 5: Commit**

```bash
cd /Users/xxf/Desktop/scss && git add -A && git commit -q -m "feat(grid): controlOutlineEdges (per-control mm border edges)"
```

---

### Task 2: Controls render content-only (drop their border boxes)

**Files:**
- Modify: `grid_app/lib/controls/label_control.dart`
- Modify: `grid_app/lib/controls/text_control.dart`
- Modify: `grid_app/lib/controls/number_control.dart`
- Modify: `grid_app/lib/controls/coordinate_control.dart`
- Test: existing control tests (`label_control_test.dart`, `text_number_control_test.dart`, `coordinate_control_test.dart`, `preview_widget_test.dart`) must stay green.

**Interfaces:**
- Produces: each control's `previewWidget`, `fillWidget`, and `paintPdf` render content WITHOUT a `Border.all` box (the border layer draws the outline). `title` is unchanged (already borderless).

- [ ] **Step 1: Remove the borders**

In each of the four control files, remove ONLY the border decoration (keep padding/alignment/content). Specifically:

`label_control.dart`:
- `previewWidget`: remove `decoration: BoxDecoration(border: Border.all(width: 0.5, color: const Color(0xFFBDBDBD))),` from the `Container` (keep `padding`, `alignment`, `child`).
- `paintPdf`: remove `decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),` from the `pw.Container`.

`text_control.dart`:
- `previewWidget`: remove the `decoration: BoxDecoration(border: Border.all(...))` (keep padding/alignment/child).
- `fillWidget`: the `TextFormField` is wrapped in a `Container(decoration: BoxDecoration(border: Border.all(...)), child: ...)`. Remove the wrapper `Container` (or its `decoration`) so the `TextFormField` is returned directly (keep its `InputDecoration` incl. `hintText`). Simplest: replace `Container(decoration: ..., child: TextFormField(...))` with just `TextFormField(...)`.
- `paintPdf`: remove `decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),`.

`number_control.dart`: same three removals as text_control (preview decoration, fillWidget wrapper Container, paintPdf decoration).

`coordinate_control.dart`:
- `previewWidget`: remove the border decoration.
- `paintPdf`: remove the border decoration.
- `fillWidget`: the no-location plain `TextFormField` branch is wrapped in a `Container(decoration: Border.all..., child: TextFormField)` → return the `TextFormField` directly.
- `_CoordinateField.build`: its outer `Container(decoration: BoxDecoration(border: Border.all(...)), child: Row(...))` → remove the `decoration` (keep the `Container`/`Row` and the text+button) OR keep a bare `Row`. Keep the `Row` (text field + GPS button) without the border box.

- [ ] **Step 2: Run the control tests**

Run: `cd grid_app && flutter test test/controls/`
Expected: PASS. The control tests assert text/value/placeholder/keyboard/propEditor behavior — none assert the border — so removing borders keeps them green. If any test fails because it looked for a `Container` with a border, update it to assert the content instead.

- [ ] **Step 3: Analyze + commit**

```bash
cd /Users/xxf/Desktop/scss/grid_app && flutter analyze
cd /Users/xxf/Desktop/scss && git add -A && git commit -q -m "refactor(controls): content-only render (borders move to the border layer)"
```
Expected: `No issues found!`, then commit. (Until Tasks 3–5 add the layer, controls render borderless — that is expected mid-refactor; the suite stays green.)

---

### Task 3: Border layer + white fills in `GridCanvas`

**Files:**
- Create: `grid_app/lib/builder/border_layer.dart`
- Modify: `grid_app/lib/builder/grid_canvas.dart`
- Test: `grid_app/test/builder/border_layer_test.dart`
- Golden: regenerate `grid_app/test/builder/goldens/grid_canvas_sample.png`

**Interfaces:**
- Consumes: `GridEdge`/`controlOutlineEdges` (Task 1).
- Produces:
  - `border_layer.dart`: `const Color kCellBorderColor = Color(0xFF455A64); const double kCellBorderPx = 1.0;` and `List<Widget> borderLineWidgets(List<GridEdge> edges, double scale, {Color color = kCellBorderColor, double thickness = kCellBorderPx})` — each edge → a `Positioned` `ColoredBox` line centered on its boundary.
  - `GridCanvas`: each control cell gets an opaque white fill under its content (covers the faint grid within the control); the border layer (`borderLineWidgets(controlOutlineEdges(template), scale)`) is drawn on top of the cells.

- [ ] **Step 1: Write the failing test**

Create `grid_app/test/builder/border_layer_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/builder/border_layer.dart';
import 'package:scss_grid/grid/cell_borders.dart';

void main() {
  test('borderLineWidgets renders one Positioned per edge, centered', () {
    const edges = [
      GridEdge(vertical: true, atMm: 30, fromMm: 10, toMm: 20),
      GridEdge(vertical: false, atMm: 10, fromMm: 30, toMm: 70),
    ];
    final w = borderLineWidgets(edges, 2.0, thickness: 1.0);
    expect(w.length, 2);
    final vert = w[0] as Positioned;
    // vertical line at x=30mm*2 = 60, centered → left = 60 - 0.5 = 59.5; width = 1
    expect(vert.left, 59.5);
    expect(vert.width, 1.0);
    expect(vert.top, 20.0); // 10mm*2
    expect(vert.height, 20.0); // (20-10)*2
    final horiz = w[1] as Positioned;
    // horizontal at y=10mm*2=20, centered → top = 20 - 0.5 = 19.5; height = 1
    expect(horiz.top, 19.5);
    expect(horiz.height, 1.0);
    expect(horiz.left, 60.0); // 30mm*2
    expect(horiz.width, 80.0); // (70-30)*2
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd grid_app && flutter test test/builder/border_layer_test.dart`
Expected: FAIL (file not found).

- [ ] **Step 3: Write `border_layer.dart`**

Create `grid_app/lib/builder/border_layer.dart`:
```dart
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
```

- [ ] **Step 4: Run the helper test**

Run: `cd grid_app && flutter test test/builder/border_layer_test.dart`
Expected: PASS.

- [ ] **Step 5: Wire white fill + border layer into `GridCanvas`**

In `grid_app/lib/builder/grid_canvas.dart`:
1. Add imports (with the others):
```dart
import '../grid/cell_borders.dart';
import 'border_layer.dart';
```
2. In `_cell`, give the content an opaque white fill under it so the faint grid lines don't show through the control. Change the `content` `Positioned`'s child `Stack` so the content sits on a white box. Specifically, wrap `content` with a white background — replace the `child: Stack(fit: StackFit.expand, children: [ content, if (cell.id == selectedId) ... ])` so the first child is `ColoredBox(color: Colors.white, child: content)`:
```dart
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: Colors.white, child: content),
          if (cell.id == selectedId)
            IgnorePointer(
              child: DecoratedBox(
                key: const ValueKey('cell-highlight'),
                position: DecorationPosition.foreground,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.blue, width: 2),
                ),
              ),
            ),
        ],
      ),
```
3. In `build`, add the border layer as the LAST children of the outer `Stack` (after the `for (final cell ...) _cell(...)` line), so it draws on top of the white-filled cells:
```dart
              for (final cell in template.cells) _cell(cell, scale),
              ...borderLineWidgets(controlOutlineEdges(template), scale),
```

- [ ] **Step 6: Regenerate the golden + run builder tests**

The canvas render changed (white fills + solid cell borders), so the golden must be updated:
```bash
cd grid_app && flutter test --update-goldens test/builder/grid_canvas_golden_test.dart
flutter test test/builder/ && flutter analyze
```
Expected: golden regenerated; `test/builder/` green; `No issues found!`.

- [ ] **Step 7: Commit**

```bash
cd /Users/xxf/Desktop/scss && git add -A && git commit -q -m "feat(builder): cell border layer + white fills in GridCanvas"
```

---

### Task 4: Border layer in `FillCanvas`

**Files:**
- Modify: `grid_app/lib/fill/fill_canvas.dart`
- Test: `grid_app/test/fill/fill_canvas_test.dart` (stays green; optionally assert a border ColoredBox)

**Interfaces:**
- Consumes: `controlOutlineEdges`, `borderLineWidgets`.
- Produces: `FillCanvas` draws the same border layer over its content cells (content is already borderless after Task 2).

- [ ] **Step 1: Wire the border layer into `FillCanvas`**

In `grid_app/lib/fill/fill_canvas.dart`:
1. Add imports:
```dart
import '../builder/border_layer.dart';
import '../grid/cell_borders.dart';
```
2. In `build`, add the border layer as the LAST children of the inner `Stack` (after the `for (final cell in template.cells) _cell(cell, scale)` line):
```dart
              for (final cell in template.cells) _cell(cell, scale),
              ...borderLineWidgets(controlOutlineEdges(template), scale),
```

- [ ] **Step 2: Run the fill tests + analyze**

Run: `cd grid_app && flutter test test/fill/ && flutter analyze`
Expected: PASS (the existing `fill_canvas_test` renders the title text + field + value; the added border layer doesn't change those `find.text` assertions) and `No issues found!`.

- [ ] **Step 3: Commit**

```bash
cd /Users/xxf/Desktop/scss && git add -A && git commit -q -m "feat(fill): cell border layer in FillCanvas"
```

---

### Task 5: Border layer in the PDF (`template_pdf`)

**Files:**
- Modify: `grid_app/lib/pdf/template_pdf.dart`
- Test: `grid_app/test/pdf/template_pdf_test.dart` + `grid_app/test/integration/build_to_pdf_test.dart` (stay green — still produce a `%PDF`)

**Interfaces:**
- Consumes: `controlOutlineEdges`, `mmToPt`.
- Produces: `renderTemplate` draws the same control outline edges as thin PDF rectangles (centered on each boundary), so the exported PDF has the single-width table borders matching the canvases.

- [ ] **Step 1: Draw the edges in the PDF**

In `grid_app/lib/pdf/template_pdf.dart`:
1. Add the import (with the others):
```dart
import '../grid/cell_borders.dart';
```
2. After the loop that adds each cell's `pw.Positioned` content to `children`, add the border edges to the same `children` list before `return pw.Stack(children: children);`. Use a thin border colour/thickness in points:
```dart
        // Cell border layer: each control-cell edge as a thin line centered on
        // its mm boundary (shared edges coincide → single width), matching the
        // builder/fill canvases.
        const borderPt = 0.7;
        final borderColor = PdfColor.fromInt(0xFF455A64);
        for (final e in controlOutlineEdges(t)) {
          if (e.vertical) {
            children.add(pw.Positioned(
              left: e.atMm * mmToPt - borderPt / 2,
              top: e.fromMm * mmToPt,
              child: pw.Container(
                width: borderPt,
                height: (e.toMm - e.fromMm) * mmToPt,
                color: borderColor,
              ),
            ));
          } else {
            children.add(pw.Positioned(
              left: e.fromMm * mmToPt,
              top: e.atMm * mmToPt - borderPt / 2,
              child: pw.Container(
                width: (e.toMm - e.fromMm) * mmToPt,
                height: borderPt,
                color: borderColor,
              ),
            ));
          }
        }
        return pw.Stack(children: children);
```
(Note: `PdfColor` comes from `package:pdf/pdf.dart`, already imported in this file as `pdf.dart`.)

- [ ] **Step 2: Run the PDF + integration tests + analyze**

Run: `cd grid_app && flutter test test/pdf/ test/integration/ && flutter analyze`
Expected: PASS (still a single-page `%PDF`; the value cells now render content-only with the layer's borders) and `No issues found!`.

- [ ] **Step 3: Run the FULL suite**

Run: `cd grid_app && flutter test`
Expected: ALL green.

- [ ] **Step 4: Commit**

```bash
cd /Users/xxf/Desktop/scss && git add -A && git commit -q -m "feat(pdf): cell border layer in the PDF renderer"
```

---

### Task 6: Manual simulator pass (controller, not a subagent)

**Files:** none

- [ ] **Step 1: Run on the emulator and verify the borders by observation**

```bash
flutter emulators --launch Medium_Phone_API_35
cd /Users/xxf/Desktop/scss/grid_app && flutter run -d emulator-5554
```
Verify and report what you see:
1. New template → in the builder, EVERY control (the title, each Label, each Text) has a solid outline showing exactly which cells it spans — including the title (which previously had no border). Unselected controls are outlined too.
2. A multi-cell control (e.g. a Text spanning cols 3–11) is ONE box — no faint grid lines run through it. Empty cells still show the faint placement grid.
3. A Label cell sitting next to a Text cell shares a single divider line between them (not a double-thick line).
4. Export PDF → the PDF shows the same single-width table borders (every control outlined, shared edges single, value cells bordered).
5. Place/drag/resize controls → the outlines and white fills track correctly; selecting a control still shows the blue highlight.

If anything misbehaves (double borders, faint lines through controls, title still borderless, PDF borders missing/misaligned), report DONE_WITH_CONCERNS with specifics.

---

## P2b — Definition of Done

- Controls render content-only; a shared border layer outlines every control's cells as lines centered on the grid boundaries, drawn identically on the builder canvas, the fill canvas, and the PDF.
- Adjacent controls' shared edges are single-width (collapse) — no double-thick borders.
- Builder issue 1: every control (incl. title, incl. unselected) shows a visible span outline.
- Builder issue 2: faint grid lines no longer show through controls (white fills); empty cells keep the placement grid.
- `flutter analyze` = 0; `flutter test` all green (golden regenerated); manual simulator pass confirms outlines, collapse, no-grid-through-controls, and PDF parity.
- No model/data/persistence/fill-logic changes — pure rendering.

## Self-Review (against spec §15)

**Coverage:**
- §15 "控件只画内容 + 边框层(以网格线为中心画线 → 相邻共享边单倍粗,canvas+PDF 共用)" → Tasks 1 (`controlOutlineEdges`) + 2 (content-only) + 3/4/5 (canvas/fill/PDF render the layer). ✓
- §15 builder issue ① "每个控件画实线轮廓框住占用范围(含 Title)" → Task 3 (border layer over all cells). ✓
- §15 builder issue ② "淡网格线只在空白格画" → Task 3 (white fills cover faint grid within controls; empty cells keep it). ✓
- "双倍边框消除" → centered-line collapse (Task 1 geometry + Tasks 3–5 rendering). ✓
- WYSIWYG (canvas == PDF) → one `controlOutlineEdges` geometry, three renderers. ✓

**Placeholder scan:** Complete code for the helper (Task 1), the widget renderer (Task 3), and the PDF edges (Task 5); precise remove-the-decoration edits for Task 2 (4 files); golden regeneration is an explicit command. No TBD/TODO.

**Type consistency:** `GridEdge{vertical,atMm,fromMm,toMm}`, `controlOutlineEdges(Template)→List<GridEdge>`, `borderLineWidgets(List<GridEdge>, double, {color, thickness})`, `kCellBorderColor`/`kCellBorderPx`, and the `mmToPt`/`PdfColor` PDF edge rendering are consistent across Tasks 1, 3, 4, 5 and the tests.
