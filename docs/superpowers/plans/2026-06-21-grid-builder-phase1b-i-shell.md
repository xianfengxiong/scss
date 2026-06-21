# Grid Template Builder — Phase 1B-i (Persistence + Read-only Builder Shell) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Phase 1A's pure core usable: persist templates (Drift/SQLite behind a `TemplateStore` abstraction), render a template on a scaled A4 canvas (`GridCanvas` using each control's `previewWidget`), browse/create/open/delete templates, and preview a template as a one-page PDF — all WITHOUT editing interactions (those are Phase 1B-ii).

**Architecture:** Screens depend on an abstract `TemplateStore` (in-memory impl for tests, Drift impl for production), so all UI is widget-testable without native SQLite. The on-screen `GridCanvas` reuses `cellRectMm` (the same geometry the PDF uses) and renders each cell via `ControlSpec.previewWidget`, mirroring `paintPdf` for WYSIWYG. PDF preview reuses Phase 1A's `renderTemplate` through the `printing` package.

**Tech Stack:** Flutter 3.27.2 / Dart 3.6.1; `drift` + `sqlite3_flutter_libs` + `path_provider` (persistence), `printing` (PDF preview), `build_runner` + `drift_dev` (codegen). Existing Phase 1A code in `grid_app/lib/{model,grid,controls,pdf,sample}`.

## Global Constraints

- Package name is `scss_grid`; project root `grid_app/` inside the git repo at `/Users/xxf/Desktop/scss` (branch work happens on a feature branch — see Task 0).
- A4 page = 210 × 297 mm. The on-screen canvas must preserve that aspect ratio and reuse `cellRectMm(grid, cell)` for cell placement (no parallel geometry).
- `previewWidget` must visually mirror the control's `paintPdf` (same label|value split, same text) so build view == PDF (WYSIWYG).
- Persistence is greenfield (no migration). Drift `schemaVersion = 1`. Templates are stored as `{id, name, json}` where `json = jsonEncode(template.toJson())`.
- Screens depend on the abstract `TemplateStore`, never directly on Drift — so widget tests use `InMemoryTemplateStore`.
- NO editing in this phase (no drag-to-place, no span/line drag, no prop editing). Builder screen is read-only + Save + Preview.
- Quality gate every task: `flutter analyze` = `No issues found!` and `flutter test` all green before commit.
- This phase's UI needs a manual simulator pass at the end (Task 9) — widget tests verify structure, not the `printing`/Drift-on-device path.

---

### Task 0: Start a feature branch

**Files:** none (git only)

- [ ] **Step 1: Branch from main**

```bash
cd /Users/xxf/Desktop/scss
git checkout main
git checkout -b feat/grid-builder-phase1b-i
git branch --show-current
```
Expected: `feat/grid-builder-phase1b-i`.

---

### Task 1: Add persistence + preview dependencies

**Files:**
- Modify: `grid_app/pubspec.yaml`

- [ ] **Step 1: Add the dependencies**

```bash
cd /Users/xxf/Desktop/scss/grid_app
flutter pub add drift sqlite3_flutter_libs path_provider printing
flutter pub add dev:drift_dev dev:build_runner
```
Expected: `drift`, `sqlite3_flutter_libs`, `path_provider`, `printing` under `dependencies`; `drift_dev`, `build_runner` under `dev_dependencies`.

- [ ] **Step 2: Verify the toolchain still builds**

```bash
cd /Users/xxf/Desktop/scss/grid_app && flutter analyze && flutter test
```
Expected: `No issues found!` and `All tests passed!` (the 28 existing tests).

- [ ] **Step 3: Commit**

```bash
cd /Users/xxf/Desktop/scss && git add -A && git commit -q -m "chore(deps): add drift, sqlite3_flutter_libs, path_provider, printing"
```

---

### Task 2: `TemplateStore` abstraction + `InMemoryTemplateStore`

**Files:**
- Create: `grid_app/lib/data/template_store.dart`
- Test: `grid_app/test/data/in_memory_store_test.dart`

**Interfaces:**
- Consumes: `Template` (`package:scss_grid/model/template.dart`)
- Produces: `abstract class TemplateStore { Future<void> upsert(Template t); Future<Template?> get(String id); Future<List<Template>> all(); Future<void> delete(String id); }` and `class InMemoryTemplateStore implements TemplateStore`

- [ ] **Step 1: Write the failing test**

Create `grid_app/test/data/in_memory_store_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/data/template_store.dart';
import 'package:scss_grid/sample/sample_template.dart';

void main() {
  test('in-memory store round-trips, lists, and deletes', () async {
    final store = InMemoryTemplateStore();
    expect(await store.all(), isEmpty);

    final t = sampleTemplate();
    await store.upsert(t);
    expect((await store.get(t.id))!.name, t.name);
    expect((await store.all()).length, 1);

    await store.upsert(t.copyWith(name: 'Renamed'));
    expect((await store.get(t.id))!.name, 'Renamed'); // upsert overwrites
    expect((await store.all()).length, 1);

    await store.delete(t.id);
    expect(await store.get(t.id), isNull);
    expect(await store.all(), isEmpty);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd grid_app && flutter test test/data/in_memory_store_test.dart`
Expected: FAIL (file not found).

- [ ] **Step 3: Write minimal implementation**

Create `grid_app/lib/data/template_store.dart`:
```dart
import '../model/template.dart';

/// Persistence boundary for templates. Screens depend on this, not on Drift,
/// so the UI is testable with [InMemoryTemplateStore].
abstract class TemplateStore {
  Future<void> upsert(Template t);
  Future<Template?> get(String id);
  Future<List<Template>> all();
  Future<void> delete(String id);
}

class InMemoryTemplateStore implements TemplateStore {
  final Map<String, Template> _byId = {};

  @override
  Future<void> upsert(Template t) async {
    _byId[t.id] = t;
  }

  @override
  Future<Template?> get(String id) async => _byId[id];

  @override
  Future<List<Template>> all() async => _byId.values.toList(growable: false);

  @override
  Future<void> delete(String id) async {
    _byId.remove(id);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd grid_app && flutter test test/data/in_memory_store_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/xxf/Desktop/scss && git add -A && git commit -q -m "feat(data): TemplateStore abstraction + InMemoryTemplateStore"
```

---

### Task 3: Drift database + `DriftTemplateStore`

**Files:**
- Create: `grid_app/lib/data/app_database.dart`
- Create: `grid_app/lib/data/connection.dart`
- Create (generated): `grid_app/lib/data/app_database.g.dart` (via build_runner)
- Test: `grid_app/test/data/drift_store_test.dart`

**Interfaces:**
- Consumes: `TemplateStore` (Task 2), `Template`
- Produces: `class AppDatabase extends _$AppDatabase`, `class DriftTemplateStore implements TemplateStore`, `LazyDatabase openConnection()`

- [ ] **Step 1: Write the failing test**

Create `grid_app/test/data/drift_store_test.dart`:
```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/data/app_database.dart';
import 'package:scss_grid/sample/sample_template.dart';

void main() {
  test('drift store round-trips a template through SQLite (in-memory)', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final store = DriftTemplateStore(db);

    final t = sampleTemplate();
    await store.upsert(t);

    final loaded = await store.get(t.id);
    expect(loaded, isNotNull);
    expect(loaded!.name, t.name);
    expect(loaded.cells.length, t.cells.length);
    expect(loaded.grid.cols, t.grid.cols);

    expect((await store.all()).length, 1);
    await store.delete(t.id);
    expect(await store.get(t.id), isNull);

    await db.close();
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd grid_app && flutter test test/data/drift_store_test.dart`
Expected: FAIL (`app_database.dart` not found / `AppDatabase` undefined).

- [ ] **Step 3: Write the database + store (pre-codegen)**

Create `grid_app/lib/data/app_database.dart`:
```dart
import 'dart:convert';

import 'package:drift/drift.dart';

import '../model/template.dart';
import 'connection.dart';
import 'template_store.dart';

part 'app_database.g.dart';

/// One row per saved template: the template serialized to JSON text.
class TemplateRows extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get json => text()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [TemplateRows])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// Production constructor: opens the on-device SQLite file.
  AppDatabase.open() : super(openConnection());

  @override
  int get schemaVersion => 1;
}

/// Drift-backed [TemplateStore]: (de)serializes [Template] to/from the `json`
/// column. The rest of the app never sees Drift types.
class DriftTemplateStore implements TemplateStore {
  final AppDatabase db;
  DriftTemplateStore(this.db);

  @override
  Future<void> upsert(Template t) =>
      db.into(db.templateRows).insertOnConflictUpdate(
            TemplateRowsCompanion.insert(
              id: t.id,
              name: t.name,
              json: jsonEncode(t.toJson()),
            ),
          );

  @override
  Future<Template?> get(String id) async {
    final row = await (db.select(db.templateRows)
          ..where((r) => r.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return null;
    return Template.fromJson(jsonDecode(row.json) as Map<String, dynamic>);
  }

  @override
  Future<List<Template>> all() async {
    final rows = await db.select(db.templateRows).get();
    return rows
        .map((r) => Template.fromJson(jsonDecode(r.json) as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> delete(String id) =>
      (db.delete(db.templateRows)..where((r) => r.id.equals(id))).go();
}
```

Create `grid_app/lib/data/connection.dart`:
```dart
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';

/// Opens the app's SQLite file lazily in the app documents directory.
LazyDatabase openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/scss_grid.sqlite');
    return NativeDatabase.createInBackground(file);
  });
}
```

- [ ] **Step 4: Run code generation**

```bash
cd /Users/xxf/Desktop/scss/grid_app && dart run build_runner build --delete-conflicting-outputs
```
Expected: generates `lib/data/app_database.g.dart`; build succeeds with "Succeeded after ...". If it reports analyzer errors in `app_database.dart`, fix them and re-run.

- [ ] **Step 5: Run test to verify it passes**

Run: `cd grid_app && flutter test test/data/drift_store_test.dart`
Expected: PASS.
> If this fails with a missing-sqlite3 native error (not a code error), report it as DONE_WITH_CONCERNS — `NativeDatabase.memory()` needs a loadable `sqlite3`; on macOS it normally resolves the system library. Do NOT skip the test silently.

- [ ] **Step 6: Run the full suite + analyze**

Run: `cd grid_app && flutter analyze && flutter test`
Expected: `No issues found!` and all green (generated `.g.dart` must be analysis-clean).

- [ ] **Step 7: Commit**

```bash
cd /Users/xxf/Desktop/scss && git add -A && git commit -q -m "feat(data): Drift AppDatabase + DriftTemplateStore (templates as json)"
```

---

### Task 4: Control `previewWidget` for Title and Field (WYSIWYG on canvas)

**Files:**
- Modify: `grid_app/lib/controls/field_control.dart`
- Modify: `grid_app/lib/controls/title_control.dart`
- Test: `grid_app/test/controls/preview_widget_test.dart`

**Interfaces:**
- Consumes: `Cell`, `ControlSpec.previewWidget` (default no-op from Phase 1A)
- Produces: overridden `Widget previewWidget(Cell cell)` on `TitleControl` and `FieldControl`; a private `(int labelCols, int valueCols) _labelValueSplit(Cell)` shared by `paintPdf` and `previewWidget` in `FieldControl`.

- [ ] **Step 1: Write the failing test**

Create `grid_app/test/controls/preview_widget_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/model/cell.dart';
import 'package:scss_grid/controls/title_control.dart';
import 'package:scss_grid/controls/field_control.dart';

Widget _host(Widget child) =>
    MaterialApp(home: Scaffold(body: SizedBox(width: 200, height: 40, child: child)));

void main() {
  testWidgets('TitleControl preview shows its text bold', (tester) async {
    await tester.pumpWidget(_host(TitleControl().previewWidget(
        const Cell(id: 't', col: 0, row: 0, type: 'title', props: {'text': 'My Title'}))));
    expect(find.text('My Title'), findsOneWidget);
  });

  testWidgets('FieldControl preview shows its label', (tester) async {
    await tester.pumpWidget(_host(FieldControl().previewWidget(
        const Cell(id: 'f', col: 0, row: 0, colSpan: 4, type: 'field',
            props: {'label': 'Site Name', 'key': 'site_name', 'labelCols': 1}))));
    expect(find.text('Site Name'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd grid_app && flutter test test/controls/preview_widget_test.dart`
Expected: FAIL — the default `previewWidget` returns `SizedBox.shrink()`, so `find.text` finds nothing.

- [ ] **Step 3: Implement `previewWidget` (and DRY the field split)**

In `grid_app/lib/controls/title_control.dart`, add inside `TitleControl` (keep `paintPdf` as-is):
```dart
  @override
  Widget previewWidget(Cell cell) => Center(
        child: Text(
          (cell.props['text'] as String?) ?? '',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      );
```

In `grid_app/lib/controls/field_control.dart`: (1) add a private split helper, (2) make `paintPdf` use it, (3) add `previewWidget`. Replace the body of `paintPdf` that computes `rawLabelCols`/`labelCols`/`valueCols` with a call to the helper, and add the new members:
```dart
  /// Label/value column split, clamped so both flex values are >= 1 even on bad
  /// data. Shared by paintPdf and previewWidget so the canvas matches the PDF.
  (int, int) _labelValueSplit(Cell cell) {
    final raw = (cell.props['labelCols'] as num?)?.toInt() ?? 1;
    final labelCols = raw.clamp(1, cell.colSpan > 1 ? cell.colSpan - 1 : 1);
    final valueCols = (cell.colSpan - labelCols).clamp(1, cell.colSpan);
    return (labelCols, valueCols);
  }

  @override
  Widget previewWidget(Cell cell) {
    final label = (cell.props['label'] as String?) ?? '';
    final valueType = (cell.props['valueType'] as String?) ?? 'text';
    final (labelCols, valueCols) = _labelValueSplit(cell);
    Widget box(String t, {bool grey = false}) => Container(
          padding: const EdgeInsets.all(2),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
              border: Border.all(width: 0.5, color: const Color(0xFFBDBDBD))),
          child: Text(t,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 9, color: grey ? const Color(0xFF9A9A9A) : Colors.black)),
        );
    return Row(children: [
      Expanded(flex: labelCols, child: box(label)),
      Expanded(flex: valueCols, child: box(valueType, grey: true)),
    ]);
  }
```
And update `paintPdf` so its existing local `rawLabelCols`/`labelCols`/`valueCols` lines become:
```dart
    final (labelCols, valueCols) = _labelValueSplit(cell);
```
(Delete the now-duplicated `rawLabelCols`/`labelCols`/`valueCols` lines in `paintPdf`; keep the rest of `paintPdf` unchanged.)

- [ ] **Step 4: Run test to verify it passes (+ existing field tests still pass)**

Run: `cd grid_app && flutter test test/controls/preview_widget_test.dart test/controls/default_controls_test.dart`
Expected: PASS for both files.

- [ ] **Step 5: Commit**

```bash
cd /Users/xxf/Desktop/scss && git add -A && git commit -q -m "feat(controls): previewWidget for Title/Field (DRY label split, WYSIWYG)"
```

---

### Task 5: `GridCanvas` — render a template on a scaled A4 box

**Files:**
- Create: `grid_app/lib/builder/grid_canvas.dart`
- Test: `grid_app/test/builder/grid_canvas_test.dart`

**Interfaces:**
- Consumes: `Template`, `cellRectMm` (`package:scss_grid/grid/geometry.dart`), `ControlRegistry`, `buildDefaultRegistry`
- Produces: `class GridCanvas extends StatelessWidget { final Template template; final ControlRegistry registry; const GridCanvas({required this.template, required this.registry}); }`

- [ ] **Step 1: Write the failing test**

Create `grid_app/test/builder/grid_canvas_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/builder/grid_canvas.dart';
import 'package:scss_grid/controls/default_controls.dart';
import 'package:scss_grid/sample/sample_template.dart';

void main() {
  testWidgets('GridCanvas renders title and field text from the template',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 300,
            child: GridCanvas(
                template: sampleTemplate(), registry: buildDefaultRegistry()),
          ),
        ),
      ),
    ));
    expect(find.text('Site Survey Form'), findsOneWidget);
    expect(find.text('Site Name'), findsOneWidget);
    expect(find.text('Site City'), findsOneWidget);
  });

  testWidgets('GridCanvas preserves A4 aspect ratio for its given width',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 210, // 1mm == 1px at this width → height should be ~297
            child: GridCanvas(
                template: sampleTemplate(), registry: buildDefaultRegistry()),
          ),
        ),
      ),
    ));
    final size = tester.getSize(find.byType(GridCanvas));
    expect(size.width, 210);
    expect(size.height, closeTo(297, 0.5));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd grid_app && flutter test test/builder/grid_canvas_test.dart`
Expected: FAIL (file not found).

- [ ] **Step 3: Write minimal implementation**

Create `grid_app/lib/builder/grid_canvas.dart`:
```dart
import 'package:flutter/material.dart';

import '../controls/registry.dart';
import '../grid/geometry.dart';
import '../model/cell.dart';
import '../model/template.dart';

/// Renders [template] as a white A4 page scaled to the available width.
/// Cells are positioned by [cellRectMm] (the same geometry the PDF uses) and
/// drawn via each control's `previewWidget`, so the canvas matches the PDF.
/// Read-only in Phase 1B-i (no editing).
class GridCanvas extends StatelessWidget {
  final Template template;
  final ControlRegistry registry;

  const GridCanvas({super.key, required this.template, required this.registry});

  @override
  Widget build(BuildContext context) {
    final page = template.page;
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = constraints.maxWidth / page.widthMm;
        final grid = template.grid;
        return Container(
          width: page.widthMm * scale,
          height: page.heightMm * scale,
          color: Colors.white,
          child: Stack(
            children: [
              // grid frame border (the PDF output region)
              Positioned(
                left: grid.xMm * scale,
                top: grid.yMm * scale,
                width: grid.frameWidthMm * scale,
                height: grid.frameHeightMm * scale,
                child: Container(
                  decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF607D8B))),
                ),
              ),
              for (final cell in template.cells) _cell(cell, scale),
            ],
          ),
        );
      },
    );
  }

  Widget _cell(Cell cell, double scale) {
    final r = cellRectMm(template.grid, cell);
    final spec = registry.specFor(cell.type);
    return Positioned(
      left: r.leftMm * scale,
      top: r.topMm * scale,
      width: r.widthMm * scale,
      height: r.heightMm * scale,
      child: Container(
        decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFBDBDBD), width: 0.5)),
        child: spec?.previewWidget(cell) ?? const SizedBox.shrink(),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd grid_app && flutter test test/builder/grid_canvas_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/xxf/Desktop/scss && git add -A && git commit -q -m "feat(builder): GridCanvas renders a template on a scaled A4 page"
```

---

### Task 6: PDF preview screen (reuses Phase 1A renderTemplate via `printing`)

**Files:**
- Create: `grid_app/lib/builder/pdf_preview_screen.dart`
- Test: `grid_app/test/builder/pdf_preview_screen_test.dart`

**Interfaces:**
- Consumes: `Template`, `ControlRegistry`, `renderTemplate` (`package:scss_grid/pdf/template_pdf.dart`)
- Produces: `class PdfPreviewScreen extends StatelessWidget { final Template template; final ControlRegistry registry; }`

- [ ] **Step 1: Write the failing test**

Create `grid_app/test/builder/pdf_preview_screen_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/builder/pdf_preview_screen.dart';
import 'package:scss_grid/controls/default_controls.dart';
import 'package:scss_grid/sample/sample_template.dart';

void main() {
  testWidgets('PdfPreviewScreen builds with an app bar titled Preview',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: PdfPreviewScreen(
          template: sampleTemplate(), registry: buildDefaultRegistry()),
    ));
    // Do not pumpAndSettle: PdfPreview renders the PDF asynchronously via the
    // platform and may never settle in the test harness. One frame is enough
    // to assert the screen scaffold built.
    expect(find.text('Preview'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd grid_app && flutter test test/builder/pdf_preview_screen_test.dart`
Expected: FAIL (file not found).

- [ ] **Step 3: Write minimal implementation**

Create `grid_app/lib/builder/pdf_preview_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../controls/registry.dart';
import '../model/template.dart';
import '../pdf/template_pdf.dart';

/// Shows the template rendered to a single-page A4 PDF using Phase 1A's
/// [renderTemplate]. Empty data (blank template preview).
class PdfPreviewScreen extends StatelessWidget {
  final Template template;
  final ControlRegistry registry;

  const PdfPreviewScreen(
      {super.key, required this.template, required this.registry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Preview')),
      body: PdfPreview(
        build: (format) =>
            renderTemplate(template, const {}, registry).save(),
        canChangePageFormat: false,
        canChangeOrientation: false,
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd grid_app && flutter test test/builder/pdf_preview_screen_test.dart`
Expected: PASS (the scaffold + app bar build on the first frame).

- [ ] **Step 5: Commit**

```bash
cd /Users/xxf/Desktop/scss && git add -A && git commit -q -m "feat(builder): PdfPreviewScreen via printing + renderTemplate"
```

---

### Task 7: `BuilderScreen` (read-only) — canvas + Save + Preview

**Files:**
- Create: `grid_app/lib/builder/builder_screen.dart`
- Test: `grid_app/test/builder/builder_screen_test.dart`

**Interfaces:**
- Consumes: `Template`, `ControlRegistry`, `TemplateStore`, `GridCanvas` (Task 5), `PdfPreviewScreen` (Task 6)
- Produces: `class BuilderScreen extends StatelessWidget { final Template template; final ControlRegistry registry; final TemplateStore store; }`

- [ ] **Step 1: Write the failing test**

Create `grid_app/test/builder/builder_screen_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/builder/builder_screen.dart';
import 'package:scss_grid/builder/grid_canvas.dart';
import 'package:scss_grid/controls/default_controls.dart';
import 'package:scss_grid/data/template_store.dart';
import 'package:scss_grid/sample/sample_template.dart';

void main() {
  testWidgets('BuilderScreen shows the template name and its canvas, and Save persists',
      (tester) async {
    final store = InMemoryTemplateStore();
    final t = sampleTemplate();
    await tester.pumpWidget(MaterialApp(
      home: BuilderScreen(
          template: t, registry: buildDefaultRegistry(), store: store),
    ));
    expect(find.text(t.name), findsOneWidget); // app bar title
    expect(find.byType(GridCanvas), findsOneWidget);

    await tester.tap(find.byTooltip('Save'));
    await tester.pump();
    expect((await store.get(t.id))!.id, t.id); // saved
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd grid_app && flutter test test/builder/builder_screen_test.dart`
Expected: FAIL (file not found).

- [ ] **Step 3: Write minimal implementation**

Create `grid_app/lib/builder/builder_screen.dart`:
```dart
import 'package:flutter/material.dart';

import '../controls/registry.dart';
import '../data/template_store.dart';
import '../model/template.dart';
import 'grid_canvas.dart';
import 'pdf_preview_screen.dart';

/// Read-only builder (Phase 1B-i): displays the template's A4 canvas with
/// Save and Preview actions. Editing interactions arrive in Phase 1B-ii.
class BuilderScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(template.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Preview',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) =>
                  PdfPreviewScreen(template: template, registry: registry),
            )),
          ),
          IconButton(
            icon: const Icon(Icons.save_outlined),
            tooltip: 'Save',
            onPressed: () async {
              await store.upsert(template);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Template saved.')));
              }
            },
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: GridCanvas(template: template, registry: registry),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd grid_app && flutter test test/builder/builder_screen_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/xxf/Desktop/scss && git add -A && git commit -q -m "feat(builder): read-only BuilderScreen (canvas + Save + Preview)"
```

---

### Task 8: `TemplateListScreen` — browse / new / open / delete

**Files:**
- Create: `grid_app/lib/builder/template_list_screen.dart`
- Test: `grid_app/test/builder/template_list_screen_test.dart`

**Interfaces:**
- Consumes: `TemplateStore`, `ControlRegistry`, `Template`, `sampleTemplate`, `BuilderScreen`
- Produces: `class TemplateListScreen extends StatefulWidget { final TemplateStore store; final ControlRegistry registry; }`

- [ ] **Step 1: Write the failing test**

Create `grid_app/test/builder/template_list_screen_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/builder/template_list_screen.dart';
import 'package:scss_grid/controls/default_controls.dart';
import 'package:scss_grid/data/template_store.dart';
import 'package:scss_grid/sample/sample_template.dart';

void main() {
  testWidgets('lists existing templates and creates a new one via the FAB',
      (tester) async {
    final store = InMemoryTemplateStore();
    await store.upsert(sampleTemplate().copyWith(id: 'a', name: 'Alpha'));

    await tester.pumpWidget(MaterialApp(
      home: TemplateListScreen(store: store, registry: buildDefaultRegistry()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Alpha'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    // Creating a template navigates into the builder; the new template is in the store.
    expect((await store.all()).length, 2);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd grid_app && flutter test test/builder/template_list_screen_test.dart`
Expected: FAIL (file not found).

- [ ] **Step 3: Write minimal implementation**

Create `grid_app/lib/builder/template_list_screen.dart`:
```dart
import 'package:flutter/material.dart';

import '../controls/registry.dart';
import '../data/template_store.dart';
import '../model/template.dart';
import '../sample/sample_template.dart';
import 'builder_screen.dart';

/// Home screen: lists saved templates; create a new one (seeded from the sample
/// layout), open one to view/preview, or delete one.
class TemplateListScreen extends StatefulWidget {
  final TemplateStore store;
  final ControlRegistry registry;

  const TemplateListScreen(
      {super.key, required this.store, required this.registry});

  @override
  State<TemplateListScreen> createState() => _TemplateListScreenState();
}

class _TemplateListScreenState extends State<TemplateListScreen> {
  List<Template> _templates = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final list = await widget.store.all();
    if (!mounted) return;
    setState(() {
      _templates = list;
      _loading = false;
    });
  }

  Future<void> _create() async {
    final t = sampleTemplate().copyWith(
      id: 'tpl_${DateTime.now().millisecondsSinceEpoch}',
      name: 'New Template',
    );
    await widget.store.upsert(t);
    await _open(t);
    await _reload();
  }

  Future<void> _open(Template t) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BuilderScreen(
          template: t, registry: widget.registry, store: widget.store),
    ));
    await _reload();
  }

  Future<void> _delete(Template t) async {
    await widget.store.delete(t.id);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SCSS Templates')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _templates.isEmpty
              ? const Center(child: Text('No templates yet. Tap + to create one.'))
              : ListView(
                  children: [
                    for (final t in _templates)
                      Dismissible(
                        key: ValueKey(t.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 16),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) => _delete(t),
                        child: ListTile(
                          title: Text(t.name),
                          subtitle: Text(
                              '${t.grid.cols}×${t.grid.rows} · ${t.cells.length} cells'),
                          onTap: () => _open(t),
                        ),
                      ),
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _create,
        tooltip: 'New template',
        child: const Icon(Icons.add),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd grid_app && flutter test test/builder/template_list_screen_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/xxf/Desktop/scss && git add -A && git commit -q -m "feat(builder): TemplateListScreen (browse/new/open/delete)"
```

---

### Task 9: Wire `main.dart` + manual simulator pass

**Files:**
- Modify: `grid_app/lib/main.dart`
- Test: `grid_app/test/app_boot_test.dart`

**Interfaces:**
- Consumes: `AppDatabase`, `DriftTemplateStore`, `InMemoryTemplateStore`, `buildDefaultRegistry`, `TemplateListScreen`
- Produces: `class ScssGridApp extends StatelessWidget { final TemplateStore store; final ControlRegistry registry; }` and a production `main()`.

- [ ] **Step 1: Write the failing test**

Create `grid_app/test/app_boot_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/main.dart';
import 'package:scss_grid/controls/default_controls.dart';
import 'package:scss_grid/data/template_store.dart';

void main() {
  testWidgets('app boots to the template list', (tester) async {
    await tester.pumpWidget(ScssGridApp(
        store: InMemoryTemplateStore(), registry: buildDefaultRegistry()));
    await tester.pumpAndSettle();
    expect(find.text('SCSS Templates'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd grid_app && flutter test test/app_boot_test.dart`
Expected: FAIL — `main.dart` currently exports the placeholder `ScssGridApp` with a different body (no `store`/`registry`).

- [ ] **Step 3: Replace `main.dart`**

Replace the entire contents of `grid_app/lib/main.dart`:
```dart
import 'package:flutter/material.dart';

import 'controls/default_controls.dart';
import 'controls/registry.dart';
import 'data/app_database.dart';
import 'data/template_store.dart';
import 'builder/template_list_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final store = DriftTemplateStore(AppDatabase.open());
  runApp(ScssGridApp(store: store, registry: buildDefaultRegistry()));
}

class ScssGridApp extends StatelessWidget {
  final TemplateStore store;
  final ControlRegistry registry;

  const ScssGridApp({super.key, required this.store, required this.registry});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'SCSS Grid Builder',
        theme: ThemeData(useMaterial3: true),
        home: TemplateListScreen(store: store, registry: registry),
      );
}
```

- [ ] **Step 4: Run test + full suite + analyze**

Run: `cd grid_app && flutter analyze && flutter test`
Expected: `No issues found!` and all tests green.

- [ ] **Step 5: Commit**

```bash
cd /Users/xxf/Desktop/scss && git add -A && git commit -q -m "feat(app): wire main.dart to TemplateList + Drift store"
```

- [ ] **Step 6: Manual simulator pass (widget tests can't cover printing/Drift-on-device)**

```bash
flutter emulators --launch Medium_Phone_API_35 2>/dev/null || true
cd /Users/xxf/Desktop/scss/grid_app && flutter run -d emulator-5554
```
Verify by hand, then report what you saw (don't just assert success):
1. App boots to "SCSS Templates" (empty list).
2. Tap **+** → opens the builder showing the A4 canvas with "Site Survey Form" + fields; the layout matches the grid.
3. Tap **Preview** → a one-page PDF renders showing the same layout.
4. Back out, tap **Save** on the builder → "Template saved." snackbar; the template appears in the list after returning.
5. Swipe a list row left → it deletes.

If any step misbehaves, report it as DONE_WITH_CONCERNS with the specifics (this step is verified by observation, not a passing test).

---

## Phase 1B-i — Definition of Done

- Templates persist via Drift (`DriftTemplateStore`), with the app logic tested against `InMemoryTemplateStore`.
- A saved template renders on a scaled A4 `GridCanvas` (reusing `cellRectMm`), matching the PDF (`previewWidget` mirrors `paintPdf`).
- The app browses/creates/opens/deletes templates and previews any template as a one-page PDF.
- `flutter analyze` = 0 issues; `flutter test` all green; manual simulator pass (Task 9 Step 6) confirms the on-device path.
- NO editing yet — that is Phase 1B-ii.

## Self-Review (against spec)

**Spec coverage (Phase 1B slice — persistence + builder display + preview):**
- §9 persistence (Drift/SQLite, templates as JSON, greenfield no migration) → Tasks 2–3. ✓
- §7 builder canvas = same grid rendered (WYSIWYG via shared `cellRectMm` + `previewWidget` mirroring `paintPdf`) → Tasks 4–5, 7. ✓
- §7 "一键 PDF 预览(渲染空模版)" → Task 6 + BuilderScreen Preview action. ✓
- §10 module boundaries (`data/`, `builder/`) and §10.1 (screens depend on registry/abstraction, not on control types) → Tasks 2, 5, 8. ✓
- Deferred to Phase 1B-ii (correctly out of this plan): palette drag-to-place, span-handle drag, grid-line drag (`resizeBoundary` UI), move/delete cell, prop editing (`propEditor`), inverse geometry (point→cell). Deferred to later phases: fill mode, device features, deviceChecklist/image/multiImage controls, NotoSansSC.

**Placeholder scan:** No TBD/TODO; every code step has complete code. The only non-test verification (Task 9 Step 6) is explicitly a manual observation step with concrete checks, not a hidden gap.

**Type consistency:** `TemplateStore` (`upsert`/`get`/`all`/`delete`), `InMemoryTemplateStore`, `AppDatabase`/`DriftTemplateStore`/`openConnection`, `GridCanvas({template, registry})`, `PdfPreviewScreen({template, registry})`, `BuilderScreen({template, registry, store})`, `TemplateListScreen({store, registry})`, `ScssGridApp({store, registry})`, and reused Phase 1A names (`cellRectMm`, `renderTemplate`, `buildDefaultRegistry`, `sampleTemplate`, `Template.copyWith`) are used identically across producing and consuming tasks.
