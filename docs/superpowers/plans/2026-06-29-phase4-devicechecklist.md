# Phase 4 — `deviceChecklist` 控件 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 新增 `deviceChecklist` 控件——一个网格原生、整页对齐的设备勾选表(固定三列:勾选/数量/备注),补上真实勘测表 "Type of device to install" 区块,使其可 100% 建模。

**Architecture:** 控件占网格矩形 `colSpan × rowSpan`;**不变式 `rowSpan == rows.length + (showHeader?1:0)`** —— 设备行数与 `rowSpan` 双向同步(拖手柄改 `rowSpan` → 行清单跟随;属性面板增删行 → `rowSpan` 跟随),两条路径都过现有 `isValid` 守卫。三个面(建模 `previewWidget` / 填写 `fillWidget` / PDF `paintPdf`)复用 `multi_image_control.dart` 的 "cell 矩形内 `Column(Expanded 行)+ Row(Expanded 列)` 铺满" 写法。双向同步靠给 `ControlSpec` 加 3 个默认 no-op 钩子(`requiredRowSpan` / `reconcile` / `defaultColSpan`),在 `editor_ops` 加两个纯函数,接到 `builder_screen` 的现有回调,**全程泛型调钩子、无按类型 switch**。

**Tech Stack:** Flutter / Dart 3.6.1,包名 `scss_grid`;`pdf` 包(PDF);`flutter_test`(测试)。

## Global Constraints

- **控件插件化**:加控件 = 1 个新文件(`lib/controls/device_checklist_control.dart`)+ 在 `lib/controls/default_controls.dart` 注册 1 行;palette/builder/fill/pdf 四处泛型遍历注册表,**不得写按 `type` 的 switch**。
- **不变式**:`rowSpan == rows.length + (showHeader ? 1 : 0)`,始终成立。
- **固定三列(本期不做可配置列)**:勾选+设备名合占首列、`Number` 列(`numberCols` 列)、`Remark` 列(`remarkCols` 列);设备名列 = `colSpan − numberCols − remarkCols`,守卫 `≥ 1`。
- **填写值**:`data[props['key']]` = `{ "<rowKey>": {"check": bool, "number": String, "remark": String}, ... }`;`check` 默认 `false`,空字段省略;无 Drift schema 变更。
- **UI 文案中文/英文照搬真实表**(`title` 默认 `Type of device to install`);**PDF 字号 9pt**;勾选在 PDF 用 `[X]`/`[ ]` 小方框(当前未嵌中文字体,避免缺字)。
- **验收基线**:现有 173 测试保持绿、新增测试全绿、`flutter analyze` 0 issue。
- **开发循环(真机)**:`flutter build apk --debug` + `adb install -r`(三星 SM-A528B,id `RZCRA03MZVX`,adb 绝对路径 `/Users/xxf/Library/Android/sdk/platform-tools/adb`)。
- **命令工作目录**:所有 `flutter`/`dart`/测试命令在 `/Users/xxf/Desktop/scss/grid_app` 下执行。

---

## File Structure

- **Create** `grid_app/lib/controls/device_checklist_control.dart` — `DeviceChecklistControl extends ControlSpec` + 私有填写 widget `_DeviceChecklistField`。单一职责:这个控件的全部(palette 元数据 / 几何钩子 / 三个面 / 属性面板)。
- **Modify** `grid_app/lib/controls/control_spec.dart` — 加 3 个默认 no-op 钩子。
- **Modify** `grid_app/lib/controls/default_controls.dart` — 注册 1 行。
- **Modify** `grid_app/lib/builder/editor_ops.dart` — 加 2 个纯函数 `reconcileCell` / `syncRowSpan`(泛型调钩子)。
- **Modify** `grid_app/lib/builder/builder_screen.dart` — 几何/属性/放置三处回调接同步。
- **Create** `grid_app/test/controls/device_checklist_control_test.dart` — 控件单测。
- **Create** `grid_app/test/builder/device_checklist_sync_test.dart` — 同步纯函数 + 放置/守卫测。

---

### Task 1: `ControlSpec` 加 3 个默认 no-op 钩子

**Files:**
- Modify: `grid_app/lib/controls/control_spec.dart`
- Test: `grid_app/test/controls/device_checklist_control_test.dart`(本任务先建文件,放钩子默认值测试)

**Interfaces:**
- Produces:
  - `int? ControlSpec.requiredRowSpan(Cell cell)` — 默认 `null`(控件不约束 rowSpan)。
  - `Cell ControlSpec.reconcile(Cell cell)` — 默认 `cell`(identity)。
  - `int? ControlSpec.defaultColSpan()` — 默认 `null`(放置时沿用 freeRunWidth)。

- [ ] **Step 1: Write the failing test**

Create `grid_app/test/controls/device_checklist_control_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/controls/number_control.dart';
import 'package:scss_grid/model/cell.dart';

void main() {
  test('ControlSpec hooks default to no-op on existing controls', () {
    final n = NumberControl();
    const cell = Cell(id: 'n', col: 0, row: 0, type: 'number');
    expect(n.requiredRowSpan(cell), isNull);
    expect(n.reconcile(cell), same(cell));
    expect(n.defaultColSpan(), isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/controls/device_checklist_control_test.dart`
Expected: FAIL — compile error, `requiredRowSpan`/`reconcile`/`defaultColSpan` not defined on `ControlSpec`.

- [ ] **Step 3: Add the hooks**

In `grid_app/lib/controls/control_spec.dart`, before the closing `}` of `abstract class ControlSpec`, add:

```dart
  /// The rowSpan this control requires for its current props, or null if it
  /// doesn't constrain rowSpan. deviceChecklist returns rows + header so the
  /// frame syncs its height to the device-row count. Default: null.
  int? requiredRowSpan(Cell cell) => null;

  /// After a geometry edit (e.g. dragging the vertical handle changed rowSpan),
  /// return a cell whose internal invariant holds again. deviceChecklist makes
  /// its `rows` list length follow rowSpan. Default: identity.
  Cell reconcile(Cell cell) => cell;

  /// Preferred initial colSpan when placed, or null to use the free run width.
  /// deviceChecklist returns 4 so its three columns fit. Default: null.
  int? defaultColSpan() => null;
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/controls/device_checklist_control_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/xxf/Desktop/scss/grid_app
git add lib/controls/control_spec.dart test/controls/device_checklist_control_test.dart
git commit -m "feat(controls): add ControlSpec geometry hooks (requiredRowSpan/reconcile/defaultColSpan, default no-op)"
```

---

### Task 2: `DeviceChecklistControl` 骨架 + 注册

**Files:**
- Create: `grid_app/lib/controls/device_checklist_control.dart`
- Modify: `grid_app/lib/controls/default_controls.dart`
- Test: `grid_app/test/controls/device_checklist_control_test.dart`

**Interfaces:**
- Consumes: `ControlSpec`, `Cell`.
- Produces:
  - `class DeviceChecklistControl extends ControlSpec` with `type == 'deviceChecklist'`, `label == 'Device Checklist'`, `icon == Icons.checklist`.
  - `defaultProps()` keys: `key`(`'deviceChecklist'`), `title`(`'Type of device to install'`), `showHeader`(`true`), `numberLabel`(`'Number'`), `remarkLabel`(`'Remark'`), `rows`(4 个 `{label:'', key:'r1'..'r4'}`), `numberCols`(`1`), `remarkCols`(`2`).
  - static helpers: `List<Map<String,dynamic>> rowsOf(Cell)`, `bool showHeaderOf(Cell)`, `int numberColsOf(Cell)`, `int remarkColsOf(Cell)`, `int nameColsFor(Cell, int colSpan)`.
  - Registered in `buildDefaultRegistry`.

- [ ] **Step 1: Write the failing test**

Append to `grid_app/test/controls/device_checklist_control_test.dart` (inside `main()`):

```dart
  test('type / label / defaultProps / dataKey', () {
    final c = DeviceChecklistControl();
    expect(c.type, 'deviceChecklist');
    expect(c.label, 'Device Checklist');
    final p = c.defaultProps();
    expect(p['key'], 'deviceChecklist');
    expect(p['title'], 'Type of device to install');
    expect(p['showHeader'], true);
    expect(p['numberLabel'], 'Number');
    expect(p['remarkLabel'], 'Remark');
    expect(p['numberCols'], 1);
    expect(p['remarkCols'], 2);
    expect((p['rows'] as List).length, 4);
    final cell = Cell(id: 'd', col: 0, row: 0, type: 'deviceChecklist', props: p);
    expect(c.dataKey(cell), 'deviceChecklist');
    expect(DeviceChecklistControl.showHeaderOf(cell), true);
    expect(DeviceChecklistControl.numberColsOf(cell), 1);
    expect(DeviceChecklistControl.remarkColsOf(cell), 2);
    // colSpan 6: name = 6 - 1 - 2 = 3
    expect(DeviceChecklistControl.nameColsFor(cell, 6), 3);
  });

  test('registered in default registry', () {
    final r = buildDefaultRegistry();
    expect(r.specFor('deviceChecklist'), isA<DeviceChecklistControl>());
  });
```

Add imports at the top of the test file:

```dart
import 'package:scss_grid/controls/default_controls.dart';
import 'package:scss_grid/controls/device_checklist_control.dart';
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/controls/device_checklist_control_test.dart`
Expected: FAIL — `DeviceChecklistControl` undefined.

- [ ] **Step 3: Create the control skeleton + register**

Create `grid_app/lib/controls/device_checklist_control.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;

import '../model/cell.dart';
import 'control_spec.dart';

/// A grid-native device checklist: fixed device rows × three columns
/// (checkbox+name / Number / Remark). Each device row = one grid row, so the
/// table aligns with the rest of the page (spec 2026-06-29, scheme B). rowSpan
/// and the device-row count stay in sync via [requiredRowSpan] / [reconcile].
class DeviceChecklistControl extends ControlSpec {
  @override
  String get type => 'deviceChecklist';
  @override
  String get label => 'Device Checklist';
  @override
  IconData get icon => Icons.checklist;

  @override
  Map<String, dynamic> defaultProps() => {
        'key': 'deviceChecklist',
        'title': 'Type of device to install',
        'showHeader': true,
        'numberLabel': 'Number',
        'remarkLabel': 'Remark',
        'rows': [
          {'label': '', 'key': 'r1'},
          {'label': '', 'key': 'r2'},
          {'label': '', 'key': 'r3'},
          {'label': '', 'key': 'r4'},
        ],
        'numberCols': 1,
        'remarkCols': 2,
      };

  // ---- prop accessors (static so tests + widgets share them) ----
  static List<Map<String, dynamic>> rowsOf(Cell c) =>
      (c.props['rows'] as List?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList() ??
      <Map<String, dynamic>>[];
  static bool showHeaderOf(Cell c) => c.props['showHeader'] as bool? ?? true;
  static int numberColsOf(Cell c) => (c.props['numberCols'] as num?)?.toInt() ?? 1;
  static int remarkColsOf(Cell c) => (c.props['remarkCols'] as num?)?.toInt() ?? 2;

  /// Device-name column width in grid columns = colSpan − number − remark,
  /// floored at 1 so rendering never divides by a non-positive flex.
  static int nameColsFor(Cell c, int colSpan) {
    final n = colSpan - numberColsOf(c) - remarkColsOf(c);
    return n < 1 ? 1 : n;
  }

  @override
  pw.Widget paintPdf(Cell cell, Map<String, dynamic> data) => pw.SizedBox();
}
```

In `grid_app/lib/controls/default_controls.dart`, add the import (keep alphabetical near the others):

```dart
import 'device_checklist_control.dart';
```

and register inside `buildDefaultRegistry`, after `SatelliteDiagramControl`:

```dart
  r.register(DeviceChecklistControl());
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/controls/device_checklist_control_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/xxf/Desktop/scss/grid_app
git add lib/controls/device_checklist_control.dart lib/controls/default_controls.dart test/controls/device_checklist_control_test.dart
git commit -m "feat(controls): deviceChecklist skeleton + register (type/defaultProps/accessors)"
```

---

### Task 3: 几何方法 `requiredRowSpan` / `reconcile`(不变式)

**Files:**
- Modify: `grid_app/lib/controls/device_checklist_control.dart`
- Test: `grid_app/test/controls/device_checklist_control_test.dart`

**Interfaces:**
- Consumes: `DeviceChecklistControl`, its `rowsOf`/`showHeaderOf`.
- Produces (overrides):
  - `requiredRowSpan(cell)` → `rowsOf(cell).length + (showHeaderOf(cell) ? 1 : 0)`.
  - `reconcile(cell)` → cell whose `rows` length == `rowSpan − header` (append blank rows with fresh `r<n>` keys / truncate from the end).
  - `defaultColSpan()` → `4`.

- [ ] **Step 1: Write the failing test**

Append to the test file's `main()`:

```dart
  test('requiredRowSpan = rows + header', () {
    final c = DeviceChecklistControl();
    final withHeader = Cell(
        id: 'd', col: 0, row: 0, type: 'deviceChecklist', props: c.defaultProps());
    expect(c.requiredRowSpan(withHeader), 5); // 4 rows + header
    final noHeader = withHeader.copyWith(
        props: {...withHeader.props, 'showHeader': false});
    expect(c.requiredRowSpan(noHeader), 4);
    expect(c.defaultColSpan(), 4);
  });

  test('reconcile makes rows follow rowSpan (grow appends blank, shrink trims)', () {
    final c = DeviceChecklistControl();
    final base = Cell(
        id: 'd', col: 0, row: 0, colSpan: 6, rowSpan: 5,
        type: 'deviceChecklist', props: c.defaultProps()); // 4 rows, header

    // grow: rowSpan 7 → want 6 device rows → append 2 blanks with unique keys
    final grown = c.reconcile(base.copyWith(rowSpan: 7));
    final grownRows = DeviceChecklistControl.rowsOf(grown);
    expect(grownRows.length, 6);
    expect(grownRows.map((e) => e['key']).toSet().length, 6); // keys unique
    expect(grownRows.last['label'], '');

    // shrink: rowSpan 3 → want 2 device rows → trim from the end
    final shrunk = c.reconcile(base.copyWith(rowSpan: 3));
    expect(DeviceChecklistControl.rowsOf(shrunk).length, 2);

    // already consistent → unchanged identity-ish (same length)
    expect(DeviceChecklistControl.rowsOf(c.reconcile(base)).length, 4);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/controls/device_checklist_control_test.dart -n "reconcile"`
Expected: FAIL — `requiredRowSpan`/`reconcile` still return base defaults (null/identity), assertions fail.

- [ ] **Step 3: Implement the overrides**

In `device_checklist_control.dart`, add these methods to the class (after `nameColsFor`):

```dart
  @override
  int? requiredRowSpan(Cell cell) =>
      rowsOf(cell).length + (showHeaderOf(cell) ? 1 : 0);

  @override
  int? defaultColSpan() => 4;

  @override
  Cell reconcile(Cell cell) {
    final header = showHeaderOf(cell) ? 1 : 0;
    final want = cell.rowSpan - header;
    final wantRows = want < 0 ? 0 : want;
    final rows = rowsOf(cell);
    if (rows.length == wantRows) return cell;
    final next = [...rows];
    if (next.length > wantRows) {
      next.removeRange(wantRows, next.length);
    } else {
      while (next.length < wantRows) {
        next.add({'label': '', 'key': _freeRowKey(next)});
      }
    }
    return cell.copyWith(props: {...cell.props, 'rows': next});
  }

  /// First `r<n>` key (n from 1) not already used in [rows].
  static String _freeRowKey(List<Map<String, dynamic>> rows) {
    final used = rows.map((e) => e['key']).toSet();
    var n = 1;
    while (used.contains('r$n')) {
      n++;
    }
    return 'r$n';
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/controls/device_checklist_control_test.dart`
Expected: PASS (all tests in the file).

- [ ] **Step 5: Commit**

```bash
cd /Users/xxf/Desktop/scss/grid_app
git add lib/controls/device_checklist_control.dart test/controls/device_checklist_control_test.dart
git commit -m "feat(controls): deviceChecklist geometry invariant (requiredRowSpan/reconcile/defaultColSpan)"
```

---

### Task 4: PDF `paintPdf`

**Files:**
- Modify: `grid_app/lib/controls/device_checklist_control.dart`
- Test: `grid_app/test/controls/device_checklist_control_test.dart`

**Interfaces:**
- Consumes: `rowsOf`/`showHeaderOf`/`numberColsOf`/`remarkColsOf`/`nameColsFor`; fill value shape `{rowKey: {check, number, remark}}`.
- Produces: `paintPdf(cell, data)` renders a `pw.Column` of equal `Expanded` rows (header + device rows), each a `pw.Row` of three `Expanded(flex)` cells; tolerates null/missing values without throwing.

- [ ] **Step 1: Write the failing test**

Add `import 'package:pdf/widgets.dart' as pw;` to the test file's imports, then append to `main()`:

```dart
  test('paintPdf builds a Column of rows, tolerates null/missing values', () {
    final c = DeviceChecklistControl();
    final cell = Cell(
        id: 'd', col: 0, row: 0, colSpan: 6, rowSpan: 5,
        type: 'deviceChecklist', props: c.defaultProps());
    // stub returns pw.SizedBox → this fails until the real renderer lands
    expect(c.paintPdf(cell, const {}), isA<pw.Column>());
    expect(
        () => c.paintPdf(cell, const {
              'deviceChecklist': {
                'r1': {'check': true, 'number': '3', 'remark': 'ok'},
                'r3': {'check': false},
              }
            }),
        returnsNormally);
    final noHeader =
        cell.copyWith(props: {...cell.props, 'showHeader': false});
    expect(() => c.paintPdf(noHeader, const {}), returnsNormally);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/controls/device_checklist_control_test.dart -n "paintPdf"`
Expected: FAIL — the stub `paintPdf` returns `pw.SizedBox`, so `isA<pw.Column>()` fails.

- [ ] **Step 3: Implement `paintPdf`**

Replace the stub `paintPdf` in `device_checklist_control.dart` with:

```dart
  static Map<String, dynamic> _rowValue(Map<String, dynamic> data, String key, String rowKey) {
    final v = data[key];
    if (v is Map) {
      final rv = v[rowKey];
      if (rv is Map) return Map<String, dynamic>.from(rv);
    }
    return const {};
  }

  @override
  pw.Widget paintPdf(Cell cell, Map<String, dynamic> data) {
    final key = cell.props['key'] as String? ?? '';
    final rows = rowsOf(cell);
    final header = showHeaderOf(cell);
    final nameFlex = nameColsFor(cell, cell.colSpan);
    final numFlex = numberColsOf(cell);
    final remFlex = remarkColsOf(cell);
    const fs = pw.TextStyle(fontSize: 9);

    pw.Widget pcell(pw.Widget child, {pw.Alignment align = pw.Alignment.centerLeft}) =>
        pw.Container(
          alignment: align,
          padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 1),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey, width: 0.4),
          ),
          child: child,
        );

    pw.Widget row3(pw.Widget a, pw.Widget b, pw.Widget cc) => pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Expanded(flex: nameFlex, child: a),
            pw.Expanded(flex: numFlex, child: b),
            pw.Expanded(flex: remFlex, child: cc),
          ],
        );

    final children = <pw.Widget>[];
    if (header) {
      children.add(pw.Expanded(
        child: row3(
          pcell(pw.Text(cell.props['title'] as String? ?? '', style: fs)),
          pcell(pw.Text(cell.props['numberLabel'] as String? ?? '', style: fs)),
          pcell(pw.Text(cell.props['remarkLabel'] as String? ?? '', style: fs)),
        ),
      ));
    }
    for (final r in rows) {
      final rk = r['key'] as String? ?? '';
      final rv = _rowValue(data, key, rk);
      final checked = rv['check'] == true;
      children.add(pw.Expanded(
        child: row3(
          pcell(pw.Row(children: [
            pw.Container(
              width: 8,
              height: 8,
              alignment: pw.Alignment.center,
              decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.6)),
              child: checked
                  ? pw.Text('X', style: const pw.TextStyle(fontSize: 7))
                  : pw.SizedBox(),
            ),
            pw.SizedBox(width: 3),
            pw.Expanded(child: pw.Text(r['label'] as String? ?? '', style: fs)),
          ])),
          pcell(pw.Text(rv['number']?.toString() ?? '', style: fs)),
          pcell(pw.Text(rv['remark']?.toString() ?? '', style: fs)),
        ),
      ));
    }
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: children.isEmpty ? [pw.SizedBox()] : children,
    );
  }
```

`PdfColors` comes from `package:pdf/pdf.dart` — add this import at the top of `device_checklist_control.dart` (alongside the existing `pdf/widgets.dart` import):

```dart
import 'package:pdf/pdf.dart';
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/controls/device_checklist_control_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/xxf/Desktop/scss/grid_app
git add lib/controls/device_checklist_control.dart test/controls/device_checklist_control_test.dart
git commit -m "feat(controls): deviceChecklist paintPdf (header + rows, [X]/[ ] checkbox, 9pt)"
```

---

### Task 5: 填写面 `fillWidget`

**Files:**
- Modify: `grid_app/lib/controls/device_checklist_control.dart`
- Test: `grid_app/test/controls/device_checklist_control_test.dart`

**Interfaces:**
- Consumes: fill value `Map<String,dynamic>` keyed by rowKey.
- Produces:
  - `fillWidget(cell, value, onChanged)` → `_DeviceChecklistField`.
  - Widget keys: `devck-check-<rowKey>` (Checkbox), `devck-number-<rowKey>` (TextField), `devck-remark-<rowKey>` (TextField).
  - On change, `onChanged` receives the **whole** nested map with only the touched `rowKey`/field updated.

- [ ] **Step 1: Write the failing test**

Append to `main()` (and add imports `package:flutter/material.dart`):

```dart
  Widget _host(Widget child) => MaterialApp(
      home: Scaffold(body: SizedBox(width: 320, height: 320, child: child)));

  testWidgets('fillWidget: tap a row checkbox → onChanged sets that row check',
      (tester) async {
    final c = DeviceChecklistControl();
    final cell = Cell(
        id: 'd', col: 0, row: 0, colSpan: 6, rowSpan: 5,
        type: 'deviceChecklist', props: c.defaultProps());
    Object? captured;
    await tester.pumpWidget(_host(c.fillWidget(cell, null, (v) => captured = v)));
    await tester.tap(find.byKey(const ValueKey('devck-check-r2')));
    await tester.pump();
    expect(captured, isA<Map>());
    expect((captured as Map)['r2'], {'check': true});
  });

  testWidgets('fillWidget: typing Number/Remark writes that row only',
      (tester) async {
    final c = DeviceChecklistControl();
    final cell = Cell(
        id: 'd', col: 0, row: 0, colSpan: 6, rowSpan: 5,
        type: 'deviceChecklist', props: c.defaultProps());
    Map<String, dynamic> value = {};
    await tester.pumpWidget(_host(c.fillWidget(cell, value, (v) {
      value = Map<String, dynamic>.from(v as Map);
    })));
    await tester.enterText(find.byKey(const ValueKey('devck-number-r1')), '3');
    expect((value['r1'] as Map)['number'], '3');
    expect(value.containsKey('r2'), isFalse);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/controls/device_checklist_control_test.dart -n "fillWidget"`
Expected: FAIL — `fillWidget` not overridden (default returns `previewWidget`'s SizedBox), keys not found.

- [ ] **Step 3: Implement `fillWidget` + `_DeviceChecklistField`**

In `device_checklist_control.dart`, add the override (inside the class):

```dart
  static Map<String, dynamic> valueOf(Object? v) =>
      v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

  @override
  Widget fillWidget(
          Cell cell, Object? value, void Function(Object? value) onChanged) =>
      _DeviceChecklistField(
        cell: cell,
        value: valueOf(value),
        onChanged: onChanged,
      );
```

Then add the widget at the bottom of the file (outside the class):

```dart
class _DeviceChecklistField extends StatelessWidget {
  final Cell cell;
  final Map<String, dynamic> value;
  final void Function(Object? value) onChanged;

  const _DeviceChecklistField({
    required this.cell,
    required this.value,
    required this.onChanged,
  });

  void _set(String rowKey, String field, Object? v) {
    final next = {...value};
    final row = {...(next[rowKey] as Map? ?? const {})};
    row[field] = v;
    next[rowKey] = row;
    onChanged(next);
  }

  Map<String, dynamic> _row(String rowKey) {
    final r = value[rowKey];
    return r is Map ? Map<String, dynamic>.from(r) : const {};
  }

  @override
  Widget build(BuildContext context) {
    final rows = DeviceChecklistControl.rowsOf(cell);
    final header = DeviceChecklistControl.showHeaderOf(cell);
    final nameFlex = DeviceChecklistControl.nameColsFor(cell, cell.colSpan);
    final numFlex = DeviceChecklistControl.numberColsOf(cell);
    final remFlex = DeviceChecklistControl.remarkColsOf(cell);
    const cellBorder = Border.fromBorderSide(
        BorderSide(color: Color(0xFFCCCCCC), width: 0.5));

    Widget box(Widget child) =>
        Container(decoration: const BoxDecoration(border: cellBorder), child: child);

    Widget row3(Widget a, Widget b, Widget cc) => Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: nameFlex, child: box(a)),
            Expanded(flex: numFlex, child: box(b)),
            Expanded(flex: remFlex, child: box(cc)),
          ],
        );

    Widget input(String rowKey, String field) => TextFormField(
          key: ValueKey('devck-$field-$rowKey'),
          initialValue: _row(rowKey)[field]?.toString() ?? '',
          keyboardType:
              field == 'number' ? TextInputType.number : TextInputType.text,
          style: const TextStyle(fontSize: 9),
          decoration: const InputDecoration(
            isDense: true,
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(horizontal: 3, vertical: 2),
          ),
          onChanged: (v) => _set(rowKey, field, v),
        );

    final children = <Widget>[];
    if (header) {
      Widget h(String s) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
          child: Text(s,
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)));
      children.add(Expanded(
        child: row3(
          h(cell.props['title'] as String? ?? ''),
          h(cell.props['numberLabel'] as String? ?? ''),
          h(cell.props['remarkLabel'] as String? ?? ''),
        ),
      ));
    }
    for (final r in rows) {
      final rk = r['key'] as String? ?? '';
      final checked = _row(rk)['check'] == true;
      children.add(Expanded(
        child: row3(
          Row(children: [
            SizedBox(
              width: 28,
              child: Checkbox(
                key: ValueKey('devck-check-$rk'),
                value: checked,
                visualDensity: VisualDensity.compact,
                onChanged: (v) => _set(rk, 'check', v ?? false),
              ),
            ),
            Expanded(
              child: Text(r['label'] as String? ?? '',
                  style: const TextStyle(fontSize: 9)),
            ),
          ]),
          input(rk, 'number'),
          input(rk, 'remark'),
        ),
      ));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children.isEmpty ? const [SizedBox()] : children,
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/controls/device_checklist_control_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/xxf/Desktop/scss/grid_app
git add lib/controls/device_checklist_control.dart test/controls/device_checklist_control_test.dart
git commit -m "feat(controls): deviceChecklist fillWidget (per-row checkbox + number/remark inputs)"
```

---

### Task 6: 建模面 `previewWidget` + 属性面板 `propEditor`

**Files:**
- Modify: `grid_app/lib/controls/device_checklist_control.dart`
- Test: `grid_app/test/controls/device_checklist_control_test.dart`

**Interfaces:**
- Produces:
  - `previewWidget(cell)` — design-canvas skeleton (header + device rows with `☐` + label placeholder).
  - `propEditor(cell, onChanged)` — fields: Key/title/showHeader/numberLabel/remarkLabel; a per-row label `TextFormField` (key `devck-rowlabel-<rowKey>`) + delete button (key `devck-delrow-<rowKey>`); an add-row button (key `devck-addrow`).
  - Add row → `onChanged` props whose `rows` has one more `{label:'', key:<fresh>}`. Delete row → one fewer.

- [ ] **Step 1: Write the failing test**

Append to `main()`:

```dart
  testWidgets('propEditor: add row appends a blank row to props.rows',
      (tester) async {
    final c = DeviceChecklistControl();
    final cell = Cell(
        id: 'd', col: 0, row: 0, colSpan: 6, rowSpan: 5,
        type: 'deviceChecklist', props: c.defaultProps());
    Map<String, dynamic>? captured;
    await tester.pumpWidget(_host(SingleChildScrollView(
        child: c.propEditor(cell, (p) => captured = p))));
    await tester.tap(find.byKey(const ValueKey('devck-addrow')));
    expect(captured, isNotNull);
    expect((captured!['rows'] as List).length, 5);
  });

  testWidgets('propEditor: delete row removes that row', (tester) async {
    final c = DeviceChecklistControl();
    final cell = Cell(
        id: 'd', col: 0, row: 0, colSpan: 6, rowSpan: 5,
        type: 'deviceChecklist', props: c.defaultProps());
    Map<String, dynamic>? captured;
    await tester.pumpWidget(_host(SingleChildScrollView(
        child: c.propEditor(cell, (p) => captured = p))));
    await tester.tap(find.byKey(const ValueKey('devck-delrow-r2')));
    expect((captured!['rows'] as List).length, 3);
    expect((captured!['rows'] as List).map((e) => e['key']),
        isNot(contains('r2')));
  });

  testWidgets('propEditor: editing a row label updates props.rows', (tester) async {
    final c = DeviceChecklistControl();
    final cell = Cell(
        id: 'd', col: 0, row: 0, colSpan: 6, rowSpan: 5,
        type: 'deviceChecklist', props: c.defaultProps());
    Map<String, dynamic>? captured;
    await tester.pumpWidget(_host(SingleChildScrollView(
        child: c.propEditor(cell, (p) => captured = p))));
    await tester.enterText(
        find.byKey(const ValueKey('devck-rowlabel-r1')), 'POE Switch');
    final rows = captured!['rows'] as List;
    expect((rows.first as Map)['label'], 'POE Switch');
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/controls/device_checklist_control_test.dart -n "propEditor"`
Expected: FAIL — `propEditor` not overridden; keys not found.

- [ ] **Step 3: Implement `previewWidget` + `propEditor`**

In `device_checklist_control.dart`, add inside the class:

```dart
  @override
  Widget previewWidget(Cell cell) {
    final rows = rowsOf(cell);
    final header = showHeaderOf(cell);
    const grey = TextStyle(fontSize: 9, color: Color(0xFF9A9A9A));
    Widget line(String a) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
        child: Text(a, style: grey, maxLines: 1, overflow: TextOverflow.ellipsis));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (header)
          Expanded(
              child: line(cell.props['title'] as String? ?? 'Device checklist')),
        for (final r in rows)
          Expanded(
            child: line('☐ ${(r['label'] as String?)?.isNotEmpty == true ? r['label'] : '设备名'}'),
          ),
      ],
    );
  }

  @override
  Widget propEditor(
      Cell cell, void Function(Map<String, dynamic> props) onChanged) {
    final rows = rowsOf(cell);
    Widget textField(String label, String key) => TextFormField(
          initialValue: cell.props[key]?.toString() ?? '',
          decoration: InputDecoration(labelText: label),
          onChanged: (v) => onChanged({...cell.props, key: v}),
        );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        textField('Key', 'key'),
        const SizedBox(height: 8),
        textField('Title', 'title'),
        Row(children: [
          const Text('Show header'),
          const Spacer(),
          Switch(
            key: const ValueKey('devck-showheader'),
            value: showHeaderOf(cell),
            onChanged: (v) => onChanged({...cell.props, 'showHeader': v}),
          ),
        ]),
        Row(children: [
          Expanded(child: textField('Number label', 'numberLabel')),
          const SizedBox(width: 8),
          Expanded(child: textField('Remark label', 'remarkLabel')),
        ]),
        const SizedBox(height: 8),
        const Text('Device rows', style: TextStyle(fontWeight: FontWeight.bold)),
        for (var i = 0; i < rows.length; i++)
          Row(
            key: ValueKey('devck-row-${rows[i]['key']}'),
            children: [
              Expanded(
                child: TextFormField(
                  key: ValueKey('devck-rowlabel-${rows[i]['key']}'),
                  initialValue: rows[i]['label'] as String? ?? '',
                  decoration:
                      const InputDecoration(isDense: true, hintText: '设备名'),
                  onChanged: (v) {
                    final next = [
                      for (final r in rows) {...r}
                    ];
                    next[i]['label'] = v;
                    onChanged({...cell.props, 'rows': next});
                  },
                ),
              ),
              IconButton(
                key: ValueKey('devck-delrow-${rows[i]['key']}'),
                icon: const Icon(Icons.remove_circle_outline, size: 18),
                onPressed: () {
                  final next = [
                    for (final r in rows) {...r}
                  ]..removeAt(i);
                  onChanged({...cell.props, 'rows': next});
                },
              ),
            ],
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const ValueKey('devck-addrow'),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('加一行'),
            onPressed: () {
              final next = [
                for (final r in rows) {...r}
              ]..add({'label': '', 'key': _freeRowKey(rows)});
              onChanged({...cell.props, 'rows': next});
            },
          ),
        ),
      ],
    );
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/controls/device_checklist_control_test.dart`
Expected: PASS (entire file).

- [ ] **Step 5: Commit**

```bash
cd /Users/xxf/Desktop/scss/grid_app
git add lib/controls/device_checklist_control.dart test/controls/device_checklist_control_test.dart
git commit -m "feat(controls): deviceChecklist previewWidget + propEditor (row list add/del/rename)"
```

---

### Task 7: `editor_ops` 同步纯函数

**Files:**
- Modify: `grid_app/lib/builder/editor_ops.dart`
- Test: `grid_app/test/builder/device_checklist_sync_test.dart`

**Interfaces:**
- Consumes: `ControlRegistry`, `updateCell`, `ControlSpec.reconcile`/`requiredRowSpan`.
- Produces:
  - `Template reconcileCell(Template t, String id, ControlRegistry r)` — replaces cell `id` with `spec.reconcile(cell)` (no-op for controls without an override).
  - `Template syncRowSpan(Template t, String id, ControlRegistry r)` — sets cell `id`'s `rowSpan` to `spec.requiredRowSpan(cell)` when non-null.

- [ ] **Step 1: Write the failing test**

Create `grid_app/test/builder/device_checklist_sync_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/builder/editor_ops.dart';
import 'package:scss_grid/controls/default_controls.dart';
import 'package:scss_grid/controls/device_checklist_control.dart';
import 'package:scss_grid/model/cell.dart';
import 'package:scss_grid/model/grid_frame.dart';
import 'package:scss_grid/model/template.dart';

Template _tpl(List<Cell> cells) => Template(
      id: 't',
      name: 'n',
      page: const PageSize.a4(),
      grid: GridFrame.uniform(
          xMm: 0, yMm: 0, cols: 8, rows: 20, colWidthMm: 20, rowHeightMm: 8),
      cells: cells,
    );

Cell _dc() => Cell(
      id: 'd', col: 0, row: 0, colSpan: 6, rowSpan: 5,
      type: 'deviceChecklist', props: DeviceChecklistControl().defaultProps());

void main() {
  final reg = buildDefaultRegistry();

  test('reconcileCell: after rowSpan grows, rows follow (geometry path)', () {
    final t = _tpl([_dc().copyWith(rowSpan: 7)]);
    final out = reconcileCell(t, 'd', reg);
    final cell = out.cells.single;
    expect(DeviceChecklistControl.rowsOf(cell).length, 6); // 7 - header
  });

  test('syncRowSpan: after rows change, rowSpan follows (property path)', () {
    // start from defaults (4 rows, rowSpan 5), add a 5th row in props
    final rows = DeviceChecklistControl.rowsOf(_dc())
      ..add({'label': '', 'key': 'r5'});
    final t = _tpl([_dc().copyWith(props: {..._dc().props, 'rows': rows})]);
    final out = syncRowSpan(t, 'd', reg);
    expect(out.cells.single.rowSpan, 6); // 5 rows + header
  });

  test('syncRowSpan: leaves controls without requiredRowSpan untouched', () {
    final t = _tpl(const [
      Cell(id: 'n', col: 0, row: 0, type: 'number', props: {'key': 'k'})
    ]);
    expect(syncRowSpan(t, 'n', reg).cells.single.rowSpan, 1);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/builder/device_checklist_sync_test.dart`
Expected: FAIL — `reconcileCell`/`syncRowSpan` undefined.

- [ ] **Step 3: Add the two functions**

In `grid_app/lib/builder/editor_ops.dart`, add the import at the top:

```dart
import '../controls/registry.dart';
```

and append at the end of the file:

```dart
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/builder/device_checklist_sync_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/xxf/Desktop/scss/grid_app
git add lib/builder/editor_ops.dart test/builder/device_checklist_sync_test.dart
git commit -m "feat(builder): reconcileCell/syncRowSpan — generic control geometry sync"
```

---

### Task 8: `builder_screen` 接线(几何 / 属性 / 放置)

**Files:**
- Modify: `grid_app/lib/builder/builder_screen.dart`
- Test: `grid_app/test/builder/device_checklist_sync_test.dart`(加放置初始尺寸的纯函数断言)

**Interfaces:**
- Consumes: `reconcileCell`, `syncRowSpan`, `ControlSpec.requiredRowSpan`/`defaultColSpan`.
- Produces (behaviour): placing a `deviceChecklist` gives `rowSpan == requiredRowSpan` and `colSpan == min(defaultColSpan, freeRunWidth)`; dragging the vertical handle reconciles rows; editing props syncs rowSpan; all gated by `isValid`.

- [ ] **Step 1: Write the failing test (placement helper math)**

Append to `grid_app/test/builder/device_checklist_sync_test.dart`:

```dart
  test('placement initial span: rowSpan=requiredRowSpan, colSpan clamped to free run', () {
    final spec = DeviceChecklistControl();
    // emulate _placeDropped's math on an empty 8-wide grid at (0,0)
    final t = _tpl(const []);
    final free = freeRunWidth(t, 0, 0); // 8
    final wantCol = spec.defaultColSpan() ?? free; // 4
    final colSpan = wantCol < free ? wantCol : free; // 4
    final tmp = Cell(
        id: 'x', col: 0, row: 0, colSpan: colSpan, rowSpan: 1,
        type: 'deviceChecklist', props: spec.defaultProps());
    final rowSpan = spec.requiredRowSpan(tmp) ?? 1; // 5
    expect(colSpan, 4);
    expect(rowSpan, 5);
    final placed = addCell(t, tmp.copyWith(rowSpan: rowSpan));
    expect(isValid(placed), isTrue); // fits in a 20-row grid
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/builder/device_checklist_sync_test.dart -n "placement"`
Expected: FAIL — `freeRunWidth`/`addCell`/`isValid` are imported already; the assertion fails only if math is wrong. (If it passes immediately, that's fine — it pins the contract the wiring must honor; proceed to wire `builder_screen` in Step 3.)

- [ ] **Step 3: Wire the three callbacks**

In `grid_app/lib/builder/builder_screen.dart`:

**(a) Placement** — replace the body of `_placeDropped` and `_addControl` so initial span comes from the spec. Change `_addControl`:

```dart
  void _addControl(ControlSpec spec) {
    final pos = firstFreeCell(_t);
    if (pos == null) return; // grid full
    final free = freeRunWidth(_t, pos.col, pos.row);
    if (free < 1) return;
    _placeAt(spec, pos.col, pos.row, free);
  }
```

Change `_placeDropped`:

```dart
  void _placeDropped(ControlSpec spec, int col, int row) {
    if (cellAtCoord(_t, col, row) != null) return; // occupied
    final free = freeRunWidth(_t, col, row);
    if (free < 1) return;
    _placeAt(spec, col, row, free);
  }
```

Add the shared helper next to them:

```dart
  void _placeAt(ControlSpec spec, int col, int row, int free) {
    final wantCol = spec.defaultColSpan() ?? free;
    final colSpan = wantCol < free ? wantCol : free;
    var cell = _withUniqueKey(Cell(
      id: _newId(spec.type),
      col: col,
      row: row,
      colSpan: colSpan,
      type: spec.type,
      props: spec.defaultProps(),
    ));
    final want = spec.requiredRowSpan(cell);
    if (want != null) cell = cell.copyWith(rowSpan: want);
    final candidate = addCell(_t, cell);
    if (isValid(candidate)) {
      setState(() {
        _t = candidate;
        _selectedId = cell.id;
      });
    }
  }
```

**(b) Geometry path** — in `_canvasArea`, change the `onSpan` callback so a rowSpan change reconciles rows:

```dart
            onSpan: (id, colSpan, rowSpan) => _commit(reconcileCell(
                setSpan(_t, id, colSpan, rowSpan), id, widget.registry)),
```

**(c) Property path** — in the `CellInspector`'s `onPropsChanged`, sync rowSpan after the props update:

```dart
                        onPropsChanged: (props) => _commit(syncRowSpan(
                            updateCell(_t, selected.id,
                                (c) => c.copyWith(props: props)),
                            selected.id,
                            widget.registry)),
```

(No new imports needed — `editor_ops.dart` is already imported; `reconcileCell`/`syncRowSpan` live there.)

- [ ] **Step 4: Run the full suite + analyze**

Run: `flutter test`
Expected: PASS — all existing 173 tests + the new ones.

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
cd /Users/xxf/Desktop/scss/grid_app
git add lib/builder/builder_screen.dart test/builder/device_checklist_sync_test.dart
git commit -m "feat(builder): wire deviceChecklist placement + bidirectional rowSpan↔rows sync"
```

---

### Task 9: 真机验收(SM-A528B)+ 进度更新

**Files:**
- Modify: `doc/PROGRESS.md`(滚动汇总加 Phase 4 一段)
- Modify: memory `scss-project-status.md`(待办推进)

**Interfaces:** none (manual acceptance).

- [ ] **Step 1: Build + install**

```bash
cd /Users/xxf/Desktop/scss/grid_app
flutter build apk --debug
/Users/xxf/Library/Android/sdk/platform-tools/adb -s RZCRA03MZVX install -r build/app/outputs/flutter-apk/app-debug.apk
```

- [ ] **Step 2: Manual acceptance (real device)** — verify against spec §9:
  1. 工具箱出现 Device Checklist;拖入画布 → 默认表头 + 4 空行、三列、整块落在网格上。
  2. 属性面板:改 Title、加/删/改名设备行;**拖纵向手柄增行 与 属性面板加行效果一致**;下方空间不足时该次操作被守卫挡住(控件不变形)。
  3. 填写页:勾选、填数量/备注;退出重进值保留(已存库)。
  4. 导出 PDF:勾选/数量/备注/表格线 与画布一致,整块与相邻字段对齐。
  5. 用真实勘测表 "Type of device to install" 区块走一遍建模→填写→导出。

- [ ] **Step 3: Update progress docs**

Add a Phase 4 line to `doc/PROGRESS.md` "Phase 2 → 3d" rolling summary (rename to "→ 4") and update memory `scss-project-status.md` to mark deviceChecklist done + next step (select/date/checkbox/staticText).

- [ ] **Step 4: Commit**

```bash
cd /Users/xxf/Desktop/scss
git add doc/PROGRESS.md
git commit -m "docs(progress): Phase 4 deviceChecklist 完成(真机验收过)"
```

---

## Self-Review (filled in by plan author)

**1. Spec coverage:** §2 固定三列 → Task 2 defaultProps + Task 4/5 三列渲染。§3.1 不变式/双向同步 → Task 3(reconcile/requiredRowSpan)+ Task 7(纯函数)+ Task 8(接线)。§3.2 列分段 → `nameColsFor`(Task 2)+ Task 4/5 flex。§4.1 props → Task 2。§4.2 填写值 → Task 5(`_set` 嵌套 map)+ Task 4(读取)。§5 三个面 → Task 4/5/6;属性面板设备行清单 → Task 6。§6 架构触点(3 钩子 + 2 纯函数 + 接线 + 注册)→ Task 1/7/8/2。§7 测试策略 → 各 Task 的 TDD 步骤。§9 验收 → Task 9。**无缺口。**

**2. Placeholder scan:** 无 TBD/TODO/占位 token;每个 code step 均含完整可跑代码。Task 4 直接写 `PdfColors.grey` 并注明 `import 'package:pdf/pdf.dart';`。

**3. Type consistency:** 钩子签名 `requiredRowSpan(Cell)→int?` / `reconcile(Cell)→Cell` / `defaultColSpan()→int?` 在 Task 1 定义,Task 3 override、Task 7/8 调用一致。`rowsOf/showHeaderOf/numberColsOf/remarkColsOf/nameColsFor` 在 Task 2 定义,Task 3/4/5/6 一致引用。widget key 命名 `devck-check/number/remark/rowlabel/delrow/addrow/showheader-<rowKey>` 在 Task 5/6 一致。`reconcileCell`/`syncRowSpan(Template,String,ControlRegistry)` 在 Task 7 定义、Task 8 调用一致。**无不一致。**
