# Phase 3b (Image Single-Photo Control) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an `image` control: in fill mode, tap to capture a photo (camera or gallery), which is compressed and stored on the device; the filled value is the image's file path; the control shows the photo with a clear (✕) button to retake; and the exported PDF embeds the photo. Resumes Phase 3 (field capabilities) on top of the P2 grid-native control model.

**Architecture:** Reuses the old app's proven IO (`image_picker` + `flutter_image_compress`, store a compressed `.jpg` under the app documents dir, keep only the file PATH in the survey `data` — not the bytes, to keep the SQLite row light). An injected `ImageService` (like Phase 3a's `LocationService`) does pick→compress→store→path; a fake drives tests. A new `ImageControl` renders content-only (P2b border layer outlines it): fill mode shows the photo + ✕ clear, or an "add photo" button. The PDF needs image BYTES but `ControlSpec.paintPdf` is synchronous, so a new `ControlSpec.resolvePdfValue(cell, value)` async hook (default identity) lets `ImageControl` turn a file path into bytes; the export pre-resolves the data map before `renderTemplate`, and `ImageControl.paintPdf` wraps the bytes in `pw.MemoryImage` synchronously.

**Tech Stack:** Flutter 3.27.2 / Dart 3.6.1. New deps (pinned to the old app's proven set): `image_picker: ^1.2.0`, `flutter_image_compress: ^2.4.0`, `uuid: ^4.5.3` (filenames), `path: ^1.9.0` (joins). Reuses `path_provider` (already a dep). Ports `/Users/xxf/Desktop/scss/app/lib/services/image_service.dart`.

## Global Constraints

- **Store the PATH, not the bytes.** `data[key]` for an image holds the `.jpg` file path (String). Image bytes are never put in the survey JSON (keeps SQLite rows small; matches the old app).
- **Pinned deps (Dart 3.6.1).** `image_picker ^1.2.0`, `flutter_image_compress ^2.4.0`, `uuid ^4.5.3`. These are the old app's verified versions — do not bump. `image_picker` + the existing `image_picker_android` need only the existing config + a `CAMERA` permission; do NOT add `permission_handler`, Kotlin/AGP bumps, or a resolutionStrategy (those were for other plugins).
- **Compression target (old app):** pick at quality 95 → compress quality 82 / minWidth&Height 1600 → if still > 500 KB, re-compress (quality 68→52→36→20, minWidth&Height 1280) until under 500 KB or the floor. Store at `<appDocs>/survey_images/<uuid>.jpg`.
- **Service injected, testable.** `ImageControl({ImageService? image})`; with no service it shows a disabled "add photo" affordance / plain state. Real `ImagePickerImageService` is device-only (verified in the manual sim); a fake drives widget tests.
- **PDF is async-prepared, paintPdf stays sync.** New `ControlSpec.resolvePdfValue(Cell, Object?) → Future<Object?>` defaults to identity; `ImageControl` overrides it to read the file → `Uint8List`. The export pre-resolves the data map (`resolvePdfData`) before `renderTemplate`. `paintPdf` reads the resolved bytes (or renders a blank cell if none). No change to the sync `paintPdf` signature.
- **One data map drives fill + PDF.** The image key flows: fill stores a path; export resolves path→bytes; the PDF embeds it. WYSIWYG (spec §7).
- **P2 model intact.** `image` is a value control in the VB toolbox; content-only (the P2b border layer draws its outline). No changes to label/text/number/coordinate/title.
- Quality gate every code task: from `grid_app/`, `flutter analyze` = `No issues found!` and `flutter test` green. Task 1 also requires a successful `flutter build apk --debug`.
- Manual simulator pass at the end (Task 6, controller) — real camera/gallery capture + PDF embed needs a device.

---

### Task 0: Start a feature branch

**Files:** none (git only)

- [ ] **Step 1**

```bash
cd /Users/xxf/Desktop/scss
git checkout main && git checkout -b feat/phase3b-image
git branch --show-current
```
Expected: `feat/phase3b-image`.

---

### Task 1: Add image deps + CAMERA permission (and prove it builds)

**Files:**
- Modify: `grid_app/pubspec.yaml`
- Modify: `grid_app/android/app/src/main/AndroidManifest.xml`

**Interfaces:**
- Produces: `image_picker`, `flutter_image_compress`, `uuid`, `path` resolvable; Android builds with the `CAMERA` permission. No Dart symbols yet.

- [ ] **Step 1: Add the dependencies**

In `grid_app/pubspec.yaml`, under `dependencies:` (after `geolocator:`), add:
```yaml
  image_picker: ^1.2.0
  flutter_image_compress: ^2.4.0
  uuid: ^4.5.3
  path: ^1.9.0
```

- [ ] **Step 2: Resolve them**

Run: `cd grid_app && flutter pub get`
Expected: resolves cleanly (image_picker 1.2.x, flutter_image_compress 2.4.x, uuid 4.5.x, path 1.9.x). No version-solve errors.

- [ ] **Step 3: Declare the CAMERA permission**

In `grid_app/android/app/src/main/AndroidManifest.xml`, add as a direct child of `<manifest>` (with the existing location permissions):
```xml
    <uses-permission android:name="android.permission.CAMERA"/>
```

- [ ] **Step 4: Prove the Android build resolves the plugins**

Run: `cd grid_app && flutter analyze && flutter build apk --debug`
Expected: `No issues found!` and `✓ Built build/app/outputs/flutter-apk/app-debug.apk`.
If the build fails on an AGP/Kotlin/SDK error, STOP and report BLOCKED with the exact error — do NOT bump Kotlin/AGP or add a resolutionStrategy.

- [ ] **Step 5: Confirm existing tests still pass**

Run: `cd grid_app && flutter test`
Expected: all existing tests green (deps added but unused).

- [ ] **Step 6: Commit**

```bash
cd /Users/xxf/Desktop/scss && git add -A && git commit -q -m "build(android): add image_picker/flutter_image_compress/uuid/path + CAMERA permission"
```

---

### Task 2: `ImageService` (+ image_picker/compress impl)

**Files:**
- Create: `grid_app/lib/services/image_service.dart`
- Test: `grid_app/test/services/image_service_test.dart`

**Interfaces:**
- Consumes: `image_picker`, `flutter_image_compress`, `uuid`, `path`, `path_provider`.
- Produces:
  ```dart
  enum ImageSource { camera, gallery }   // re-exported / mirrored from image_picker
  abstract class ImageService {
    Future<String?> capture(ImageSource source); // pick+compress+store -> file path, or null if cancelled
  }
  class ImagePickerImageService implements ImageService { ... } // device-only
  ```
  (Use image_picker's own `ImageSource` enum directly to avoid a second enum — import `package:image_picker/image_picker.dart` and expose `capture(ImageSource source)`.)

- [ ] **Step 1: Write the failing test**

`ImagePickerImageService` is device-only (it calls platform channels). Test only the boundary: a fake implementing `ImageService` round-trips, and the abstract type is usable. Create `grid_app/test/services/image_service_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:scss_grid/services/image_service.dart';

class _FakeImageService implements ImageService {
  String? next;
  ImageSource? lastSource;
  _FakeImageService(this.next);
  @override
  Future<String?> capture(ImageSource source) async {
    lastSource = source;
    return next;
  }
}

void main() {
  test('ImageService.capture returns a stored path (fake)', () async {
    final s = _FakeImageService('/docs/survey_images/abc.jpg');
    expect(await s.capture(ImageSource.camera), '/docs/survey_images/abc.jpg');
    expect(s.lastSource, ImageSource.camera);
  });

  test('capture returns null when cancelled (fake)', () async {
    final s = _FakeImageService(null);
    expect(await s.capture(ImageSource.gallery), isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd grid_app && flutter test test/services/image_service_test.dart`
Expected: FAIL (`image_service.dart` not found).

- [ ] **Step 3: Write the implementation**

Create `grid_app/lib/services/image_service.dart` (ports the old app's `image_service.dart` flow, scoped to a flat `survey_images` folder):
```dart
import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Captures a photo (camera/gallery), compresses it, stores it in the app
/// documents directory, and returns the file path. Abstracted so controls can
/// be tested with a fake (the image_picker impl is device-only).
abstract class ImageService {
  /// Pick from [source], compress, store; returns the saved file path, or null
  /// if the user cancelled.
  Future<String?> capture(ImageSource source);
}

class ImagePickerImageService implements ImageService {
  final ImagePicker _picker = ImagePicker();
  final Uuid _uuid = const Uuid();

  Future<Directory> _dir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'survey_images'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  @override
  Future<String?> capture(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 95);
    if (picked == null) return null;
    final dir = await _dir();
    final target = p.join(dir.path, '${_uuid.v4()}.jpg');

    final compressed = await FlutterImageCompress.compressAndGetFile(
      picked.path,
      target,
      quality: 82,
      minWidth: 1600,
      minHeight: 1600,
    );
    if (compressed == null) {
      await File(picked.path).copy(target);
      return target;
    }
    return _ensureUnder500kb(compressed.path);
  }

  /// Re-compress until the file is under 500 KB or the quality floor is hit.
  Future<String> _ensureUnder500kb(String path) async {
    var current = path;
    var quality = 68;
    while (await File(current).length() > 500 * 1024 && quality >= 30) {
      final out = '$current.q$quality.jpg';
      final res = await FlutterImageCompress.compressAndGetFile(
        current,
        out,
        quality: quality,
        minWidth: 1280,
        minHeight: 1280,
      );
      if (res == null) break;
      current = res.path;
      quality -= 16;
    }
    return current;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd grid_app && flutter test test/services/image_service_test.dart`
Expected: PASS (2 tests). `ImagePickerImageService` is not unit-tested — it forwards to platform plugins; verified on-device in Task 6.

- [ ] **Step 5: Analyze + commit**

```bash
cd /Users/xxf/Desktop/scss/grid_app && flutter analyze
cd /Users/xxf/Desktop/scss && git add -A && git commit -q -m "feat(services): ImageService + image_picker/compress impl"
```
Expected: `No issues found!`, then commit.

---

### Task 3: `ControlSpec.resolvePdfValue` + `ImageControl`

**Files:**
- Modify: `grid_app/lib/controls/control_spec.dart` (add `resolvePdfValue` default)
- Create: `grid_app/lib/controls/image_control.dart`
- Test: `grid_app/test/controls/image_control_test.dart`

**Interfaces:**
- Consumes: `ImageService`, `ImageSource`, `ControlSpec`, `Cell`.
- Produces:
  - `Future<Object?> ControlSpec.resolvePdfValue(Cell cell, Object? value) async => value;` (default identity).
  - `class ImageControl extends ControlSpec` — `type='image'`, props `{key, caption}`, `ImageControl({ImageService? image})`. `previewWidget`: grey `[image]` placeholder. `fillWidget`: if `value` (a path) is set → `Image.file` + a ✕ clear button (keyed `ValueKey('image-clear')`) that calls `onChanged(null)`; else an "add photo" button (keyed `ValueKey('image-add')`) that, with a service, picks (a camera/gallery choice) → `onChanged(path)`. `resolvePdfValue`: if `value` is a non-empty path to an existing file → `await File(value).readAsBytes()` (Uint8List); else null. `paintPdf`: if `data[key]` is `Uint8List` → `pw.Image(pw.MemoryImage(bytes), fit: contain)`; else a blank `pw.SizedBox`. `dataKey` = `props['key']`.

- [ ] **Step 1: Write the failing test**

Create `grid_app/test/controls/image_control_test.dart`:
```dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:scss_grid/controls/image_control.dart';
import 'package:scss_grid/model/cell.dart';
import 'package:scss_grid/services/image_service.dart';

class _FakeImage implements ImageService {
  final String? path;
  _FakeImage(this.path);
  @override
  Future<String?> capture(ImageSource source) async => path;
}

const _cell = Cell(id: 'i', col: 0, row: 0, colSpan: 4, rowSpan: 3, type: 'image',
    props: {'key': 'site_photo'});

Widget _host(Widget child) =>
    MaterialApp(home: Scaffold(body: SizedBox(width: 200, height: 200, child: child)));

void main() {
  test('type, defaultProps, dataKey', () {
    final c = ImageControl();
    expect(c.type, 'image');
    expect(c.defaultProps(), {'key': 'image', 'caption': ''});
    expect(c.dataKey(_cell), 'site_photo');
  });

  testWidgets('with no value, shows an add-photo button', (tester) async {
    await tester.pumpWidget(_host(
      ImageControl(image: _FakeImage('/x.jpg')).fillWidget(_cell, null, (_) {}),
    ));
    expect(find.byKey(const ValueKey('image-add')), findsOneWidget);
    expect(find.byKey(const ValueKey('image-clear')), findsNothing);
  });

  testWidgets('with a value, shows the image and a clear button that clears',
      (tester) async {
    Object? captured = 'unset';
    await tester.pumpWidget(_host(
      ImageControl(image: _FakeImage(null))
          .fillWidget(_cell, '/nonexistent.jpg', (v) => captured = v),
    ));
    expect(find.byKey(const ValueKey('image-clear')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('image-clear')));
    await tester.pump();
    expect(captured, isNull); // clear → onChanged(null)
  });

  test('resolvePdfValue: null/empty/missing-file → null', () async {
    final c = ImageControl();
    expect(await c.resolvePdfValue(_cell, null), isNull);
    expect(await c.resolvePdfValue(_cell, ''), isNull);
    expect(await c.resolvePdfValue(_cell, '/does/not/exist.jpg'), isNull);
  });

  test('paintPdf tolerates non-bytes value (renders without throwing)', () {
    final c = ImageControl();
    // data has a path string (not yet resolved) → must not throw, renders blank
    expect(() => c.paintPdf(_cell, const {'site_photo': '/x.jpg'}), returnsNormally);
    // data has bytes → renders an image without throwing
    expect(
        () => c.paintPdf(_cell, {'site_photo': Uint8List.fromList(const [1, 2, 3])}),
        returnsNormally);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd grid_app && flutter test test/controls/image_control_test.dart`
Expected: FAIL (`image_control.dart` not found; `resolvePdfValue` undefined).

- [ ] **Step 3: Add `resolvePdfValue` default to `ControlSpec`**

In `grid_app/lib/controls/control_spec.dart`, add (next to `dataKey`):
```dart
  /// Transform this control's fill value into the value its `paintPdf` expects,
  /// async, before PDF rendering. Default: identity (text/number/coordinate
  /// print their string as-is). `image` overrides this to read its file into
  /// bytes, since `paintPdf` is synchronous and cannot do file IO.
  Future<Object?> resolvePdfValue(Cell cell, Object? value) async => value;
```

- [ ] **Step 4: Write `ImageControl`**

Create `grid_app/lib/controls/image_control.dart`:
```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/widgets.dart' as pw;

import '../model/cell.dart';
import '../services/image_service.dart';
import 'control_spec.dart';

/// A single-photo value control. Fill mode: capture (camera/gallery) → compress
/// → store; the value is the file path; shows the photo with a ✕ clear button.
/// PDF: embeds the photo (bytes resolved via [resolvePdfValue] before render).
class ImageControl extends ControlSpec {
  /// Injected by the registry so fill mode can capture photos. Null → the
  /// add-photo button is shown but capture is a no-op (tests / non-device).
  final ImageService? image;

  ImageControl({this.image});

  @override
  String get type => 'image';
  @override
  String get label => 'Image';
  @override
  IconData get icon => Icons.image_outlined;
  @override
  Map<String, dynamic> defaultProps() => {'key': 'image', 'caption': ''};

  @override
  Future<Object?> resolvePdfValue(Cell cell, Object? value) async {
    if (value is! String || value.isEmpty) return null;
    final f = File(value);
    if (!await f.exists()) return null;
    return f.readAsBytes();
  }

  @override
  pw.Widget paintPdf(Cell cell, Map<String, dynamic> data) {
    final v = data[cell.props['key']];
    if (v is Uint8List) {
      return pw.Image(pw.MemoryImage(v), fit: pw.BoxFit.contain);
    }
    return pw.SizedBox();
  }

  @override
  Widget previewWidget(Cell cell) => Container(
        alignment: Alignment.center,
        child: const Text('[image]',
            style: TextStyle(fontSize: 9, color: Color(0xFF9A9A9A))),
      );

  @override
  Widget fillWidget(
          Cell cell, Object? value, void Function(Object? value) onChanged) =>
      _ImageField(image: image, value: value as String?, onChanged: onChanged);
}

class _ImageField extends StatelessWidget {
  final ImageService? image;
  final String? value;
  final void Function(Object? value) onChanged;

  const _ImageField({
    required this.image,
    required this.value,
    required this.onChanged,
  });

  Future<void> _add(BuildContext context) async {
    final svc = image;
    if (svc == null) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(children: [
          ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(context, ImageSource.camera)),
          ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery)),
        ]),
      ),
    );
    if (source == null) return;
    final path = await svc.capture(source);
    if (path != null) onChanged(path);
  }

  @override
  Widget build(BuildContext context) {
    final path = value;
    if (path != null && path.isNotEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.file(File(path), fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  const Center(child: Icon(Icons.broken_image, size: 16))),
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              key: const ValueKey('image-clear'),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              iconSize: 16,
              tooltip: 'Clear',
              icon: const Icon(Icons.close),
              onPressed: () => onChanged(null),
            ),
          ),
        ],
      );
    }
    return Center(
      child: IconButton(
        key: const ValueKey('image-add'),
        iconSize: 20,
        tooltip: 'Add photo',
        icon: const Icon(Icons.add_a_photo_outlined),
        onPressed: () => _add(context),
      ),
    );
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd grid_app && flutter test test/controls/image_control_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 6: Analyze + commit**

```bash
cd /Users/xxf/Desktop/scss/grid_app && flutter analyze
cd /Users/xxf/Desktop/scss && git add -A && git commit -q -m "feat(controls): ImageControl + ControlSpec.resolvePdfValue"
```
Expected: `No issues found!`, then commit.

---

### Task 4: PDF pre-resolve (`resolvePdfData`) + async `PdfPreviewScreen`

**Files:**
- Create: `grid_app/lib/pdf/resolve_pdf_data.dart`
- Modify: `grid_app/lib/builder/pdf_preview_screen.dart`
- Test: `grid_app/test/pdf/resolve_pdf_data_test.dart`

**Interfaces:**
- Consumes: `ControlSpec.resolvePdfValue`/`dataKey`, `ControlRegistry`, `Template`.
- Produces: `Future<Map<String, dynamic>> resolvePdfData(Template t, Map<String, dynamic> data, ControlRegistry registry)` — for each cell with a `dataKey`, replaces the value with `await spec.resolvePdfValue(cell, value)` (so an image path becomes bytes; text stays a string). `PdfPreviewScreen` calls it (async) before `renderTemplate`.

- [ ] **Step 1: Write the failing test**

Create `grid_app/test/pdf/resolve_pdf_data_test.dart`:
```dart
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/controls/control_spec.dart';
import 'package:scss_grid/controls/registry.dart';
import 'package:scss_grid/model/cell.dart';
import 'package:scss_grid/model/grid_frame.dart';
import 'package:scss_grid/model/template.dart';
import 'package:scss_grid/pdf/resolve_pdf_data.dart';
import 'package:flutter/widgets.dart';
import 'package:pdf/widgets.dart' as pw;

// A minimal control whose resolvePdfValue turns its value into bytes.
class _BytesControl extends ControlSpec {
  @override
  String get type => 'bytes';
  @override
  String get label => 'Bytes';
  @override
  IconData get icon => Icons.image;
  @override
  Map<String, dynamic> defaultProps() => {'key': 'k'};
  @override
  Future<Object?> resolvePdfValue(Cell cell, Object? value) async =>
      value == null ? null : Uint8List.fromList([1, 2, 3]);
  @override
  pw.Widget paintPdf(Cell cell, Map<String, dynamic> data) => pw.SizedBox();
}

Template _tpl(List<Cell> cells) => Template(
      id: 't', name: 'n', page: const PageSize.a4(),
      grid: GridFrame.uniform(xMm: 0, yMm: 0, cols: 4, rows: 4, colWidthMm: 20, rowHeightMm: 10),
      cells: cells,
    );

void main() {
  test('resolvePdfData maps each cell value through its control', () async {
    final r = ControlRegistry()..register(_BytesControl());
    final t = _tpl(const [Cell(id: 'a', col: 0, row: 0, type: 'bytes', props: {'key': 'k'})]);
    final out = await resolvePdfData(t, const {'k': '/some/path.jpg', 'other': 'x'}, r);
    expect(out['k'], isA<Uint8List>());       // resolved path → bytes
    expect(out['other'], 'x');                 // untouched keys preserved
  });

  test('unregistered cell type leaves data unchanged', () async {
    final r = ControlRegistry();
    final t = _tpl(const [Cell(id: 'a', col: 0, row: 0, type: 'nope', props: {'key': 'k'})]);
    final out = await resolvePdfData(t, const {'k': 'v'}, r);
    expect(out['k'], 'v');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd grid_app && flutter test test/pdf/resolve_pdf_data_test.dart`
Expected: FAIL (`resolve_pdf_data.dart` not found).

- [ ] **Step 3: Write `resolvePdfData`**

Create `grid_app/lib/pdf/resolve_pdf_data.dart`:
```dart
import '../controls/registry.dart';
import '../model/template.dart';

/// Prepare [data] for PDF rendering: for each cell that has a data key, replace
/// its value with `spec.resolvePdfValue(...)` (async). Most controls are
/// identity; `image` turns a file path into bytes (since paintPdf is sync).
Future<Map<String, dynamic>> resolvePdfData(
  Template t,
  Map<String, dynamic> data,
  ControlRegistry registry,
) async {
  final out = Map<String, dynamic>.from(data);
  for (final cell in t.cells) {
    final spec = registry.specFor(cell.type);
    if (spec == null) continue;
    final key = spec.dataKey(cell);
    if (key == null) continue;
    out[key] = await spec.resolvePdfValue(cell, out[key]);
  }
  return out;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd grid_app && flutter test test/pdf/resolve_pdf_data_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Make `PdfPreviewScreen` resolve before rendering**

In `grid_app/lib/builder/pdf_preview_screen.dart`:
1. Add the import:
```dart
import '../pdf/resolve_pdf_data.dart';
```
2. Change the `PdfPreview` `build` callback to async-resolve the data first:
```dart
        build: (format) => renderTemplate(template, data, registry).save(),
```
to:
```dart
        build: (format) async {
          final resolved = await resolvePdfData(template, data, registry);
          return renderTemplate(template, resolved, registry).save();
        },
```

- [ ] **Step 6: Run the pdf/builder tests + analyze**

Run: `cd grid_app && flutter test test/pdf/ test/builder/pdf_preview_screen_test.dart && flutter analyze`
Expected: PASS (the existing preview test still builds — `resolvePdfData` with no image controls is a near-identity map) and `No issues found!`.

- [ ] **Step 7: Commit**

```bash
cd /Users/xxf/Desktop/scss && git add -A && git commit -q -m "feat(pdf): resolvePdfData (async image bytes) + async PdfPreviewScreen"
```

---

### Task 5: Register `ImageControl` (registry + main wiring)

**Files:**
- Modify: `grid_app/lib/controls/default_controls.dart`
- Modify: `grid_app/lib/main.dart`
- Test: `grid_app/test/controls/default_controls_test.dart` (update the expected set)

**Interfaces:**
- Consumes: `ImageControl`, `ImageService`/`ImagePickerImageService`.
- Produces: `buildDefaultRegistry({LocationService? location, ImageService? image})` registers `ImageControl(image: image)`; `main` injects `ImagePickerImageService()`.

- [ ] **Step 1: Update the registry test first**

In `grid_app/test/controls/default_controls_test.dart`, update the expected control-type set to include `image` (the test asserts `buildDefaultRegistry().all.map((s)=>s.type).toSet()`). Add `'image'` to the expected set.

- [ ] **Step 2: Run it to verify it fails**

Run: `cd grid_app && flutter test test/controls/default_controls_test.dart`
Expected: FAIL (`image` not registered).

- [ ] **Step 3: Register `ImageControl`**

In `grid_app/lib/controls/default_controls.dart`:
1. Add the imports:
```dart
import 'image_control.dart';
import '../services/image_service.dart';
```
2. Change the signature + add the registration:
```dart
ControlRegistry buildDefaultRegistry(
    {LocationService? location, ImageService? image}) {
  final r = ControlRegistry();
  r.register(TitleControl());
  r.register(LabelControl());
  r.register(TextControl());
  r.register(NumberControl());
  r.register(CoordinateControl(location: location));
  r.register(ImageControl(image: image));
  return r;
}
```

- [ ] **Step 4: Wire the real service in `main`**

In `grid_app/lib/main.dart`:
1. Add the import:
```dart
import 'services/image_service.dart';
```
2. Pass the service:
```dart
    registry: buildDefaultRegistry(location: GeolocatorLocationService()),
```
to:
```dart
    registry: buildDefaultRegistry(
      location: GeolocatorLocationService(),
      image: ImagePickerImageService(),
    ),
```

- [ ] **Step 5: Run the FULL suite + analyze**

Run: `cd grid_app && flutter analyze && flutter test`
Expected: `No issues found!` and ALL green (the registry test now expects `image`; the palette/golden tests count controls dynamically so they adapt; if `grid_canvas_golden_test` fails because the palette has a new item, regenerate it — but the golden renders the CANVAS (sample template), not the palette, so it should NOT change).

- [ ] **Step 6: Commit**

```bash
cd /Users/xxf/Desktop/scss && git add -A && git commit -q -m "feat: register ImageControl + wire ImagePickerImageService in main"
```

---

### Task 6: Manual simulator pass (controller, not a subagent)

**Files:** none

- [ ] **Step 1: Run on the emulator and verify image capture + PDF embed by observation**

```bash
flutter emulators --launch Medium_Phone_API_35
cd /Users/xxf/Desktop/scss/grid_app && flutter run -d emulator-5554
```
Verify and report what you see:
1. Builder: the palette now includes **Image**. Place an `Image` control spanning a few cells (e.g. cols 0–5, rows 4–8); it shows the `[image]` placeholder, outlined by the border layer. Save.
2. Fill the template → the image cell shows an **add-photo** button (📷). Tap it → a Camera/Gallery sheet appears → pick Gallery (the emulator has sample images; or use Camera) → the photo appears in the cell, compressed and stored.
3. A **✕ clear** button is shown over the photo; tapping it removes the photo (back to the add button).
4. Re-add a photo, then **Export** → the PDF preview embeds the photo in that cell (fit-contain), alongside the other fields.
5. **Save** the survey → reopen from Surveys → the photo is still there (the path persisted); Export again still embeds it.

If capture/permission/clear/PDF-embed misbehaves, report DONE_WITH_CONCERNS with specifics. (On the emulator, grant the camera permission when prompted; Gallery uses the device's sample images.)

---

## Phase 3b — Definition of Done

- An `image` control captures a photo (camera/gallery) in fill mode, compresses + stores it on device, keeps the file PATH in the survey data, shows the photo with a ✕ clear, and the exported PDF embeds the photo.
- The PDF embed works despite the synchronous `paintPdf`: `ControlSpec.resolvePdfValue` (async, default identity) + `resolvePdfData` pre-resolve the path→bytes before render; `ImageControl.paintPdf` wraps the bytes in `pw.MemoryImage`.
- `image_picker ^1.2.0` + `flutter_image_compress ^2.4.0` build on the app's Android toolchain (`flutter build apk --debug` succeeds) with only a `CAMERA` permission; no Kotlin/AGP/resolutionStrategy changes.
- The control is plugin-generic (in the VB toolbox, content-only, outlined by the P2b border layer); no other control changed.
- `flutter analyze` = 0; `flutter test` all green; manual simulator pass confirms capture → display → clear → PDF embed → persist.
- Deferred to later phases: `multiImage` (3c), `satelliteDiagram` (3d), orphaned-image-file cleanup, per-survey image foldering, image caption in the PDF.

## Self-Review (against spec)

**Coverage (spec §6 `image`, §8 reuse camera/compress, §12.3 现场能力):**
- §6 `image` "点击→相机/相册→填入一张;支持清除重填" → Task 3 (`_ImageField` add/clear). ✓
- §6 `image` PDF "图片" → Task 3 (`paintPdf` `pw.MemoryImage`) + Task 4 (resolve path→bytes). ✓
- §8 "复用相机+压缩" → Task 2 ports the old `image_service.dart` (image_picker + flutter_image_compress, <500KB loop). ✓
- §7 one model drives fill+PDF → path in `data[key]`; resolve→bytes for PDF. ✓
- §10.1 plugin-generic → `image` is a registry entry; `resolvePdfValue` is a generic ControlSpec hook (default identity), not image-specific switch. ✓
- Pinned-version discipline → Task 1 pins image_picker ^1.2.0 / flutter_image_compress ^2.4.0, CAMERA only, no toolchain bump. ✓

**Placeholder scan:** Complete code for the service (Task 2), the control + resolvePdfValue (Task 3), the resolve helper + async preview (Task 4), and the wiring (Task 5). Task 6 is explicit manual observation. `ImagePickerImageService` device-only (not unit-tested) is a stated, justified decision.

**Type consistency:** `ImageService.capture(ImageSource)→Future<String?>`, `ImageControl({image})`, `ControlSpec.resolvePdfValue(Cell,Object?)→Future<Object?>`, `resolvePdfData(Template,Map,ControlRegistry)→Future<Map>`, `buildDefaultRegistry({location, image})`, and the `image-add`/`image-clear` keys are consistent across Tasks 2–5 and the tests.
