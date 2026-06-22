# Grid Template Builder — Phase 2 (Fill Loop) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the fill loop — fill a saved template (values only, structure frozen), persist the answers as a `Survey`, and export a WYSIWYG A4 PDF carrying those values, using the same grid model that drives the builder and the PDF.

**Architecture:** A `Survey` (templateId + a `key→value` data map) is the only new model concept; it is persisted by a `SurveyStore` (abstract + in-memory + a Drift `surveys` table), mirroring the existing `TemplateStore`. Controls gain real fill behavior: `ControlSpec.fillWidget` (default = read-only `previewWidget`, `FieldControl` overrides with a bound text input) plus `ControlSpec.dataKey` (where a control reads/writes its value). A new `FillCanvas` renders the *same* grid geometry (`cellRectMm` + `pageScale`) but draws each control's `fillWidget`; `FillScreen` owns the data map, Saves the survey, and Exports the PDF via the existing single-page renderer (which already takes a `data` map). A `SurveyListScreen` lists/resumes/deletes saved surveys; the template list gets a per-template "Fill" action.

**Tech Stack:** Flutter 3.27.2 / Dart 3.6.1. Reuses Phase 1A/1B: `cellRectMm` (`grid/geometry.dart`), `pageScale`/`kCanvasPad` (`builder/canvas_metrics.dart`), `renderTemplate` (`pdf/template_pdf.dart`), `ControlRegistry`/`ControlSpec`, `PdfPreviewScreen`, Drift `AppDatabase`. Persistence is Drift 2.28.2 + drift_dev 2.28.0 + build_runner 2.4.15 (all pinned for Dart 3.6.1; do NOT bump).

## Global Constraints

- **A4 single page, no pagination.** Fill mode renders the *same* grid as builder/PDF; it only changes values, never structure (spec §3, §7). No layout edits in fill mode.
- **One data map drives fill AND PDF.** Values live in `Map<String, dynamic>` keyed by each control's `dataKey` (for `field`, that is `cell.props['key']`). `renderTemplate(template, data, registry)` and `fillWidget` read the *same* keys, so what you fill is what the PDF prints (WYSIWYG).
- **Geometry is shared, never re-derived.** Fill canvas positions cells with `cellRectMm(grid, cell)` and scales with `pageScale(widthPx, page.widthMm)` — the exact functions the builder and PDF use.
- **Controls stay plugin-generic.** No `switch (cell.type)` in canvas/fill/list code; iterate the registry and call `ControlSpec` members. Adding a control later must not touch fill-mode plumbing (spec §10.1).
- **Drift versions are pinned** (drift 2.28.2 / drift_dev 2.28.0 / build_runner 2.4.15; Dart 3.6.1). Newer drift_dev needs Dart ≥ 3.10 — do not upgrade. After changing any `@DriftDatabase`/`Table`, regenerate with `dart run build_runner build --delete-conflicting-outputs` and commit the regenerated `app_database.g.dart`.
- **greenfield, but the dev simulator already holds a v1 DB.** Adding the `surveys` table bumps `schemaVersion` 1→2 with an `onUpgrade` that creates the new table, so an existing install keeps its saved templates.
- Quality gate every task: from `grid_app/`, `flutter analyze` = `No issues found!` and `flutter test` all green before commit.
- Manual simulator pass at the end (Task 9, controller) — fill + export needs a device check.

---

### Task 0: Start a feature branch

**Files:** none (git only)

- [ ] **Step 1**

```bash
cd /Users/xxf/Desktop/scss
git checkout main && git checkout -b feat/grid-builder-phase2-fill-loop
git branch --show-current
```
Expected: `feat/grid-builder-phase2-fill-loop`.

---

### Task 1: `Survey` model (+ JSON round-trip)

**Files:**
- Create: `grid_app/lib/model/survey.dart`
- Test: `grid_app/test/model/survey_test.dart`

**Interfaces:**
- Consumes: nothing (pure model).
- Produces:
  ```dart
  class Survey {
    final String id;
    final String templateId;
    final String name;
    final Map<String, dynamic> data; // control dataKey -> value
    const Survey({required String id, required String templateId,
        required String name, Map<String, dynamic> data = const {}});
    Survey copyWith({String? id, String? templateId, String? name, Map<String, dynamic>? data});
    Map<String, dynamic> toJson();
    factory Survey.fromJson(Map<String, dynamic> j);
  }
  ```

- [ ] **Step 1: Write the failing test**

Create `grid_app/test/model/survey_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/model/survey.dart';

void main() {
  test('defaults to an empty data map', () {
    const s = Survey(id: 's1', templateId: 't1', name: 'My Survey');
    expect(s.data, isEmpty);
  });

  test('JSON round-trips id, templateId, name, and data', () {
    const s = Survey(
      id: 's1',
      templateId: 't1',
      name: 'My Survey',
      data: {'site_name': 'Gjirokaster', 'count': 3},
    );
    final back = Survey.fromJson(s.toJson());
    expect(back.id, 's1');
    expect(back.templateId, 't1');
    expect(back.name, 'My Survey');
    expect(back.data, {'site_name': 'Gjirokaster', 'count': 3});
  });

  test('copyWith replaces only the given fields', () {
    const s = Survey(id: 's1', templateId: 't1', name: 'A', data: {'k': 1});
    final r = s.copyWith(name: 'B', data: {'k': 2});
    expect([r.id, r.templateId, r.name], ['s1', 't1', 'B']);
    expect(r.data, {'k': 2});
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd grid_app && flutter test test/model/survey_test.dart`
Expected: FAIL (`survey.dart` not found).

- [ ] **Step 3: Write minimal implementation**

Create `grid_app/lib/model/survey.dart`:
```dart
/// One filled-in instance of a template: answers keyed by each control's
/// `dataKey`. Structure lives in the template; a survey only holds values.
class Survey {
  final String id;
  final String templateId;
  final String name;

  /// Answers, keyed by control dataKey (e.g. a field's `props['key']`).
  /// The same map is handed to `renderTemplate` so the PDF prints what was
  /// filled (WYSIWYG).
  final Map<String, dynamic> data;

  const Survey({
    required this.id,
    required this.templateId,
    required this.name,
    this.data = const {},
  });

  Survey copyWith({
    String? id,
    String? templateId,
    String? name,
    Map<String, dynamic>? data,
  }) =>
      Survey(
        id: id ?? this.id,
        templateId: templateId ?? this.templateId,
        name: name ?? this.name,
        data: data ?? this.data,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'templateId': templateId,
        'name': name,
        'data': data,
      };

  factory Survey.fromJson(Map<String, dynamic> j) => Survey(
        id: j['id'] as String,
        templateId: j['templateId'] as String,
        name: j['name'] as String,
        data: Map<String, dynamic>.from(j['data'] as Map? ?? const {}),
      );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd grid_app && flutter test test/model/survey_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
cd /Users/xxf/Desktop/scss && git add -A && git commit -q -m "feat(model): Survey (templateId + key->value data, JSON round-trip)"
```

---

### Task 2: `SurveyStore` abstract boundary + `InMemorySurveyStore`

**Files:**
- Create: `grid_app/lib/data/survey_store.dart`
- Test: `grid_app/test/data/in_memory_survey_store_test.dart`

**Interfaces:**
- Consumes: `Survey` (`model/survey.dart`).
- Produces:
  ```dart
  abstract class SurveyStore {
    Future<void> upsert(Survey s);
    Future<Survey?> get(String id);
    Future<List<Survey>> all();
    Future<void> delete(String id);
  }
  class InMemorySurveyStore implements SurveyStore { ... }
  ```

- [ ] **Step 1: Write the failing test**

Create `grid_app/test/data/in_memory_survey_store_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/data/survey_store.dart';
import 'package:scss_grid/model/survey.dart';

void main() {
  test('in-memory survey store round-trips, lists, upserts, and deletes',
      () async {
    final store = InMemorySurveyStore();
    expect(await store.all(), isEmpty);

    const s = Survey(id: 's1', templateId: 't1', name: 'A', data: {'k': 1});
    await store.upsert(s);
    expect((await store.get('s1'))!.name, 'A');
    expect((await store.all()).length, 1);

    await store.upsert(s.copyWith(name: 'B'));
    expect((await store.get('s1'))!.name, 'B'); // upsert overwrites
    expect((await store.all()).length, 1);

    await store.delete('s1');
    expect(await store.get('s1'), isNull);
    expect(await store.all(), isEmpty);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd grid_app && flutter test test/data/in_memory_survey_store_test.dart`
Expected: FAIL (`survey_store.dart` not found).

- [ ] **Step 3: Write minimal implementation**

Create `grid_app/lib/data/survey_store.dart`:
```dart
import '../model/survey.dart';

/// Persistence boundary for surveys. Screens depend on this, not on Drift,
/// so the UI is testable with [InMemorySurveyStore]. Mirrors TemplateStore.
abstract class SurveyStore {
  Future<void> upsert(Survey s);
  Future<Survey?> get(String id);
  Future<List<Survey>> all();
  Future<void> delete(String id);
}

class InMemorySurveyStore implements SurveyStore {
  final Map<String, Survey> _byId = {};

  @override
  Future<void> upsert(Survey s) async {
    _byId[s.id] = s;
  }

  @override
  Future<Survey?> get(String id) async => _byId[id];

  @override
  Future<List<Survey>> all() async => _byId.values.toList(growable: false);

  @override
  Future<void> delete(String id) async {
    _byId.remove(id);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd grid_app && flutter test test/data/in_memory_survey_store_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/xxf/Desktop/scss && git add -A && git commit -q -m "feat(data): SurveyStore boundary + InMemorySurveyStore"
```

---

### Task 3: `surveys` Drift table + `DriftSurveyStore` + migration (codegen)

**Files:**
- Modify: `grid_app/lib/data/app_database.dart`
- Regenerate: `grid_app/lib/data/app_database.g.dart` (via build_runner; commit it)
- Test: `grid_app/test/data/drift_survey_store_test.dart`

**Interfaces:**
- Consumes: `Survey`, `SurveyStore` (Task 1, 2), Drift `AppDatabase`.
- Produces: `class SurveyRows extends Table {...}`, `class DriftSurveyStore implements SurveyStore {...}`, `AppDatabase.schemaVersion == 2` with an `onUpgrade` that creates `surveyRows`.

- [ ] **Step 1: Write the failing test**

Create `grid_app/test/data/drift_survey_store_test.dart`:
```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/data/app_database.dart';
import 'package:scss_grid/model/survey.dart';

void main() {
  test('drift survey store round-trips a survey through SQLite (in-memory)',
      () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final store = DriftSurveyStore(db);

    const s = Survey(
      id: 's1',
      templateId: 't1',
      name: 'Castle survey',
      data: {'site_name': 'Gjirokaster', 'count': 3},
    );
    await store.upsert(s);

    final loaded = await store.get('s1');
    expect(loaded, isNotNull);
    expect(loaded!.name, 'Castle survey');
    expect(loaded.templateId, 't1');
    expect(loaded.data, {'site_name': 'Gjirokaster', 'count': 3});

    expect((await store.all()).length, 1);
    await store.delete('s1');
    expect(await store.get('s1'), isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd grid_app && flutter test test/data/drift_survey_store_test.dart`
Expected: FAIL (`DriftSurveyStore`/`SurveyRows` not defined).

- [ ] **Step 3: Add the table, store, and migration in `app_database.dart`**

In `grid_app/lib/data/app_database.dart`:

1. Add the survey import near the top (with the other imports):
```dart
import '../model/survey.dart';
import 'survey_store.dart';
```

2. Add a new table class right after the `TemplateRows` class:
```dart
/// One row per saved survey: the survey serialized to JSON text. `templateId`
/// and `name` are kept as columns for listing/ordering without parsing JSON.
class SurveyRows extends Table {
  TextColumn get id => text()();
  TextColumn get templateId => text()();
  TextColumn get name => text()();
  TextColumn get json => text()();

  @override
  Set<Column> get primaryKey => {id};
}
```

3. Register the table and bump the schema + add the migration. Replace:
```dart
@DriftDatabase(tables: [TemplateRows])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// Production constructor: opens the on-device SQLite file.
  AppDatabase.open() : super(openConnection());

  @override
  int get schemaVersion => 1;
}
```
with:
```dart
@DriftDatabase(tables: [TemplateRows, SurveyRows])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// Production constructor: opens the on-device SQLite file.
  AppDatabase.open() : super(openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        // v1 installs (Phase 1B dev DBs) only had `template_rows`; v2 adds
        // `survey_rows`. greenfield = no data backfill, just create the table.
        onUpgrade: (m, from, to) async {
          if (from < 2) await m.createTable(surveyRows);
        },
      );
}
```

4. Add the `DriftSurveyStore` at the end of the file (after `DriftTemplateStore`):
```dart
/// Drift-backed [SurveyStore]: (de)serializes [Survey] to/from the `json`
/// column. The rest of the app never sees Drift types.
class DriftSurveyStore implements SurveyStore {
  final AppDatabase _db;
  DriftSurveyStore(this._db);

  @override
  Future<void> upsert(Survey s) =>
      _db.into(_db.surveyRows).insertOnConflictUpdate(
            SurveyRowsCompanion.insert(
              id: s.id,
              templateId: s.templateId,
              name: s.name,
              json: jsonEncode(s.toJson()),
            ),
          );

  @override
  Future<Survey?> get(String id) async {
    final row = await (_db.select(_db.surveyRows)
          ..where((r) => r.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return null;
    return Survey.fromJson(jsonDecode(row.json) as Map<String, dynamic>);
  }

  @override
  Future<List<Survey>> all() async {
    final query = _db.select(_db.surveyRows)
      ..orderBy([(r) => OrderingTerm(expression: r.name)]);
    final rows = await query.get();
    return rows
        .map((r) => Survey.fromJson(jsonDecode(r.json) as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> delete(String id) =>
      (_db.delete(_db.surveyRows)..where((r) => r.id.equals(id))).go();
}
```

- [ ] **Step 4: Regenerate the Drift code**

Run: `cd grid_app && dart run build_runner build --delete-conflicting-outputs`
Expected: `Succeeded` — `lib/data/app_database.g.dart` now contains `SurveyRows`/`SurveyRowsCompanion`/`$SurveyRowsTable`.

- [ ] **Step 5: Run test + full data suite to verify it passes**

Run: `cd grid_app && flutter test test/data/`
Expected: PASS (new survey store test + existing template store tests, including the in-memory ones).

- [ ] **Step 6: Analyze + commit (include the generated file)**

```bash
cd /Users/xxf/Desktop/scss/grid_app && flutter analyze
cd /Users/xxf/Desktop/scss && git add -A && git commit -q -m "feat(data): surveys table + DriftSurveyStore + v2 migration"
```
Expected: `No issues found!`, then commit includes `app_database.dart` AND the regenerated `app_database.g.dart`.

---

### Task 4: Control fill behavior — `dataKey`, `fillWidget` default, `FieldControl` input

**Files:**
- Modify: `grid_app/lib/controls/control_spec.dart`
- Modify: `grid_app/lib/controls/field_control.dart`
- Test: `grid_app/test/controls/fill_widget_test.dart`

**Interfaces:**
- Consumes: `Cell`, `ControlSpec.previewWidget` (existing).
- Produces:
  - `String? ControlSpec.dataKey(Cell cell)` — default `cell.props['key'] as String?` (null = control holds no value, e.g. `title`).
  - `ControlSpec.fillWidget` default changes from `SizedBox.shrink()` to `previewWidget(cell)` (read-only controls show their preview in fill mode).
  - `FieldControl.fillWidget` — `label | TextFormField` bound to `value`, reporting edits via `onChanged`.

- [ ] **Step 1: Write the failing test**

Create `grid_app/test/controls/fill_widget_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/controls/field_control.dart';
import 'package:scss_grid/controls/title_control.dart';
import 'package:scss_grid/model/cell.dart';

Widget _host(Widget child) =>
    MaterialApp(home: Scaffold(body: SizedBox(width: 300, height: 60, child: child)));

void main() {
  test('dataKey returns the field key, null for a title', () {
    const field = Cell(id: 'f', col: 0, row: 0, colSpan: 4, type: 'field',
        props: {'label': 'L', 'key': 'site_name'});
    const title = Cell(id: 't', col: 0, row: 0, colSpan: 4, type: 'title',
        props: {'text': 'Hi'});
    expect(FieldControl().dataKey(field), 'site_name');
    expect(TitleControl().dataKey(title), isNull);
  });

  testWidgets('field fillWidget shows the current value and reports edits',
      (tester) async {
    Object? captured;
    const cell = Cell(id: 'f', col: 0, row: 0, colSpan: 4, type: 'field',
        props: {'label': 'Site', 'key': 'site_name', 'labelCols': 1});
    await tester.pumpWidget(_host(
      FieldControl().fillWidget(cell, 'Old', (v) => captured = v),
    ));
    expect(find.text('Site'), findsOneWidget); // label rendered
    expect(find.text('Old'), findsOneWidget); // current value prefilled

    await tester.enterText(find.byType(TextFormField), 'New');
    expect(captured, 'New');
  });

  testWidgets('title fillWidget is read-only (its preview text, no input)',
      (tester) async {
    const cell = Cell(id: 't', col: 0, row: 0, colSpan: 4, type: 'title',
        props: {'text': 'Form Title'});
    await tester.pumpWidget(_host(
      TitleControl().fillWidget(cell, null, (_) {}),
    ));
    expect(find.text('Form Title'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd grid_app && flutter test test/controls/fill_widget_test.dart`
Expected: FAIL (`dataKey` undefined; field `fillWidget` still returns `SizedBox.shrink`).

- [ ] **Step 3: Update `ControlSpec` defaults**

In `grid_app/lib/controls/control_spec.dart`, replace the `fillWidget` default and add `dataKey`. Change:
```dart
  /// Real input shown in fill mode.
  Widget fillWidget(
          Cell cell, Object? value, void Function(Object? value) onChanged) =>
      const SizedBox.shrink();
```
to:
```dart
  /// The data-map key this control reads/writes in fill mode, or null if it
  /// holds no value (e.g. a title). Default: the control's `props['key']`.
  String? dataKey(Cell cell) => cell.props['key'] as String?;

  /// Real input shown in fill mode. Default: the read-only `previewWidget`, so
  /// value-less controls (title/section/staticText) just show themselves.
  /// Input controls override this.
  Widget fillWidget(
          Cell cell, Object? value, void Function(Object? value) onChanged) =>
      previewWidget(cell);
```

- [ ] **Step 4: Implement `FieldControl.fillWidget`**

In `grid_app/lib/controls/field_control.dart`, add this method to the `FieldControl` class (e.g. after `previewWidget`):
```dart
  @override
  Widget fillWidget(
      Cell cell, Object? value, void Function(Object? value) onChanged) {
    final label = (cell.props['label'] as String?) ?? '';
    final valueType = (cell.props['valueType'] as String?) ?? 'text';
    final (labelCols, valueCols) = _labelValueSplit(cell);

    final labelBox = Container(
      padding: const EdgeInsets.all(2),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
          border: Border.all(width: 0.5, color: const Color(0xFFBDBDBD))),
      child: Text(label,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 9)),
    );

    final inputBox = Container(
      decoration: BoxDecoration(
          border: Border.all(width: 0.5, color: const Color(0xFFBDBDBD))),
      child: TextFormField(
        initialValue: value?.toString() ?? '',
        keyboardType:
            valueType == 'number' ? TextInputType.number : TextInputType.text,
        // Fill the cell's height so the input matches the WYSIWYG row.
        expands: true,
        maxLines: null,
        textAlignVertical: TextAlignVertical.center,
        style: const TextStyle(fontSize: 9),
        decoration: const InputDecoration(
          isDense: true,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        ),
        onChanged: (v) => onChanged(v),
      ),
    );

    return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(flex: labelCols, child: labelBox),
      Expanded(flex: valueCols, child: inputBox),
    ]);
  }
```

- [ ] **Step 5: Run test + existing control tests + analyze**

Run: `cd grid_app && flutter test test/controls/ && flutter analyze`
Expected: PASS (new fill tests + existing preview/propEditor/registry tests) and `No issues found!`.

- [ ] **Step 6: Commit**

```bash
cd /Users/xxf/Desktop/scss && git add -A && git commit -q -m "feat(controls): fill behavior (dataKey, fillWidget default, FieldControl input)"
```

---

### Task 5: `FillCanvas` — same grid, drawn with `fillWidget`

**Files:**
- Create: `grid_app/lib/fill/fill_canvas.dart`
- Test: `grid_app/test/fill/fill_canvas_test.dart`

**Interfaces:**
- Consumes: `cellRectMm` (`grid/geometry.dart`), `pageScale` (`builder/canvas_metrics.dart`), `ControlRegistry`, `Template`, `Cell`, `ControlSpec.fillWidget`/`dataKey`.
- Produces:
  ```dart
  class FillCanvas extends StatelessWidget {
    final Template template;
    final ControlRegistry registry;
    final Map<String, dynamic> data;                       // current answers
    final void Function(String key, Object? value) onChanged;
  }
  ```
  Renders a white A4 page scaled to width: the grid-frame border plus each cell positioned by `cellRectMm` and drawn by its control's `fillWidget(cell, data[dataKey], cb)`. Unregistered types get a red placeholder (same convention as `GridCanvas`).

- [ ] **Step 1: Write the failing test**

Create `grid_app/test/fill/fill_canvas_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/controls/default_controls.dart';
import 'package:scss_grid/fill/fill_canvas.dart';
import 'package:scss_grid/model/cell.dart';
import 'package:scss_grid/model/grid_frame.dart';
import 'package:scss_grid/model/template.dart';

Template _tpl() => Template(
      id: 't',
      name: 'n',
      page: const PageSize.a4(),
      grid: GridFrame.uniform(
          xMm: 0, yMm: 0, cols: 12, rows: 4, colWidthMm: 15, rowHeightMm: 20),
      cells: const [
        Cell(id: 'title', col: 0, row: 0, colSpan: 12, type: 'title',
            props: {'text': 'Form'}),
        Cell(id: 'name', col: 0, row: 1, colSpan: 12, type: 'field',
            props: {'label': 'Site', 'key': 'site_name', 'labelCols': 3}),
      ],
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
  testWidgets('renders title text and a field input with its current value',
      (tester) async {
    await tester.pumpWidget(_host(FillCanvas(
      template: _tpl(),
      registry: buildDefaultRegistry(),
      data: const {'site_name': 'Gjirokaster'},
      onChanged: (_, __) {},
    )));
    expect(find.text('Form'), findsOneWidget); // read-only title
    expect(find.text('Site'), findsOneWidget); // field label
    expect(find.text('Gjirokaster'), findsOneWidget); // prefilled value
  });

  testWidgets('editing a field reports (key, value) via onChanged',
      (tester) async {
    String? gotKey;
    Object? gotVal;
    await tester.pumpWidget(_host(FillCanvas(
      template: _tpl(),
      registry: buildDefaultRegistry(),
      data: const {},
      onChanged: (k, v) {
        gotKey = k;
        gotVal = v;
      },
    )));
    await tester.enterText(find.byType(TextFormField), 'Berat');
    expect(gotKey, 'site_name');
    expect(gotVal, 'Berat');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd grid_app && flutter test test/fill/fill_canvas_test.dart`
Expected: FAIL (`fill_canvas.dart` not found).

- [ ] **Step 3: Write `FillCanvas`**

Create `grid_app/lib/fill/fill_canvas.dart`:
```dart
import 'package:flutter/material.dart';

import '../builder/canvas_metrics.dart';
import '../controls/registry.dart';
import '../grid/geometry.dart';
import '../model/cell.dart';
import '../model/template.dart';

/// Renders [template] as a white A4 page scaled to width — the SAME geometry the
/// builder and PDF use (`cellRectMm` + `pageScale`) — but draws each cell with
/// its control's `fillWidget`, so the user fills values in place (WYSIWYG).
/// Structure is fixed; only values change.
class FillCanvas extends StatelessWidget {
  final Template template;
  final ControlRegistry registry;

  /// Current answers, keyed by each control's `dataKey`.
  final Map<String, dynamic> data;

  /// Called when a control edits its value: (control dataKey, new value).
  final void Function(String key, Object? value) onChanged;

  const FillCanvas({
    super.key,
    required this.template,
    required this.registry,
    required this.data,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final page = template.page;
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = pageScale(constraints.maxWidth, page.widthMm);
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
    final Widget content;
    if (spec == null) {
      content = Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
            border: Border.all(color: Colors.red),
            color: const Color(0x11FF0000)),
        child: Text('?${cell.type}',
            style: const TextStyle(fontSize: 9, color: Colors.red)),
      );
    } else {
      final key = spec.dataKey(cell);
      final value = key == null ? null : data[key];
      content = spec.fillWidget(cell, value, (v) {
        if (key != null) onChanged(key, v);
      });
    }
    return Positioned(
      left: r.leftMm * scale,
      top: r.topMm * scale,
      width: r.widthMm * scale,
      height: r.heightMm * scale,
      child: content,
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd grid_app && flutter test test/fill/fill_canvas_test.dart`
Expected: PASS (both tests).

- [ ] **Step 5: Analyze + commit**

```bash
cd /Users/xxf/Desktop/scss/grid_app && flutter analyze
cd /Users/xxf/Desktop/scss && git add -A && git commit -q -m "feat(fill): FillCanvas (same grid, drawn with fillWidget)"
```
Expected: `No issues found!`, then commit.

---

### Task 6: `FillScreen` — fill, save, export

**Files:**
- Modify: `grid_app/lib/builder/pdf_preview_screen.dart` (add optional `data`)
- Create: `grid_app/lib/fill/fill_screen.dart`
- Test: `grid_app/test/fill/fill_screen_test.dart`
- Test: `grid_app/test/integration/fill_to_pdf_test.dart`

**Interfaces:**
- Consumes: `FillCanvas`, `Survey`, `SurveyStore`, `Template`, `ControlRegistry`, `PdfPreviewScreen`, `renderTemplate`, `kCanvasPad`.
- Produces:
  - `PdfPreviewScreen` gains `final Map<String, dynamic> data;` (default `const {}`), passed into `renderTemplate`.
  - ```dart
    class FillScreen extends StatefulWidget {
      final Template template;
      final Survey survey;
      final SurveyStore store;
      final ControlRegistry registry;
    }
    ```
    Hosts `FillCanvas` over a working copy of `survey.data`; AppBar has Export (→ `PdfPreviewScreen` with the data) and Save (→ `store.upsert(survey.copyWith(data: ...))` + snackbar).

- [ ] **Step 1: Write the failing tests**

Create `grid_app/test/fill/fill_screen_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/controls/default_controls.dart';
import 'package:scss_grid/data/survey_store.dart';
import 'package:scss_grid/fill/fill_canvas.dart';
import 'package:scss_grid/fill/fill_screen.dart';
import 'package:scss_grid/model/cell.dart';
import 'package:scss_grid/model/grid_frame.dart';
import 'package:scss_grid/model/survey.dart';
import 'package:scss_grid/model/template.dart';

Template _tpl() => Template(
      id: 't1',
      name: 'Site Survey',
      page: const PageSize.a4(),
      grid: GridFrame.uniform(
          xMm: 0, yMm: 0, cols: 12, rows: 4, colWidthMm: 15, rowHeightMm: 20),
      cells: const [
        Cell(id: 'name', col: 0, row: 0, colSpan: 12, type: 'field',
            props: {'label': 'Site', 'key': 'site_name', 'labelCols': 3}),
      ],
    );

void main() {
  testWidgets('renders the fill canvas and Save persists entered values',
      (tester) async {
    final store = InMemorySurveyStore();
    const survey = Survey(id: 's1', templateId: 't1', name: 'Site Survey');
    await tester.pumpWidget(MaterialApp(
      home: FillScreen(
        template: _tpl(),
        survey: survey,
        store: store,
        registry: buildDefaultRegistry(),
      ),
    ));
    expect(find.byType(FillCanvas), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'Gjirokaster');
    await tester.tap(find.byTooltip('Save'));
    await tester.pump();

    final saved = await store.get('s1');
    expect(saved!.data['site_name'], 'Gjirokaster');
  });
}
```

Create `grid_app/test/integration/fill_to_pdf_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/controls/default_controls.dart';
import 'package:scss_grid/model/survey.dart';
import 'package:scss_grid/pdf/template_pdf.dart';
import 'package:scss_grid/sample/sample_template.dart';

void main() {
  test('a filled survey renders its values into a single-page PDF', () async {
    final t = sampleTemplate();
    const survey = Survey(
      id: 's1',
      templateId: 'sample',
      name: 'Filled',
      data: {'site_name': 'Gjirokaster', 'site_city': 'Gjirokaster'},
    );

    final doc = renderTemplate(t, survey.data, buildDefaultRegistry());
    final bytes = await doc.save();
    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd grid_app && flutter test test/fill/fill_screen_test.dart test/integration/fill_to_pdf_test.dart`
Expected: FAIL (`fill_screen.dart` not found; the integration test fails only if imports are unresolved — it compiles once `survey.dart` exists, so it may already PASS, which is fine).

- [ ] **Step 3: Add optional `data` to `PdfPreviewScreen`**

In `grid_app/lib/builder/pdf_preview_screen.dart`:
1. Add the field and constructor parameter. Change:
```dart
  final Template template;
  final ControlRegistry registry;

  const PdfPreviewScreen(
      {super.key, required this.template, required this.registry});
```
to:
```dart
  final Template template;
  final ControlRegistry registry;

  /// Answers to render into the PDF. Empty = blank-template preview (builder).
  final Map<String, dynamic> data;

  const PdfPreviewScreen(
      {super.key,
      required this.template,
      required this.registry,
      this.data = const {}});
```
2. Pass it to the renderer. Change:
```dart
        build: (format) =>
            renderTemplate(template, const {}, registry).save(),
```
to:
```dart
        build: (format) => renderTemplate(template, data, registry).save(),
```

- [ ] **Step 4: Write `FillScreen`**

Create `grid_app/lib/fill/fill_screen.dart`:
```dart
import 'package:flutter/material.dart';

import '../builder/canvas_metrics.dart';
import '../builder/pdf_preview_screen.dart';
import '../controls/registry.dart';
import '../data/survey_store.dart';
import '../model/survey.dart';
import '../model/template.dart';
import 'fill_canvas.dart';

/// Fill mode: render [template]'s grid with real inputs, edit values, save the
/// [Survey], and export the filled A4 PDF. Structure is fixed — values only.
class FillScreen extends StatefulWidget {
  final Template template;
  final Survey survey;
  final SurveyStore store;
  final ControlRegistry registry;

  const FillScreen({
    super.key,
    required this.template,
    required this.survey,
    required this.store,
    required this.registry,
  });

  @override
  State<FillScreen> createState() => _FillScreenState();
}

class _FillScreenState extends State<FillScreen> {
  // Working copy of the answers; committed to the store on Save.
  late final Map<String, dynamic> _data = {...widget.survey.data};

  Survey get _current => widget.survey.copyWith(data: _data);

  Future<void> _save() async {
    await widget.store.upsert(_current);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Survey saved.')));
    }
  }

  void _export() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PdfPreviewScreen(
        template: widget.template,
        registry: widget.registry,
        data: _data,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.survey.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Export',
            onPressed: _export,
          ),
          IconButton(
            icon: const Icon(Icons.save_outlined),
            tooltip: 'Save',
            onPressed: _save,
          ),
        ],
      ),
      // No scroll view: the canvas fits the available box (FillCanvas scales to
      // width); a vertical scroll could steal taps. Matches BuilderScreen.
      body: Padding(
        padding: const EdgeInsets.all(kCanvasPad),
        child: Center(
          child: FillCanvas(
            template: widget.template,
            registry: widget.registry,
            data: _data,
            onChanged: (key, value) => setState(() => _data[key] = value),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `cd grid_app && flutter test test/fill/ test/integration/fill_to_pdf_test.dart`
Expected: PASS (fill canvas, fill screen, fill→pdf).

- [ ] **Step 6: Analyze + commit**

```bash
cd /Users/xxf/Desktop/scss/grid_app && flutter analyze
cd /Users/xxf/Desktop/scss && git add -A && git commit -q -m "feat(fill): FillScreen (fill/save/export) + PdfPreviewScreen data param"
```
Expected: `No issues found!`, then commit.

---

### Task 7: `SurveyListScreen` — list, resume, delete

**Files:**
- Create: `grid_app/lib/fill/survey_list_screen.dart`
- Test: `grid_app/test/fill/survey_list_screen_test.dart`

**Interfaces:**
- Consumes: `SurveyStore`, `TemplateStore`, `ControlRegistry`, `FillScreen`, `Survey`, `Template`.
- Produces:
  ```dart
  class SurveyListScreen extends StatefulWidget {
    final SurveyStore surveyStore;
    final TemplateStore templateStore;
    final ControlRegistry registry;
  }
  ```
  Lists saved surveys (title = name, subtitle = `${data.length} fields filled`). Tap → load the survey's template via `templateStore.get(survey.templateId)` and push `FillScreen` (snackbar if the template is missing). Swipe end-to-start → delete (mirrors `TemplateListScreen`).

- [ ] **Step 1: Write the failing test**

Create `grid_app/test/fill/survey_list_screen_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/controls/default_controls.dart';
import 'package:scss_grid/data/survey_store.dart';
import 'package:scss_grid/data/template_store.dart';
import 'package:scss_grid/fill/fill_screen.dart';
import 'package:scss_grid/fill/survey_list_screen.dart';
import 'package:scss_grid/model/survey.dart';
import 'package:scss_grid/sample/sample_template.dart';

void main() {
  testWidgets('lists surveys; tapping one resumes it in FillScreen',
      (tester) async {
    final templateStore = InMemoryTemplateStore();
    await templateStore.upsert(sampleTemplate()); // id 'sample'
    final surveyStore = InMemorySurveyStore();
    await surveyStore.upsert(const Survey(
        id: 's1', templateId: 'sample', name: 'Castle survey',
        data: {'site_name': 'Gjirokaster'}));

    await tester.pumpWidget(MaterialApp(
      home: SurveyListScreen(
        surveyStore: surveyStore,
        templateStore: templateStore,
        registry: buildDefaultRegistry(),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Castle survey'), findsOneWidget);

    await tester.tap(find.text('Castle survey'));
    await tester.pumpAndSettle();
    expect(find.byType(FillScreen), findsOneWidget);
  });

  testWidgets('swipe deletes a survey', (tester) async {
    final surveyStore = InMemorySurveyStore();
    await surveyStore.upsert(
        const Survey(id: 's1', templateId: 'sample', name: 'Castle survey'));

    await tester.pumpWidget(MaterialApp(
      home: SurveyListScreen(
        surveyStore: surveyStore,
        templateStore: InMemoryTemplateStore(),
        registry: buildDefaultRegistry(),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.drag(find.text('Castle survey'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(await surveyStore.all(), isEmpty);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd grid_app && flutter test test/fill/survey_list_screen_test.dart`
Expected: FAIL (`survey_list_screen.dart` not found).

- [ ] **Step 3: Write `SurveyListScreen`**

Create `grid_app/lib/fill/survey_list_screen.dart`:
```dart
import 'package:flutter/material.dart';

import '../controls/registry.dart';
import '../data/survey_store.dart';
import '../data/template_store.dart';
import '../model/survey.dart';
import 'fill_screen.dart';

/// Lists saved surveys: resume one (loads its template, opens FillScreen) or
/// swipe to delete. Surveys are created from the template list's Fill action.
class SurveyListScreen extends StatefulWidget {
  final SurveyStore surveyStore;
  final TemplateStore templateStore;
  final ControlRegistry registry;

  const SurveyListScreen({
    super.key,
    required this.surveyStore,
    required this.templateStore,
    required this.registry,
  });

  @override
  State<SurveyListScreen> createState() => _SurveyListScreenState();
}

class _SurveyListScreenState extends State<SurveyListScreen> {
  List<Survey> _surveys = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final list = await widget.surveyStore.all();
    if (!mounted) return;
    setState(() {
      _surveys = list;
      _loading = false;
    });
  }

  Future<void> _resume(Survey s) async {
    final template = await widget.templateStore.get(s.templateId);
    if (!mounted) return;
    if (template == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Template not found for this survey.')));
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => FillScreen(
        template: template,
        survey: s,
        store: widget.surveyStore,
        registry: widget.registry,
      ),
    ));
    await _reload();
  }

  Future<void> _delete(Survey s) async {
    await widget.surveyStore.delete(s.id);
    if (!mounted) return;
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Surveys')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _surveys.isEmpty
              ? const Center(
                  child: Text('No surveys yet. Fill a template to start one.'))
              : ListView(
                  children: [
                    for (final s in _surveys)
                      Dismissible(
                        key: ValueKey(s.id),
                        direction: DismissDirection.endToStart,
                        background: const SizedBox.shrink(),
                        secondaryBackground: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 16),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) => _delete(s),
                        child: ListTile(
                          title: Text(s.name),
                          subtitle: Text('${s.data.length} fields filled'),
                          onTap: () => _resume(s),
                        ),
                      ),
                  ],
                ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd grid_app && flutter test test/fill/survey_list_screen_test.dart`
Expected: PASS (list+resume, swipe-delete).

- [ ] **Step 5: Analyze + commit**

```bash
cd /Users/xxf/Desktop/scss/grid_app && flutter analyze
cd /Users/xxf/Desktop/scss && git add -A && git commit -q -m "feat(fill): SurveyListScreen (list, resume, delete)"
```
Expected: `No issues found!`, then commit.

---

### Task 8: Wire fill mode into the app (template list Fill action + Surveys entry + main)

**Files:**
- Modify: `grid_app/lib/builder/template_list_screen.dart`
- Modify: `grid_app/lib/main.dart`
- Modify: `grid_app/test/app_boot_test.dart`
- Modify: `grid_app/test/builder/template_list_screen_test.dart`
- Test: (extend) `grid_app/test/builder/template_list_screen_test.dart`

**Interfaces:**
- Consumes: `SurveyStore`/`InMemorySurveyStore`, `DriftSurveyStore`, `SurveyListScreen`, `FillScreen`, `Survey`.
- Produces:
  - `TemplateListScreen` gains `final SurveyStore surveyStore;`; each template tile gets a trailing "Fill" `IconButton` that creates a `Survey` and opens `FillScreen`; the AppBar gains a "Surveys" action opening `SurveyListScreen`.
  - `ScssGridApp` gains `final SurveyStore surveyStore;` and passes it down.
  - `main()` builds one `AppDatabase` shared by `DriftTemplateStore` and `DriftSurveyStore`.

- [ ] **Step 1: Update the existing tests first (they encode the new constructors)**

In `grid_app/test/app_boot_test.dart`, add the survey-store import and pass it:
```dart
import 'package:scss_grid/data/survey_store.dart';
```
Change the `pumpWidget` call to:
```dart
    await tester.pumpWidget(ScssGridApp(
        store: InMemoryTemplateStore(),
        surveyStore: InMemorySurveyStore(),
        registry: buildDefaultRegistry()));
```

In `grid_app/test/builder/template_list_screen_test.dart`, add the import:
```dart
import 'package:scss_grid/data/survey_store.dart';
```
Change the existing `TemplateListScreen(...)` construction to include `surveyStore`:
```dart
    await tester.pumpWidget(MaterialApp(
      home: TemplateListScreen(
          store: store,
          surveyStore: InMemorySurveyStore(),
          registry: buildDefaultRegistry()),
    ));
```
Then append a new test inside the same `main()` (after the existing one):
```dart
  testWidgets('Fill action on a template starts a survey in FillScreen',
      (tester) async {
    final store = InMemoryTemplateStore();
    await store.upsert(sampleTemplate().copyWith(id: 'a', name: 'Alpha'));
    final surveyStore = InMemorySurveyStore();

    await tester.pumpWidget(MaterialApp(
      home: TemplateListScreen(
          store: store,
          surveyStore: surveyStore,
          registry: buildDefaultRegistry()),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('fill-a')));
    await tester.pumpAndSettle();
    expect(find.byType(FillScreen), findsOneWidget);
    expect((await surveyStore.all()).length, 1); // a survey was created
  });
```
Add the imports this new test needs at the top of the file:
```dart
import 'package:scss_grid/fill/fill_screen.dart';
```
(`survey_store.dart` is already imported above.)

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd grid_app && flutter test test/app_boot_test.dart test/builder/template_list_screen_test.dart`
Expected: FAIL (compile errors: `ScssGridApp`/`TemplateListScreen` have no `surveyStore`; no `fill-a` key).

- [ ] **Step 3: Add `surveyStore` + Fill action + Surveys entry to `TemplateListScreen`**

In `grid_app/lib/builder/template_list_screen.dart`:

1. Add imports (with the existing ones):
```dart
import '../data/survey_store.dart';
import '../fill/fill_screen.dart';
import '../fill/survey_list_screen.dart';
import '../model/survey.dart';
```

2. Add the field + constructor param. Change:
```dart
  final TemplateStore store;
  final ControlRegistry registry;

  const TemplateListScreen(
      {super.key, required this.store, required this.registry});
```
to:
```dart
  final TemplateStore store;
  final SurveyStore surveyStore;
  final ControlRegistry registry;

  const TemplateListScreen(
      {super.key,
      required this.store,
      required this.surveyStore,
      required this.registry});
```

3. Add a method to start a survey (next to `_open`):
```dart
  Future<void> _fill(Template t) async {
    final survey = Survey(
      id: 'srv_${DateTime.now().millisecondsSinceEpoch}',
      templateId: t.id,
      name: t.name,
    );
    await widget.surveyStore.upsert(survey);
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => FillScreen(
        template: t,
        survey: survey,
        store: widget.surveyStore,
        registry: widget.registry,
      ),
    ));
  }

  void _openSurveys() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SurveyListScreen(
        surveyStore: widget.surveyStore,
        templateStore: widget.store,
        registry: widget.registry,
      ),
    ));
  }
```

4. Add the AppBar action. Change:
```dart
      appBar: AppBar(title: const Text('SCSS Templates')),
```
to:
```dart
      appBar: AppBar(
        title: const Text('SCSS Templates'),
        actions: [
          IconButton(
            icon: const Icon(Icons.assignment_outlined),
            tooltip: 'Surveys',
            onPressed: _openSurveys,
          ),
        ],
      ),
```

5. Add the per-template Fill button as the tile's `trailing`. Change the `ListTile` inside the `Dismissible`:
```dart
                        child: ListTile(
                          title: Text(t.name),
                          subtitle: Text(
                              '${t.grid.cols}×${t.grid.rows} · ${t.cells.length} cells'),
                          onTap: () => _open(t),
                        ),
```
to:
```dart
                        child: ListTile(
                          title: Text(t.name),
                          subtitle: Text(
                              '${t.grid.cols}×${t.grid.rows} · ${t.cells.length} cells'),
                          trailing: IconButton(
                            key: ValueKey('fill-${t.id}'),
                            icon: const Icon(Icons.edit_note),
                            tooltip: 'Fill',
                            onPressed: () => _fill(t),
                          ),
                          onTap: () => _open(t),
                        ),
```

- [ ] **Step 4: Wire `surveyStore` through `main.dart`**

In `grid_app/lib/main.dart`:

1. Add the survey-store import (with the others):
```dart
import 'data/survey_store.dart';
```

2. Build one shared database and both stores. Change:
```dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final store = DriftTemplateStore(AppDatabase.open());
  runApp(ScssGridApp(store: store, registry: buildDefaultRegistry()));
}
```
to:
```dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final db = AppDatabase.open();
  runApp(ScssGridApp(
    store: DriftTemplateStore(db),
    surveyStore: DriftSurveyStore(db),
    registry: buildDefaultRegistry(),
  ));
}
```

3. Add the field + pass it to the home screen. Change:
```dart
  final TemplateStore store;
  final ControlRegistry registry;

  const ScssGridApp({super.key, required this.store, required this.registry});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'SCSS Grid Builder',
        theme: ThemeData(useMaterial3: true),
        home: TemplateListScreen(store: store, registry: registry),
      );
```
to:
```dart
  final TemplateStore store;
  final SurveyStore surveyStore;
  final ControlRegistry registry;

  const ScssGridApp(
      {super.key,
      required this.store,
      required this.surveyStore,
      required this.registry});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'SCSS Grid Builder',
        theme: ThemeData(useMaterial3: true),
        home: TemplateListScreen(
            store: store, surveyStore: surveyStore, registry: registry),
      );
```

- [ ] **Step 5: Run the full suite + analyze**

Run: `cd grid_app && flutter analyze && flutter test`
Expected: `No issues found!` and ALL tests green (the updated boot/template-list tests, the new fill tests, and every Phase 1 test).

- [ ] **Step 6: Commit**

```bash
cd /Users/xxf/Desktop/scss && git add -A && git commit -q -m "feat: wire fill mode (template Fill action, Surveys entry, main stores)"
```

---

### Task 9: Manual simulator pass (controller, not a subagent)

**Files:** none

- [ ] **Step 1: Run the app on the emulator and verify the fill loop by observation**

```bash
flutter emulators --launch Medium_Phone_API_35
cd /Users/xxf/Desktop/scss/grid_app && flutter run -d emulator-5554
```
Verify and report what you see:
1. Home → an existing template tile shows an "edit_note" (Fill) icon on its right; the AppBar shows a "Surveys" icon. (Create a template first via + if the list is empty, add a Title + a couple of Fields in the builder, Save, go back.)
2. Tap the template's Fill icon → FillScreen opens showing the same A4 grid; title text is read-only; field cells show `label | input` boxes.
3. Tap a field's input → keyboard appears → type a value; it stays in the cell.
4. Tap Export → the PDF preview shows the A4 page with your typed values in the field boxes (WYSIWYG — matches the on-screen grid).
5. Tap Save → "Survey saved." snackbar. Back out to home → AppBar "Surveys" → the survey is listed; tap it → values are still there (persisted); Export again shows the same values.
6. On the Surveys list, swipe a survey left → it deletes.

If anything misbehaves (tiny inputs unusable, values not persisting, PDF blank), report DONE_WITH_CONCERNS with specifics. Note: very dense templates make inputs small — that is the known A4 ergonomics trade-off (spec §13); zoom/pan is deferred to the polish phase.

---

## Phase 2 — Definition of Done

- A saved template can be filled: the fill screen renders the *same* grid (shared `cellRectMm`/`pageScale`), title-like controls are read-only, and `field` controls accept text/number input bound to a `key→value` data map.
- Answers persist as a `Survey` (Drift `surveys` table, schema v2 migration) and can be resumed from a Surveys list; surveys can be deleted.
- Export produces a single-page A4 PDF that prints the filled values via the existing `renderTemplate(template, data, registry)` — what you fill is what prints (WYSIWYG).
- Fill plumbing is control-generic: it goes through `ControlSpec.fillWidget`/`dataKey`, no `switch (type)` — a future control drops in without touching fill code.
- `flutter analyze` = 0 issues; `flutter test` all green; manual simulator pass confirms fill → save → resume → export.
- Deferred to later phases (not regressions): richer inputs for `valueType` select/date/coordinate and GPS (Phase 3/4), `image`/`multiImage`/`satelliteDiagram` fill + clear (Phase 3), deviceChecklist (Phase 4), NotoSansSC for Chinese glyphs (Phase 5), canvas zoom/pan for fill ergonomics (polish).

## Self-Review (against spec)

**Spec coverage (Phase 2 slice = spec §12.2 "填写闭环:填写模式渲染同一网格;基本字段输入 + 存库 + 导出"):**
- §7 "填写模式:同一网格渲染,cell 内的占位变成真实输入" → Task 5 (`FillCanvas` reuses `cellRectMm`/`pageScale`) + Task 4 (`FieldControl.fillWidget` real input). ✓
- §7 "结构不可改" (values only) → fill mode has no structure edits; `Survey` holds only `data`. ✓
- §5/§7 "一份模型驱动填写/PDF…三处共用 cell 矩形几何" → `FillCanvas` and `renderTemplate` both use `cellRectMm`; one `data` map feeds both. ✓
- §9 persistence (`surveys`, `survey.data` keyed by control key) → Tasks 1–3 (`Survey`, `SurveyStore`, Drift `surveys` table + migration). ✓
- §10.1 plugin-generic (no per-type switch) → fill goes through `ControlSpec.fillWidget`/`dataKey`; registry iterated generically (Tasks 4, 5). ✓
- §12.2 "导出" → Task 6 (`FillScreen` Export → `PdfPreviewScreen(data:)` → `renderTemplate`). ✓
- Read-only controls (title) in fill mode → Task 4 default `fillWidget = previewWidget`. ✓

**Placeholder scan:** No TBD/TODO. Every code step contains complete code (model, stores, controls, canvas, screens, wiring). Task 9 is an explicit manual-observation step with concrete checks. The `expands:true`/`InputBorder.none` field styling is real, not a placeholder.

**Type consistency (producer → consumer):**
- `Survey({id, templateId, name, data})` + `copyWith` + `toJson`/`fromJson` — consistent across Tasks 1, 3, 6, 7, 8.
- `SurveyStore` methods `upsert/get/all/delete` — same shape in abstract (Task 2), `InMemorySurveyStore` (Task 2), `DriftSurveyStore` (Task 3), and all consumers.
- `ControlSpec.dataKey(Cell)→String?` and `fillWidget(Cell, Object?, void Function(Object?))` — defined Task 4, consumed by `FillCanvas` (Task 5) exactly.
- `FillCanvas({template, registry, data, onChanged: (String key, Object? value)})` — Task 5 producer, Task 6 consumer match.
- `FillScreen({template, survey, store, registry})` — Task 6 producer; consumed identically by `SurveyListScreen` (Task 7) and `TemplateListScreen._fill` (Task 8).
- `SurveyListScreen({surveyStore, templateStore, registry})` — Task 7 producer; Task 8 consumer match.
- `PdfPreviewScreen` new optional `data` (default `const {}`) — keeps the builder's existing call valid (Task 6).
- `ScssGridApp`/`TemplateListScreen` gain `surveyStore` — tests updated in lockstep (Task 8 Step 1).
- Drift: `SurveyRows` → generated `SurveyRowsCompanion.insert(id, templateId, name, json)` + `surveyRows` getter used by `DriftSurveyStore` and the migration (Task 3).
