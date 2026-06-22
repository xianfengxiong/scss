# Grid-Native Controls — P2a (VB Toolbox Decomposition) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the one-size-fits-all `field` control (label + value + valueType dropdown) with a VB-toolbox set of single-purpose, grid-native controls — `label`, `text`, `number`, `coordinate` (plus the existing `title`) — each occupying whole grid cells with its own property set. This structurally fixes label/value misalignment (a row becomes a `label` cell + a value cell, aligned by the grid) and sets up P2b's collapsed-border work.

**Architecture:** Each control is its own `ControlSpec` file (plugin per type, spec §10.1 + §15). A value control renders ONLY a value box (no embedded label, no `labelCols` flex split); a `label` control renders left/center/right (optionally bold) text. Data keys auto-uniquify on placement (`text_1`, `text_2`, …) and are editable in the inspector. Phase 3a's GPS `_CoordinateField` + `LocationService` injection move from `FieldControl` into a dedicated `CoordinateControl`. New controls are built and unit-tested standalone first (Tasks 1–4, additive, no registry/test breakage), then a single switch task (Task 5) registers them, restructures the sample, deletes `FieldControl`, and updates every test that referenced `field`. Each control keeps a simple `Border.all(0.5)` box for now (the table look); collapsed borders + builder grid rendering are P2b.

**Tech Stack:** Flutter 3.27.2 / Dart 3.6.1. Reuses: `ControlSpec`/`ControlRegistry`, `LocationService`/`CoordinateResult`/`formatCoordinate` (`services/location_service.dart`), `Cell`/`Template`, `cellAtCoord`/`addCell`/`isValid`/`firstFreeCell`/`freeRunWidth` (`builder/editor_ops.dart`), `BuilderScreen`. Removes `FieldControl`.

## Global Constraints

- **Grid-native (spec §15):** controls fill whole cells; positioning/size is `col/row/colSpan/rowSpan`. No internal sub-cell layout (no `labelCols` flex split). A "Label │ value" row is a `label` cell next to a value cell — alignment is structural.
- **One control per type (VB toolbox):** `label`, `text`, `number`, `coordinate` are separate `ControlSpec`s; the `field` control + its `valueType` dropdown are removed. `title` stays.
- **Property set per control (spec §15):** props live in `cell.props` (free map). `label`: `{text, align, bold}`. `text`: `{key, hint}`. `number`: `{key, unit}`. `coordinate`: `{key}`. `title`: `{text, align}` (unchanged).
- **Value controls carry a unique key.** On placement, a value control's `key` is made unique within the template (`text`, then `text_1`, `text_2`, …) and is editable in the inspector. One `data` map keyed by these keys still drives fill + PDF (spec §7).
- **Each control keeps a simple `Border.all(width: 0.5)` box for the table look in P2a.** Collapsed borders (single-width shared edges), per-control span outlines, and empty-only grid lines are **P2b** — do NOT attempt them here.
- **Coordinate GPS is preserved:** `CoordinateControl` reuses Phase 3a's `_CoordinateField` + injected `LocationService?` exactly (📍 capture, SnackBar on failure, plain text when no service).
- Quality gate every code task: from `grid_app/`, `flutter analyze` = `No issues found!` and `flutter test` green.
- Manual simulator pass at the end (Task 6, controller).

---

### Task 0: Start a feature branch

**Files:** none (git only)

- [ ] **Step 1**

```bash
cd /Users/xxf/Desktop/scss
git checkout main && git checkout -b feat/grid-native-controls-p2a
git branch --show-current
```
Expected: `feat/grid-native-controls-p2a`.

---

### Task 1: `LabelControl` (read-only text: align + bold)

**Files:**
- Create: `grid_app/lib/controls/label_control.dart`
- Test: `grid_app/test/controls/label_control_test.dart`

**Interfaces:**
- Consumes: `ControlSpec`, `Cell`.
- Produces: `class LabelControl extends ControlSpec` — `type='label'`, props `{text, align, bold}`, content-only text in a `Border.all(0.5)` box; `dataKey` returns null (no `key` prop); `fillWidget` inherits the read-only default (`previewWidget`); `propEditor` edits text + align + bold.

- [ ] **Step 1: Write the failing test**

Create `grid_app/test/controls/label_control_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/controls/label_control.dart';
import 'package:scss_grid/model/cell.dart';

const _cell = Cell(id: 'l', col: 0, row: 0, colSpan: 3, type: 'label',
    props: {'text': 'Site Name', 'align': 'left', 'bold': true});

Widget _host(Widget child) =>
    MaterialApp(home: Scaffold(body: SizedBox(width: 200, height: 40, child: child)));

void main() {
  test('type, defaultProps, and dataKey (no data key for a label)', () {
    final c = LabelControl();
    expect(c.type, 'label');
    expect(c.defaultProps(), {'text': 'Label', 'align': 'left', 'bold': false});
    expect(c.dataKey(_cell), isNull);
  });

  testWidgets('previewWidget shows the text', (tester) async {
    await tester.pumpWidget(_host(LabelControl().previewWidget(_cell)));
    expect(find.text('Site Name'), findsOneWidget);
  });

  testWidgets('fillWidget is read-only (shows text, no input)', (tester) async {
    await tester.pumpWidget(_host(LabelControl().fillWidget(_cell, null, (_) {})));
    expect(find.text('Site Name'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(TextFormField), findsNothing);
  });

  testWidgets('propEditor edits text, align, and bold', (tester) async {
    var props = <String, dynamic>{...const {'text': 'Site Name', 'align': 'left', 'bold': false}};
    await tester.pumpWidget(_host(
      LabelControl().propEditor(_cell, (p) => props = p),
    ));
    await tester.enterText(find.byType(TextFormField), 'City');
    expect(props['text'], 'City');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd grid_app && flutter test test/controls/label_control_test.dart`
Expected: FAIL (file not found).

- [ ] **Step 3: Write `LabelControl`**

Create `grid_app/lib/controls/label_control.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;

import '../model/cell.dart';
import 'control_spec.dart';

/// A read-only text label that fills its cell. Part of the text-control family
/// (with `title`). Separate from value controls so a "Label │ value" row is two
/// grid-aligned cells (spec §15).
class LabelControl extends ControlSpec {
  @override
  String get type => 'label';
  @override
  String get label => 'Label';
  @override
  IconData get icon => Icons.label_outline;
  @override
  Map<String, dynamic> defaultProps() =>
      {'text': 'Label', 'align': 'left', 'bold': false};

  String _text(Cell c) => (c.props['text'] as String?) ?? '';
  String _alignName(Cell c) => (c.props['align'] as String?) ?? 'left';
  bool _bold(Cell c) => (c.props['bold'] as bool?) ?? false;

  Alignment _align(Cell c) {
    switch (_alignName(c)) {
      case 'center':
        return Alignment.center;
      case 'right':
        return Alignment.centerRight;
      default:
        return Alignment.centerLeft;
    }
  }

  pw.Alignment _pwAlign(Cell c) {
    switch (_alignName(c)) {
      case 'center':
        return pw.Alignment.center;
      case 'right':
        return pw.Alignment.centerRight;
      default:
        return pw.Alignment.centerLeft;
    }
  }

  @override
  pw.Widget paintPdf(Cell cell, Map<String, dynamic> data) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        alignment: _pwAlign(cell),
        decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
        child: pw.Text(_text(cell),
            style: pw.TextStyle(
                fontSize: 9,
                fontWeight:
                    _bold(cell) ? pw.FontWeight.bold : pw.FontWeight.normal)),
      );

  @override
  Widget previewWidget(Cell cell) => Container(
        padding: const EdgeInsets.all(2),
        alignment: _align(cell),
        decoration: BoxDecoration(
            border: Border.all(width: 0.5, color: const Color(0xFFBDBDBD))),
        child: Text(_text(cell),
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 9,
                fontWeight: _bold(cell) ? FontWeight.bold : FontWeight.normal)),
      );

  @override
  Widget propEditor(
      Cell cell, void Function(Map<String, dynamic> props) onChanged) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          initialValue: _text(cell),
          decoration: const InputDecoration(labelText: 'Text'),
          onChanged: (v) => onChanged({...cell.props, 'text': v}),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _alignName(cell),
          decoration: const InputDecoration(labelText: 'Align'),
          items: const ['left', 'center', 'right']
              .map((v) => DropdownMenuItem(value: v, child: Text(v)))
              .toList(),
          onChanged: (v) => onChanged({...cell.props, 'align': v ?? 'left'}),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Bold'),
          value: _bold(cell),
          onChanged: (v) => onChanged({...cell.props, 'bold': v}),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd grid_app && flutter test test/controls/label_control_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Analyze + commit**

```bash
cd /Users/xxf/Desktop/scss/grid_app && flutter analyze
cd /Users/xxf/Desktop/scss && git add -A && git commit -q -m "feat(controls): LabelControl (read-only text: align + bold)"
```
Expected: `No issues found!`, then commit.

---

### Task 2: `TextControl` + `NumberControl` (value inputs)

**Files:**
- Create: `grid_app/lib/controls/text_control.dart`
- Create: `grid_app/lib/controls/number_control.dart`
- Test: `grid_app/test/controls/text_number_control_test.dart`

**Interfaces:**
- Consumes: `ControlSpec`, `Cell`.
- Produces:
  - `class TextControl extends ControlSpec` — `type='text'`, props `{key, hint}`, value box (`Border.all(0.5)`); `previewWidget` shows a grey `[text]` placeholder; `fillWidget` is a `TextFormField` bound to the value; `paintPdf` prints the value string; `dataKey` = `props['key']`; `propEditor` edits `key` (+ `hint`).
  - `class NumberControl extends ControlSpec` — same shape, `type='number'`, numeric keyboard, props `{key, unit}`; PDF/preview append the unit; `propEditor` edits `key` (+ `unit`).

- [ ] **Step 1: Write the failing test**

Create `grid_app/test/controls/text_number_control_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/controls/text_control.dart';
import 'package:scss_grid/controls/number_control.dart';
import 'package:scss_grid/model/cell.dart';

const _textCell = Cell(id: 't', col: 0, row: 0, colSpan: 4, type: 'text',
    props: {'key': 'site_name', 'hint': ''});
const _numCell = Cell(id: 'n', col: 0, row: 0, colSpan: 4, type: 'number',
    props: {'key': 'count', 'unit': 'm'});

Widget _host(Widget child) =>
    MaterialApp(home: Scaffold(body: SizedBox(width: 240, height: 40, child: child)));

void main() {
  test('TextControl: type, defaultProps, dataKey', () {
    final c = TextControl();
    expect(c.type, 'text');
    expect(c.defaultProps(), {'key': 'text', 'hint': ''});
    expect(c.dataKey(_textCell), 'site_name');
  });

  test('NumberControl: type, defaultProps, dataKey', () {
    final c = NumberControl();
    expect(c.type, 'number');
    expect(c.defaultProps(), {'key': 'number', 'unit': ''});
    expect(c.dataKey(_numCell), 'count');
  });

  testWidgets('TextControl fillWidget shows current value and reports edits',
      (tester) async {
    Object? captured;
    await tester.pumpWidget(_host(
      TextControl().fillWidget(_textCell, 'Old', (v) => captured = v),
    ));
    expect(find.text('Old'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'New');
    expect(captured, 'New');
  });

  testWidgets('NumberControl fillWidget uses a numeric keyboard', (tester) async {
    await tester.pumpWidget(_host(
      NumberControl().fillWidget(_numCell, '3', (_) {}),
    ));
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.keyboardType, TextInputType.number);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd grid_app && flutter test test/controls/text_number_control_test.dart`
Expected: FAIL (files not found).

- [ ] **Step 3: Write `TextControl`**

Create `grid_app/lib/controls/text_control.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;

import '../model/cell.dart';
import 'control_spec.dart';

/// A free-text value input that fills its cell. The label, if any, is a separate
/// `label` control beside it (spec §15).
class TextControl extends ControlSpec {
  @override
  String get type => 'text';
  @override
  String get label => 'Text';
  @override
  IconData get icon => Icons.short_text;
  @override
  Map<String, dynamic> defaultProps() => {'key': 'text', 'hint': ''};

  @override
  pw.Widget paintPdf(Cell cell, Map<String, dynamic> data) {
    final value = (data[cell.props['key']] ?? '').toString();
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      alignment: pw.Alignment.centerLeft,
      decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
      child: pw.Text(value, style: const pw.TextStyle(fontSize: 9)),
    );
  }

  @override
  Widget previewWidget(Cell cell) => Container(
        padding: const EdgeInsets.all(2),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
            border: Border.all(width: 0.5, color: const Color(0xFFBDBDBD))),
        child: const Text('[text]',
            style: TextStyle(fontSize: 9, color: Color(0xFF9A9A9A))),
      );

  @override
  Widget fillWidget(
          Cell cell, Object? value, void Function(Object? value) onChanged) =>
      Container(
        decoration: BoxDecoration(
            border: Border.all(width: 0.5, color: const Color(0xFFBDBDBD))),
        child: TextFormField(
          initialValue: value?.toString() ?? '',
          expands: true,
          maxLines: null,
          textAlignVertical: TextAlignVertical.center,
          style: const TextStyle(fontSize: 9),
          decoration: const InputDecoration(
            isDense: true,
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          ),
          onChanged: onChanged,
        ),
      );

  @override
  Widget propEditor(
          Cell cell, void Function(Map<String, dynamic> props) onChanged) =>
      TextFormField(
        initialValue: (cell.props['key'] as String?) ?? '',
        decoration: const InputDecoration(labelText: 'Key'),
        onChanged: (v) => onChanged({...cell.props, 'key': v}),
      );
}
```

- [ ] **Step 4: Write `NumberControl`**

Create `grid_app/lib/controls/number_control.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;

import '../model/cell.dart';
import 'control_spec.dart';

/// A numeric value input that fills its cell. `unit` (e.g. "m") is appended to
/// the value in preview/PDF.
class NumberControl extends ControlSpec {
  @override
  String get type => 'number';
  @override
  String get label => 'Number';
  @override
  IconData get icon => Icons.pin;
  @override
  Map<String, dynamic> defaultProps() => {'key': 'number', 'unit': ''};

  String _unit(Cell c) => (c.props['unit'] as String?) ?? '';

  @override
  pw.Widget paintPdf(Cell cell, Map<String, dynamic> data) {
    final raw = (data[cell.props['key']] ?? '').toString();
    final unit = _unit(cell);
    final text = raw.isEmpty || unit.isEmpty ? raw : '$raw $unit';
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      alignment: pw.Alignment.centerLeft,
      decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 9)),
    );
  }

  @override
  Widget previewWidget(Cell cell) => Container(
        padding: const EdgeInsets.all(2),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
            border: Border.all(width: 0.5, color: const Color(0xFFBDBDBD))),
        child: Text(_unit(cell).isEmpty ? '[number]' : '[number] ${_unit(cell)}',
            style: const TextStyle(fontSize: 9, color: Color(0xFF9A9A9A))),
      );

  @override
  Widget fillWidget(
          Cell cell, Object? value, void Function(Object? value) onChanged) =>
      Container(
        decoration: BoxDecoration(
            border: Border.all(width: 0.5, color: const Color(0xFFBDBDBD))),
        child: TextFormField(
          initialValue: value?.toString() ?? '',
          keyboardType: TextInputType.number,
          expands: true,
          maxLines: null,
          textAlignVertical: TextAlignVertical.center,
          style: const TextStyle(fontSize: 9),
          decoration: const InputDecoration(
            isDense: true,
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          ),
          onChanged: onChanged,
        ),
      );

  @override
  Widget propEditor(
      Cell cell, void Function(Map<String, dynamic> props) onChanged) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          initialValue: (cell.props['key'] as String?) ?? '',
          decoration: const InputDecoration(labelText: 'Key'),
          onChanged: (v) => onChanged({...cell.props, 'key': v}),
        ),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: _unit(cell),
          decoration: const InputDecoration(labelText: 'Unit'),
          onChanged: (v) => onChanged({...cell.props, 'unit': v}),
        ),
      ],
    );
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd grid_app && flutter test test/controls/text_number_control_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 6: Analyze + commit**

```bash
cd /Users/xxf/Desktop/scss/grid_app && flutter analyze
cd /Users/xxf/Desktop/scss && git add -A && git commit -q -m "feat(controls): TextControl + NumberControl (value inputs)"
```
Expected: `No issues found!`, then commit.

---

### Task 3: `CoordinateControl` (GPS value input — moved from FieldControl)

**Files:**
- Create: `grid_app/lib/controls/coordinate_control.dart`
- Test: `grid_app/test/controls/coordinate_control_test.dart`

**Interfaces:**
- Consumes: `ControlSpec`, `Cell`, `LocationService`/`CoordinateResult`/`formatCoordinate` (`services/location_service.dart`).
- Produces: `class CoordinateControl extends ControlSpec` — `type='coordinate'`, props `{key}`, value box; `CoordinateControl({LocationService? location})`; `fillWidget` = a `_CoordinateField` (text + 📍 GPS button) when `location != null`, else a plain `TextFormField`; `paintPdf` prints the value string; `dataKey`=`props['key']`; `propEditor` edits `key`. (This is Phase 3a's coordinate behavior, lifted out of `FieldControl`.)

- [ ] **Step 1: Write the failing test**

Create `grid_app/test/controls/coordinate_control_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/controls/coordinate_control.dart';
import 'package:scss_grid/model/cell.dart';
import 'package:scss_grid/services/location_service.dart';

class _FakeOk implements LocationService {
  @override
  Future<CoordinateResult> getCoordinate() async =>
      CoordinateResult.success(41.1234567, 20.7654321);
}

const _cell = Cell(id: 'c', col: 0, row: 0, colSpan: 6, type: 'coordinate',
    props: {'key': 'site_gps'});

Widget _host(Widget child) =>
    MaterialApp(home: Scaffold(body: SizedBox(width: 360, height: 40, child: child)));

void main() {
  test('type, defaultProps, dataKey', () {
    final c = CoordinateControl();
    expect(c.type, 'coordinate');
    expect(c.defaultProps(), {'key': 'coordinate'});
    expect(c.dataKey(_cell), 'site_gps');
  });

  testWidgets('GPS button fills the value with a formatted coordinate',
      (tester) async {
    Object? captured;
    await tester.pumpWidget(_host(
      CoordinateControl(location: _FakeOk())
          .fillWidget(_cell, null, (v) => captured = v),
    ));
    expect(find.byKey(const ValueKey('gps-capture')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('gps-capture')));
    await tester.pumpAndSettle();
    expect(captured, '41.123457, 20.765432');
  });

  testWidgets('with no LocationService, coordinate is a plain text input',
      (tester) async {
    await tester.pumpWidget(_host(
      CoordinateControl().fillWidget(_cell, 'old', (_) {}),
    ));
    expect(find.byKey(const ValueKey('gps-capture')), findsNothing);
    expect(find.byType(TextFormField), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd grid_app && flutter test test/controls/coordinate_control_test.dart`
Expected: FAIL (file not found).

- [ ] **Step 3: Write `CoordinateControl`**

Create `grid_app/lib/controls/coordinate_control.dart` (the `_CoordinateField` is moved verbatim from `field_control.dart`):
```dart
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;

import '../model/cell.dart';
import '../services/location_service.dart';
import 'control_spec.dart';

/// A GPS coordinate value input. In fill mode, a 📍 button reads the device
/// position and fills "lat, lon" (6 dp); manual entry still works. Behaviour
/// lifted from Phase 3a's FieldControl coordinate branch.
class CoordinateControl extends ControlSpec {
  /// Injected by the registry so fill mode can capture GPS. Null in tests /
  /// non-device contexts → a plain text input.
  final LocationService? location;

  CoordinateControl({this.location});

  @override
  String get type => 'coordinate';
  @override
  String get label => 'Coordinate';
  @override
  IconData get icon => Icons.my_location;
  @override
  Map<String, dynamic> defaultProps() => {'key': 'coordinate'};

  @override
  pw.Widget paintPdf(Cell cell, Map<String, dynamic> data) {
    final value = (data[cell.props['key']] ?? '').toString();
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      alignment: pw.Alignment.centerLeft,
      decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
      child: pw.Text(value, style: const pw.TextStyle(fontSize: 9)),
    );
  }

  @override
  Widget previewWidget(Cell cell) => Container(
        padding: const EdgeInsets.all(2),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
            border: Border.all(width: 0.5, color: const Color(0xFFBDBDBD))),
        child: const Text('[coordinate]',
            style: TextStyle(fontSize: 9, color: Color(0xFF9A9A9A))),
      );

  @override
  Widget fillWidget(
      Cell cell, Object? value, void Function(Object? value) onChanged) {
    if (location == null) {
      return Container(
        decoration: BoxDecoration(
            border: Border.all(width: 0.5, color: const Color(0xFFBDBDBD))),
        child: TextFormField(
          initialValue: value?.toString() ?? '',
          expands: true,
          maxLines: null,
          textAlignVertical: TextAlignVertical.center,
          style: const TextStyle(fontSize: 9),
          decoration: const InputDecoration(
            isDense: true,
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          ),
          onChanged: onChanged,
        ),
      );
    }
    return _CoordinateField(
      location: location!,
      initialValue: value?.toString() ?? '',
      onChanged: onChanged,
    );
  }

  @override
  Widget propEditor(
          Cell cell, void Function(Map<String, dynamic> props) onChanged) =>
      TextFormField(
        initialValue: (cell.props['key'] as String?) ?? '',
        decoration: const InputDecoration(labelText: 'Key'),
        onChanged: (v) => onChanged({...cell.props, 'key': v}),
      );
}

/// Fill-mode value box for a coordinate: a text input plus a GPS button that
/// reads the device position and fills "lat, lon". Manual edits flow through
/// [onChanged].
class _CoordinateField extends StatefulWidget {
  final LocationService location;
  final String initialValue;
  final void Function(Object? value) onChanged;

  const _CoordinateField({
    required this.location,
    required this.initialValue,
    required this.onChanged,
  });

  @override
  State<_CoordinateField> createState() => _CoordinateFieldState();
}

class _CoordinateFieldState extends State<_CoordinateField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialValue);
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    setState(() => _loading = true);
    final r = await widget.location.getCoordinate();
    // widget gone during the GPS call — nothing to update (no rebuild can occur).
    if (!mounted) return;
    setState(() => _loading = false);
    if (r.ok) {
      _controller.text = formatCoordinate(r.lat!, r.lon!);
      widget.onChanged(_controller.text);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(r.error ?? 'GPS capture failed.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          border: Border.all(width: 0.5, color: const Color(0xFFBDBDBD))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              expands: true,
              maxLines: null,
              textAlignVertical: TextAlignVertical.center,
              style: const TextStyle(fontSize: 9),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              ),
              onChanged: widget.onChanged,
            ),
          ),
          IconButton(
            key: const ValueKey('gps-capture'),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            iconSize: 16,
            tooltip: 'Capture GPS',
            onPressed: _loading ? null : _capture,
            icon: _loading
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.my_location),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd grid_app && flutter test test/controls/coordinate_control_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Analyze + commit**

```bash
cd /Users/xxf/Desktop/scss/grid_app && flutter analyze
cd /Users/xxf/Desktop/scss && git add -A && git commit -q -m "feat(controls): CoordinateControl (GPS value input)"
```
Expected: `No issues found!`, then commit.

---

### Task 4: `uniqueKey` helper (no two value controls share a data key)

**Files:**
- Modify: `grid_app/lib/builder/editor_ops.dart`
- Test: `grid_app/test/builder/unique_key_test.dart`

**Interfaces:**
- Consumes: `Template`.
- Produces: `String uniqueKey(Template t, String base)` — returns `base` if no cell already uses it as a `props['key']`, else the first free `${base}_$n` (n from 1).

- [ ] **Step 1: Write the failing test**

Create `grid_app/test/builder/unique_key_test.dart`:
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
  test('returns the base when unused', () {
    expect(uniqueKey(_tpl(const []), 'text'), 'text');
  });

  test('suffixes to avoid collisions', () {
    final t = _tpl(const [
      Cell(id: 'a', col: 0, row: 0, type: 'text', props: {'key': 'text'}),
      Cell(id: 'b', col: 0, row: 1, type: 'text', props: {'key': 'text_1'}),
    ]);
    expect(uniqueKey(t, 'text'), 'text_2');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd grid_app && flutter test test/builder/unique_key_test.dart`
Expected: FAIL (`uniqueKey` not defined).

- [ ] **Step 3: Add `uniqueKey` to `editor_ops.dart`**

Append to `grid_app/lib/builder/editor_ops.dart`:
```dart
/// A data key not already used by any cell in [t]. Returns [base] if free, else
/// the first free `${base}_$n` (n from 1). Used when placing a value control so
/// keys never collide in the survey data map.
String uniqueKey(Template t, String base) {
  final used = t.cells
      .map((c) => c.props['key'])
      .whereType<String>()
      .toSet();
  if (!used.contains(base)) return base;
  var n = 1;
  while (used.contains('${base}_$n')) {
    n++;
  }
  return '${base}_$n';
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd grid_app && flutter test test/builder/unique_key_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
cd /Users/xxf/Desktop/scss && git add -A && git commit -q -m "feat(builder): uniqueKey helper for non-colliding control keys"
```

---

### Task 5: Switch the registry + sample to the new controls; remove `FieldControl`; update all tests

**Files:**
- Modify: `grid_app/lib/controls/default_controls.dart` (register the new set)
- Delete: `grid_app/lib/controls/field_control.dart`
- Modify: `grid_app/lib/sample/sample_template.dart` (title + label/value rows)
- Modify: `grid_app/lib/builder/builder_screen.dart` (apply `uniqueKey` on add/drop)
- Modify (sweep): every test referencing `FieldControl` or a `type: 'field'` cell — see the list in Step 5.

**Interfaces:**
- Consumes: `LabelControl`, `TextControl`, `NumberControl`, `CoordinateControl`, `TitleControl`, `uniqueKey`.
- Produces: `buildDefaultRegistry({LocationService? location})` registers `{title, label, text, number, coordinate}`; `FieldControl` no longer exists; the sample is title + label/value rows; new value controls get unique keys on placement.

- [ ] **Step 1: Rewrite `buildDefaultRegistry`**

Replace the whole `grid_app/lib/controls/default_controls.dart` with:
```dart
import '../services/location_service.dart';
import 'coordinate_control.dart';
import 'label_control.dart';
import 'number_control.dart';
import 'registry.dart';
import 'text_control.dart';
import 'title_control.dart';

/// The app's VB-toolbox control set. Add a new control by registering it here
/// (spec §10.1, §15). [location] is injected so a `coordinate` control can
/// capture GPS; tests that omit it get a text-only coordinate input.
ControlRegistry buildDefaultRegistry({LocationService? location}) {
  final r = ControlRegistry();
  r.register(TitleControl());
  r.register(LabelControl());
  r.register(TextControl());
  r.register(NumberControl());
  r.register(CoordinateControl(location: location));
  return r;
}
```

- [ ] **Step 2: Delete `FieldControl`**

```bash
git rm grid_app/lib/controls/field_control.dart
```

- [ ] **Step 3: Restructure the sample template**

Replace the `cells:` list in `grid_app/lib/sample/sample_template.dart` so a label and a value are SEPARATE cells (keep the `Template`/`grid` wrapper and the file's doc comment; just change the cells):
```dart
      cells: const [
        Cell(id: 'title', col: 0, row: 0, colSpan: 12, type: 'title',
            props: {'text': 'Site Survey Form', 'align': 'center'}),
        Cell(id: 'name_l', col: 0, row: 1, colSpan: 3, type: 'label',
            props: {'text': 'Site Name', 'align': 'left', 'bold': false}),
        Cell(id: 'name_v', col: 3, row: 1, colSpan: 9, type: 'text',
            props: {'key': 'site_name', 'hint': ''}),
        Cell(id: 'city_l', col: 0, row: 2, colSpan: 3, type: 'label',
            props: {'text': 'Site City', 'align': 'left', 'bold': false}),
        Cell(id: 'city_v', col: 3, row: 2, colSpan: 9, type: 'text',
            props: {'key': 'site_city', 'hint': ''}),
      ],
```

- [ ] **Step 4: Apply `uniqueKey` when placing a value control in `BuilderScreen`**

In `grid_app/lib/builder/builder_screen.dart`, both `_addControl` and `_placeDropped` build a `Cell` from `spec.defaultProps()`. After building each cell, if it carries a data key, replace it with a unique one. Add a small private helper and use it in BOTH methods:
```dart
  // Give a value control a key that doesn't collide with existing cells.
  Cell _withUniqueKey(Cell c) {
    final key = c.props['key'];
    if (key is! String) return c;
    return c.copyWith(props: {...c.props, 'key': uniqueKey(_t, key)});
  }
```
Then in `_addControl`, change:
```dart
    final cell = Cell(
      id: _newId(spec.type),
      col: pos.col,
      row: pos.row,
      colSpan: span,
      type: spec.type,
      props: spec.defaultProps(),
    );
    final candidate = addCell(_t, cell);
```
to:
```dart
    final cell = _withUniqueKey(Cell(
      id: _newId(spec.type),
      col: pos.col,
      row: pos.row,
      colSpan: span,
      type: spec.type,
      props: spec.defaultProps(),
    ));
    final candidate = addCell(_t, cell);
```
and in `_placeDropped`, change:
```dart
    final cell = Cell(
      id: _newId(spec.type),
      col: col,
      row: row,
      colSpan: span,
      type: spec.type,
      props: spec.defaultProps(),
    );
    final candidate = addCell(_t, cell);
```
to:
```dart
    final cell = _withUniqueKey(Cell(
      id: _newId(spec.type),
      col: col,
      row: row,
      colSpan: span,
      type: spec.type,
      props: spec.defaultProps(),
    ));
    final candidate = addCell(_t, cell);
```

- [ ] **Step 5: Sweep the tests off `field`**

`FieldControl` and `type: 'field'` no longer exist. Run `flutter test` once to get the failing list, then update each. The mechanical mapping:
- `FieldControl()` → the right new control: a `valueType: 'text'`/absent field → `TextControl()`; `valueType: 'coordinate'` → `CoordinateControl()` (pass `location:` where the old test passed it to `FieldControl`).
- A `Cell(type: 'field', props: {'label': L, 'key': K, 'valueType': 'text'})` that tested the **value/input** → `Cell(type: 'text', props: {'key': K, 'hint': ''})`; if the test also asserted the **label**, add a separate `Cell(type: 'label', props: {'text': L, 'align': 'left', 'bold': false})` or assert against a `LabelControl`.
- `valueType: 'coordinate'` field → `Cell(type: 'coordinate', props: {'key': K})`.
- Tests that did `find.text('Field')` (the palette item) → the new palette has `Label`/`Text`/`Number`/`Coordinate`; use the one the test means (usually `find.text('Text')`).

Known files to update (grep `FieldControl` and `'field'` to confirm the full set):
- `test/controls/fill_widget_test.dart` (FieldControl fillWidget/dataKey) → split into TextControl + TitleControl/LabelControl cases, or delete if now covered by `text_number_control_test.dart` + `label_control_test.dart`.
- `test/controls/coordinate_fill_test.dart` → `CoordinateControl` + `type: 'coordinate'` (this duplicates `coordinate_control_test.dart` — delete it or convert).
- `test/controls/preview_widget_test.dart` (FieldControl preview) → `TextControl`/`LabelControl`.
- `test/controls/prop_editor_test.dart` (FieldControl propEditor label) → `LabelControl` (text) and/or `TextControl` (key).
- `test/controls/default_controls_test.dart` → assert the new registry set `{title,label,text,number,coordinate}`.
- `test/builder/builder_screen_test.dart`, `test/builder/add_control_placement_test.dart`, `test/builder/palette_drag_test.dart`, `test/builder/cell_inspector_refresh_test.dart`, `test/builder/grid_canvas_*_test.dart`, `test/builder/editable_canvas_test.dart` → any `type: 'field'` cell → `type: 'text'` (value) or `type: 'label'`; any `find.text('Field')` → `find.text('Text')`.
- `test/builder/cell_inspector_test.dart` → if it builds a FieldControl/`field` cell, use `LabelControl`/`text`.
- `test/fill/fill_canvas_test.dart`, `test/fill/fill_screen_test.dart` → `type: 'field'` value cells → `type: 'text'`; if they assert a label, add a `label` cell.
- `test/integration/build_to_pdf_test.dart`, `test/integration/fill_to_pdf_test.dart`, `test/pdf/template_pdf_test.dart` → these use `sampleTemplate()`; the new sample uses `site_name`/`site_city` keys on `text` cells, so the `data` maps (`{'site_name': ..., 'site_city': ...}`) still apply unchanged — just confirm they pass.
- `test/builder/grid_canvas_golden_test.dart` → the golden image will change (new sample + label/text rendering). Regenerate it: `flutter test --update-goldens test/builder/grid_canvas_golden_test.dart`, then re-run normally.

- [ ] **Step 6: Run the FULL suite + analyze until green**

Run: `cd grid_app && flutter analyze && flutter test`
Expected: `No issues found!` and ALL tests green. Iterate on the sweep (Step 5) until the suite is green. The PDF/fill data-flow is unchanged (value keyed by `props['key']`), so only test fixtures using `'field'` need touching.

- [ ] **Step 7: Commit**

```bash
cd /Users/xxf/Desktop/scss && git add -A && git commit -q -m "feat(controls): switch to VB-toolbox controls; remove FieldControl; restructure sample"
```

---

### Task 6: Manual simulator pass (controller, not a subagent)

**Files:** none

- [ ] **Step 1: Run on the emulator and verify the toolbox by observation**

```bash
flutter emulators --launch Medium_Phone_API_35
cd /Users/xxf/Desktop/scss/grid_app && flutter run -d emulator-5554
```
Verify and report what you see:
1. New template → the palette now shows **Title, Label, Text, Number, Coordinate** (VB toolbox). The sample renders a centered title + two rows, each a **Label cell** beside a **Text cell** — and the label/value dividers line up across both rows (grid-aligned, no more ragged split).
2. Place a **Label** (e.g. cols 0–2) and a **Text** beside it (cols 3–11) on a new row → they align with the rows above.
3. Add two **Text** controls → their inspector **Key** fields show distinct auto keys (`text`, then `text_1`).
4. Select a Label → inspector shows **Text / Align / Bold**; toggle Bold/Align → the canvas updates. Select a Text → inspector shows **Key**.
5. Fill the template → a **Coordinate** control still shows the 📍 button and captures GPS (set a mock location via `adb emu geo fix <lon> <lat>`); Export PDF shows the values.

If anything misbehaves, report DONE_WITH_CONCERNS with specifics. NOTE (expected, P2b): adjacent control borders are double-thick at shared edges, Title has no border, and faint grid lines still show through controls — those are fixed in P2b, not here.

---

## P2a — Definition of Done

- The palette is a VB toolbox: `title`, `label`, `text`, `number`, `coordinate`, each a single-purpose grid-native control with its own property set; `field` + its `valueType` dropdown are gone.
- A "Label │ value" row is a `label` cell beside a value cell, aligned by the grid — the old per-field label/value misalignment is structurally eliminated.
- Value controls get auto-unique data keys on placement, editable in the inspector; the one `data` map (keyed by those keys) still drives fill + PDF.
- Coordinate GPS capture is preserved (📍 button + `LocationService`), now in its own control.
- `flutter analyze` = 0; `flutter test` all green; manual simulator pass confirms the toolbox, alignment, unique keys, per-control properties, and GPS.
- Explicitly deferred to **P2b**: collapsed (single-width) shared borders, a solid span outline on every control (incl. title), and suppressing the faint grid lines inside occupied cells.

## Self-Review (against spec §15)

**Coverage:**
- §15 "废弃 field + valueType,拆为独立控件 label/text/number/coordinate" → Tasks 1–3 + Task 5 (remove field, register set). ✓
- §15 "label 与 value 不再绑定 → 一行=label 格+value 格,对齐由网格保证" → Task 5 sample restructure. ✓
- §15 "检视器=VB 属性面板,每控件自己的属性集" → each control's `propEditor` (label: text/align/bold; text: key; number: key/unit; coordinate: key). ✓
- §15 "输入控件 key 自动唯一 + 可改" → Task 4 (`uniqueKey`) + Task 5 (apply on add/drop) + value controls' `propEditor` key field. ✓
- §15 coordinate "搬 Phase 3a 的 _CoordinateField + LocationService" → Task 3. ✓
- §7 "一份 data 驱动 fill+PDF" → value keyed by `props['key']`; `paintPdf` reads `data[key]` (unchanged). ✓
- Deferred (P2b, explicitly): border collapse, per-control outline, empty-only grid lines. ✓

**Placeholder scan:** New control code is complete in Tasks 1–4. Task 5 is a mechanical sweep with an exact mapping + file list + the green-suite gate (the only task whose per-file test diffs aren't pre-written, because they are a rename-style refactor driven by the compiler/test failures). Task 6 is explicit manual observation.

**Type consistency:** `LabelControl`/`TextControl`/`NumberControl`/`CoordinateControl({location})`, `uniqueKey(Template, String)`, `buildDefaultRegistry({location})` registering the five controls, and the `coordinate` `ValueKey('gps-capture')` / `formatCoordinate` reuse are consistent across Tasks 1–5 and the tests.
