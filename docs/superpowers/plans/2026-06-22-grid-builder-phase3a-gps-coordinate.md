# Grid Template Builder — Phase 3a (GPS Coordinate Field) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make a `field` of `valueType: coordinate` capture the device GPS in fill mode — a "📍" button reads the current position and fills the value as `"lat, lon"` (6 dp), which the existing PDF path already prints. This is the first slice of Phase 3 (field capabilities) and de-risks adding a real Android device plugin to the new app.

**Architecture:** Add the `geolocator` plugin (pinned to ^13.0.0 — 14.x breaks on Flutter 3.27) plus the two Android location permissions. A new `LocationService` abstraction (with a `CoordinateResult` value type and a `formatCoordinate` helper) wraps geolocator's permission+position flow (ported from the old app's `location_service.dart`); the real `GeolocatorLocationService` is device-only, and a fake drives tests. `FieldControl` gains an injected `LocationService?`; when a coordinate field is filled and a service is present, its value box becomes a small text field + a GPS button. `buildDefaultRegistry({location})` wires the real service in `main.dart`; existing callers that pass no service keep the plain text input (backward compatible). No data-model, persistence, or PDF changes — a coordinate is just a string in the survey `data` map, exactly as today.

**Tech Stack:** Flutter 3.27.2 / Dart 3.6.1. New dep: `geolocator: ^13.0.0` (+ `geolocator_android` 4.6.x). Reuses Phase 2: `ControlSpec`/`FieldControl.fillWidget`, `buildDefaultRegistry`, `FillCanvas`/`FillScreen`, `renderTemplate` (FieldControl.paintPdf already prints `data[key]`). Ports `/Users/xxf/Desktop/scss/app/lib/services/location_service.dart`.

## Global Constraints

- **geolocator is pinned to `^13.0.0`.** Do NOT use 14.x: its `geolocator_android` 5.0.3 calls `Color.toARGB32()`, which does not exist in Flutter 3.27's SDK (per `app/BUILD_NOTES.md`). 13.x exposes the same Dart API (`LocationSettings`, `getCurrentPosition`, `checkPermission`, `requestPermission`).
- **No `permission_handler`.** geolocator owns its permission flow (`checkPermission` / `requestPermission`), exactly as the old app.
- **Coordinate value format:** `"${lat.toStringAsFixed(6)}, ${lon.toStringAsFixed(6)}"` — 6 decimal places, comma-space separator (matches the old app's `site_detail_screen.dart:128`). No accuracy appended to the field value.
- **Backward compatibility:** `FieldControl`'s new `location` is optional; `buildDefaultRegistry()` with no arg yields `location: null`, and a coordinate field with no service renders the plain Phase-2 text input. Every existing test that calls `buildDefaultRegistry()` must still pass unchanged.
- **Plugin-generic:** no `switch (cell.type)` outside a `ControlSpec`. The coordinate branch lives inside `FieldControl` (keyed off its own `valueType` prop), not in canvas/fill/screen code.
- **Android:** add only `ACCESS_FINE_LOCATION` + `ACCESS_COARSE_LOCATION` (GPS needs no INTERNET). Set `minSdk = 23` (the old app's proven floor for these plugins). Do NOT add a `resolutionStrategy` block or bump Kotlin — those were for `share_plus`/`connectivity_plus`, not geolocator.
- Quality gate every code task: from `grid_app/`, `flutter analyze` = `No issues found!` and `flutter test` all green. Task 1 additionally requires a successful `flutter build apk --debug`.
- Manual simulator pass at the end (Task 4, controller) — real GPS capture + permission prompt needs a device.

---

### Task 0: Start a feature branch

**Files:** none (git only)

- [ ] **Step 1**

```bash
cd /Users/xxf/Desktop/scss
git checkout main && git checkout -b feat/grid-builder-phase3a-gps-coordinate
git branch --show-current
```
Expected: `feat/grid-builder-phase3a-gps-coordinate`.

---

### Task 1: Add geolocator + Android location permissions (and prove it builds)

**Files:**
- Modify: `grid_app/pubspec.yaml` (add `geolocator: ^13.0.0`)
- Modify: `grid_app/android/app/src/main/AndroidManifest.xml` (2 permissions)
- Modify: `grid_app/android/app/build.gradle` (`minSdk = 23`)

**Interfaces:**
- Consumes: nothing.
- Produces: the `geolocator` package is resolvable and the Android app builds with location permissions declared. No Dart symbols yet.

- [ ] **Step 1: Add the dependency**

In `grid_app/pubspec.yaml`, under `dependencies:` (after `printing:`), add:
```yaml
  geolocator: ^13.0.0 # pinned: 14.x's geolocator_android calls Color.toARGB32() (absent in Flutter 3.27)
```

- [ ] **Step 2: Resolve it**

Run: `cd grid_app && flutter pub get`
Expected: resolves `geolocator 13.x` + `geolocator_android 4.6.x`. No version-solve errors.

- [ ] **Step 3: Declare the Android permissions**

In `grid_app/android/app/src/main/AndroidManifest.xml`, add these two lines as direct children of `<manifest>` (e.g. immediately before the `<application>` tag):
```xml
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
```

- [ ] **Step 4: Set the minSdk floor**

In `grid_app/android/app/build.gradle`, inside `defaultConfig`, replace:
```groovy
        minSdk = flutter.minSdkVersion
```
with:
```groovy
        minSdk = 23 // geolocator/device plugins floor (matches the old app)
```

- [ ] **Step 5: Prove the Android build resolves the plugin**

Run: `cd grid_app && flutter analyze && flutter build apk --debug`
Expected: `No issues found!` and `✓ Built build/app/outputs/flutter-apk/app-debug.apk`. (This is the real de-risking check — it exercises the geolocator Android toolchain.)
If the build fails on an AGP/Kotlin/SDK error, STOP and report BLOCKED with the exact error — do NOT bump Kotlin/AGP or add a resolutionStrategy without escalating.

- [ ] **Step 6: Confirm existing tests still pass**

Run: `cd grid_app && flutter test`
Expected: all existing tests green (the dependency is added but unused).

- [ ] **Step 7: Commit**

```bash
cd /Users/xxf/Desktop/scss && git add -A && git commit -q -m "build(android): add geolocator ^13 + location permissions + minSdk 23"
```

---

### Task 2: `LocationService` + `CoordinateResult` (+ geolocator impl)

**Files:**
- Create: `grid_app/lib/services/location_service.dart`
- Test: `grid_app/test/services/location_service_test.dart`

**Interfaces:**
- Consumes: `geolocator` (`package:geolocator/geolocator.dart`).
- Produces:
  ```dart
  class CoordinateResult {
    final double? lat;
    final double? lon;
    final double? accuracy;
    final String? error;
    const CoordinateResult._(...);
    factory CoordinateResult.success(double lat, double lon, {double? accuracy});
    factory CoordinateResult.failure(String message);
    bool get ok;            // error == null && lat != null && lon != null
  }
  String formatCoordinate(double lat, double lon); // "12.345678, 98.765432"
  abstract class LocationService { Future<CoordinateResult> getCoordinate(); }
  class GeolocatorLocationService implements LocationService { ... } // device-only
  ```

- [ ] **Step 1: Write the failing test**

Create `grid_app/test/services/location_service_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/services/location_service.dart';

void main() {
  test('formatCoordinate uses 6 dp and a comma-space separator', () {
    expect(formatCoordinate(41.1234567, 20.1), '41.123457, 20.100000');
  });

  test('CoordinateResult.success is ok and carries the coordinate', () {
    final r = CoordinateResult.success(41.1, 20.2, accuracy: 8);
    expect(r.ok, isTrue);
    expect([r.lat, r.lon, r.accuracy], [41.1, 20.2, 8]);
    expect(r.error, isNull);
  });

  test('CoordinateResult.failure is not ok and carries the message', () {
    final r = CoordinateResult.failure('Location permission denied.');
    expect(r.ok, isFalse);
    expect(r.error, 'Location permission denied.');
    expect(r.lat, isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd grid_app && flutter test test/services/location_service_test.dart`
Expected: FAIL (file not found).

- [ ] **Step 3: Write the implementation**

Create `grid_app/lib/services/location_service.dart`:
```dart
import 'package:geolocator/geolocator.dart';

/// A GPS read: either a coordinate (`ok`) or an error message.
class CoordinateResult {
  final double? lat;
  final double? lon;
  final double? accuracy;
  final String? error;

  const CoordinateResult._({this.lat, this.lon, this.accuracy, this.error});

  factory CoordinateResult.success(double lat, double lon, {double? accuracy}) =>
      CoordinateResult._(lat: lat, lon: lon, accuracy: accuracy);

  factory CoordinateResult.failure(String message) =>
      CoordinateResult._(error: message);

  bool get ok => error == null && lat != null && lon != null;
}

/// Field value format for a coordinate: "lat, lon" at 6 decimal places
/// (matches the old app, so PDFs read identically).
String formatCoordinate(double lat, double lon) =>
    '${lat.toStringAsFixed(6)}, ${lon.toStringAsFixed(6)}';

/// Reads the device's current position. Abstracted so controls can be tested
/// with a fake (the geolocator impl is device-only).
abstract class LocationService {
  Future<CoordinateResult> getCoordinate();
}

/// Real implementation over `geolocator` (ported from the old app's
/// LocationService). Owns its permission flow — no permission_handler.
class GeolocatorLocationService implements LocationService {
  @override
  Future<CoordinateResult> getCoordinate() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return CoordinateResult.failure('Location services are disabled.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      return CoordinateResult.failure('Location permission denied.');
    }
    if (permission == LocationPermission.deniedForever) {
      return CoordinateResult.failure(
          'Location permission permanently denied.');
    }

    final pos = await Geolocator.getCurrentPosition(
      locationSettings:
          const LocationSettings(accuracy: LocationAccuracy.high),
    );
    return CoordinateResult.success(pos.latitude, pos.longitude,
        accuracy: pos.accuracy);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd grid_app && flutter test test/services/location_service_test.dart`
Expected: PASS (3 tests). `GeolocatorLocationService` is not unit-tested — it only forwards to geolocator's static API and is verified on-device in Task 4.

- [ ] **Step 5: Analyze + commit**

```bash
cd /Users/xxf/Desktop/scss/grid_app && flutter analyze
cd /Users/xxf/Desktop/scss && git add -A && git commit -q -m "feat(services): LocationService + CoordinateResult + geolocator impl"
```
Expected: `No issues found!`, then commit.

---

### Task 3: Coordinate capture in `FieldControl` (+ registry/main wiring)

**Files:**
- Modify: `grid_app/lib/controls/field_control.dart` (inject `LocationService?`; coordinate fill widget)
- Modify: `grid_app/lib/controls/default_controls.dart` (`buildDefaultRegistry({location})`)
- Modify: `grid_app/lib/main.dart` (pass `GeolocatorLocationService()`)
- Test: `grid_app/test/controls/coordinate_fill_test.dart`

**Interfaces:**
- Consumes: `LocationService`, `CoordinateResult`, `formatCoordinate` (Task 2); `FieldControl.fillWidget` / `_labelValueSplit` (existing).
- Produces:
  - `FieldControl({LocationService? location})` — stores `location`.
  - When `valueType == 'coordinate'` and `location != null`, `fillWidget`'s value box is a `_CoordinateField` (private StatefulWidget): a text field + a GPS `IconButton` keyed `ValueKey('gps-capture')`. Tap → spinner → `location.getCoordinate()`; on `ok` set the text to `formatCoordinate(lat,lon)` and call `onChanged`; on failure show a `SnackBar`. Manual edits still call `onChanged`.
  - `ControlRegistry buildDefaultRegistry({LocationService? location})` — passes `location` to `FieldControl`.

- [ ] **Step 1: Write the failing test**

Create `grid_app/test/controls/coordinate_fill_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/controls/field_control.dart';
import 'package:scss_grid/model/cell.dart';
import 'package:scss_grid/services/location_service.dart';

class _FakeOk implements LocationService {
  @override
  Future<CoordinateResult> getCoordinate() async =>
      CoordinateResult.success(41.1234567, 20.7654321);
}

class _FakeFail implements LocationService {
  @override
  Future<CoordinateResult> getCoordinate() async =>
      CoordinateResult.failure('Location permission denied.');
}

const _coordCell = Cell(id: 'c', col: 0, row: 0, colSpan: 6, type: 'field',
    props: {'label': 'GPS', 'key': 'site_gps', 'valueType': 'coordinate',
        'labelCols': 2});

Widget _host(Widget child) =>
    MaterialApp(home: Scaffold(body: SizedBox(width: 360, height: 80, child: child)));

void main() {
  testWidgets('GPS button fills the value with a formatted coordinate',
      (tester) async {
    Object? captured;
    await tester.pumpWidget(_host(
      FieldControl(location: _FakeOk())
          .fillWidget(_coordCell, null, (v) => captured = v),
    ));
    expect(find.byKey(const ValueKey('gps-capture')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('gps-capture')));
    await tester.pumpAndSettle();
    expect(captured, '41.123457, 20.765432');
    expect(find.text('41.123457, 20.765432'), findsOneWidget);
  });

  testWidgets('GPS failure shows a SnackBar and does not fill the value',
      (tester) async {
    Object? captured;
    await tester.pumpWidget(_host(
      FieldControl(location: _FakeFail())
          .fillWidget(_coordCell, null, (v) => captured = v),
    ));
    await tester.tap(find.byKey(const ValueKey('gps-capture')));
    await tester.pumpAndSettle();
    expect(find.text('Location permission denied.'), findsOneWidget);
    expect(captured, isNull);
  });

  testWidgets('with no LocationService, a coordinate field is a plain text input',
      (tester) async {
    await tester.pumpWidget(_host(
      FieldControl().fillWidget(_coordCell, 'old', (_) {}),
    ));
    expect(find.byKey(const ValueKey('gps-capture')), findsNothing);
    expect(find.byType(TextFormField), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd grid_app && flutter test test/controls/coordinate_fill_test.dart`
Expected: FAIL (`FieldControl` has no `location` param / no `gps-capture` button).

- [ ] **Step 3: Add the `location` field + coordinate branch to `FieldControl`**

In `grid_app/lib/controls/field_control.dart`:

1. Add the import at the top (after `import 'control_spec.dart';`):
```dart
import '../services/location_service.dart';
```

2. Give `FieldControl` a constructor with the injected service. Replace the class header line:
```dart
class FieldControl extends ControlSpec {
```
with:
```dart
class FieldControl extends ControlSpec {
  /// Injected by the registry so a `coordinate` field can capture GPS in fill
  /// mode. Null in tests / non-device contexts → coordinate fields stay text.
  final LocationService? location;

  FieldControl({this.location});
```

3. In `fillWidget`, branch to the coordinate input. Replace the `inputBox` local and the final `return` (the block from `final inputBox = Container(` through the closing `);` of the returned `Row`) with:
```dart
    final Widget inputBox;
    if (valueType == 'coordinate' && location != null) {
      inputBox = _CoordinateField(
        location: location!,
        initialValue: value?.toString() ?? '',
        onChanged: onChanged,
      );
    } else {
      inputBox = Container(
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
          onChanged: onChanged,
        ),
      );
    }

    return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(flex: labelCols, child: labelBox),
      Expanded(flex: valueCols, child: inputBox),
    ]);
```

4. Add the `_CoordinateField` widget at the END of the file (after the `FieldControl` class closing brace):
```dart
/// Fill-mode value box for a `coordinate` field: a text input plus a GPS button
/// that reads the device position and fills "lat, lon". Manual edits still flow
/// through [onChanged].
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

- [ ] **Step 4: Run the control test to verify it passes**

Run: `cd grid_app && flutter test test/controls/coordinate_fill_test.dart`
Expected: PASS (fill, failure SnackBar, no-service text fallback).

- [ ] **Step 5: Wire the service through the registry and main**

In `grid_app/lib/controls/default_controls.dart`, replace the whole `buildDefaultRegistry` with:
```dart
import '../services/location_service.dart';
import 'field_control.dart';
import 'registry.dart';
import 'title_control.dart';

/// The app's starting control set. Add new controls by registering them here.
/// [location] is injected so a `coordinate` field can capture GPS; tests that
/// omit it get text-only coordinate fields.
ControlRegistry buildDefaultRegistry({LocationService? location}) {
  final r = ControlRegistry();
  r.register(TitleControl());
  r.register(FieldControl(location: location));
  return r;
}
```

In `grid_app/lib/main.dart`:
1. Add the import (with the others):
```dart
import 'services/location_service.dart';
```
2. Pass the real service. Change:
```dart
  runApp(ScssGridApp(
    store: DriftTemplateStore(db),
    surveyStore: DriftSurveyStore(db),
    registry: buildDefaultRegistry(),
  ));
```
to:
```dart
  runApp(ScssGridApp(
    store: DriftTemplateStore(db),
    surveyStore: DriftSurveyStore(db),
    registry: buildDefaultRegistry(location: GeolocatorLocationService()),
  ));
```

- [ ] **Step 6: Run the FULL suite + analyze**

Run: `cd grid_app && flutter analyze && flutter test`
Expected: `No issues found!` and ALL tests green — the existing tests call `buildDefaultRegistry()` with no `location`, so coordinate fields stay text and nothing regresses.

- [ ] **Step 7: Commit**

```bash
cd /Users/xxf/Desktop/scss && git add -A && git commit -q -m "feat(controls): GPS capture for coordinate fields (FieldControl + registry/main wiring)"
```

---

### Task 4: Manual simulator pass (controller, not a subagent)

**Files:** none

- [ ] **Step 1: Run on the emulator and verify GPS capture by observation**

```bash
flutter emulators --launch Medium_Phone_API_35
cd /Users/xxf/Desktop/scss/grid_app && flutter run -d emulator-5554
```
Verify and report what you see:
1. Open a template in the builder, add a `Field`, set its **Value type → coordinate**, give it a label/key, Save, go back.
2. Tap the template's **Fill** button → the coordinate field shows a small text box with a **📍 (my_location)** button on its right.
3. Tap 📍 → Android's location-permission prompt appears (first time) → grant it → the field fills with `"lat, lon"` (6 dp). (On the emulator, set a location via the emulator's Extended Controls → Location if needed.)
4. Tap **Export** → the PDF shows the captured coordinate string in that field's cell.
5. Tap **Save** → reopen the survey from **Surveys** → the coordinate value persisted.
6. (Negative) Deny the permission → a SnackBar shows the error and the field stays empty.

If GPS capture or the permission prompt misbehaves, report DONE_WITH_CONCERNS with specifics.

---

## Phase 3a — Definition of Done

- A `field` with `valueType: coordinate` captures the device GPS in fill mode via a 📍 button and fills `"lat, lon"` (6 dp); manual entry still works; failure surfaces a SnackBar.
- The captured value persists in the survey `data` map and prints in the exported PDF unchanged (no PDF/model/persistence code changed).
- `geolocator ^13` builds on the new app's Android toolchain (`flutter build apk --debug` succeeds) with only the two location permissions + `minSdk 23`; no Kotlin/AGP/resolutionStrategy changes.
- Coordinate capture is control-local (inside `FieldControl`), service-injected (testable with a fake), and backward compatible (no service → plain text).
- `flutter analyze` = 0; `flutter test` all green; manual simulator pass confirms real GPS + permission.
- Deferred to later Phase 3 slices: `image` (3b), `multiImage` (3c), `satelliteDiagram` map pin+snapshot (3d); richer `select`/`date` inputs (Phase 4).

## Self-Review (against spec)

**Spec coverage (Phase 3 slice = spec §12.3 "现场能力" → GPS field; §6 `field` valueType `coordinate` "取 GPS"):**
- §6 `field` `coordinate` "取 GPS" in fill mode → Task 3 (`_CoordinateField` + 📍 button). ✓
- §8 "复用可靠底层 — GPS:geolocator" → Task 2 ports the old `location_service.dart` flow. ✓
- §7 one model drives fill + PDF → coordinate is a string in `data[key]`; `FieldControl.paintPdf` already prints it (no change). ✓
- §10.1 plugin-generic → coordinate branch lives in `FieldControl`, no external `switch`. ✓
- Pinned-version discipline (`app/BUILD_NOTES.md`) → Task 1 pins geolocator ^13, minSdk 23, no Kotlin/AGP bump. ✓

**Placeholder scan:** No TBD/TODO; every code step has complete code. Task 4 is an explicit manual-observation step. `GeolocatorLocationService` being device-only (not unit-tested) is a stated, justified decision, not a gap.

**Type consistency:** `CoordinateResult.success/failure`/`ok`, `formatCoordinate(double,double)`, `LocationService.getCoordinate()→Future<CoordinateResult>`, `FieldControl({LocationService? location})`, `buildDefaultRegistry({LocationService? location})`, and the `ValueKey('gps-capture')` button key are consistent across Tasks 2–4 and the tests.
