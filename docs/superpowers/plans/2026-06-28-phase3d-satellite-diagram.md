# Phase 3d — SatelliteDiagram 卫星图打钉截图控件 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 新增 `SatelliteDiagramControl`（type `satelliteDiagram`），让一个网格格子承载"开卫星地图 → 打钉 → 截图"，截图嵌入 PDF；钉带可选标签、可改/删；支持清除重测。

**Architecture:** 方案 A——控件 `fillWidget` 显示截图缩略图（有图：图 + ✕ 清除；无图：开地图按钮），点击 `Navigator.push` 全屏 `SatelliteDiagramScreen`（移植旧 `app/lib/screens/site_diagram_screen.dart` 并与 `Site`/DB 解耦），返回 `{pins, center, zoom, path}`；控件把该 Map 整体存进 `data[key]`。PDF 经现有异步管线 `resolvePdfValue`（读截图字节）→ `paintPdf`（`pw.Image` + 可选 caption）。

**Tech Stack:** Flutter / Dart，`flutter_test`（手写 fake，无 mockito），`pdf`（`pw.*`），`flutter_map ^8.3.0` + `latlong2`（`LatLng`）+ `screenshot ^3.0.0`，`geolocator`（经 `LocationService`），`image_picker`（`ImageSource`），包名 `package:scss_grid`。

## Global Constraints

- 所有 `flutter` / `git` 命令在 `grid_app/` 目录下执行（pubspec 所在目录）。
- 值类型：`data[key]` 存 Map `{'path': String, 'pins': List<Map>, 'center': {'lat','lon'}, 'zoom': num}`；未填/清除为 `null`。
- `defaultProps()` = `{'key': 'diagram', 'caption': ''}`。
- 清除 = `onChanged(null)`（一次清掉截图 + 钉 + 中心）。空值合法（`validate` 返回 `null`）。
- 钉：点空白落红钉；点钉弹框改标签 / 删除；标签画钉下方、烤进截图。
- 初始中心：仅首填（`initialCenter == null`）取当前 GPS；失败/拒权/无 `LocationService` → 兜底 `LatLng(40.0759, 20.1389)`。重开用存的 `center/zoom`。
- 不引 `connectivity_plus`（无离线橙条）。截图用 `screenshot` 包 `capture(delay: 250ms)`。
- 旧截图覆盖保存时不主动删（与现有 image 控件一致）。
- caption 用与 title/label 相同的默认 PDF 字体路径；中文缺字限制全 app 一致，本期不解决。
- 测试不依赖平台通道：`Directory.systemTemp` 真实文件 IO 可用；`ImagePickerImageService.saveBytes`、`SatelliteDiagramScreen`、GPS、flutter_map 渲染仅真机验收（Task 8），不写自动化测试。
- 依赖钉版底线：当前 Flutter 3.27 / Dart 3.6.1，`geolocator` 钉在 13.x（14.x 调 `Color.toARGB32()` 在 3.27 不存在）。新依赖若与之传递冲突，按 geolocator 先例钉版。

---

## File Structure

- `lib/model/pin.dart` — **新建**。`Pin` 值对象（lat/lon/label + copyWith/toJson/fromJson），移植自旧 app。
- `lib/services/image_service.dart` — **改**。`ImageService` 抽象类加 `saveBytes`；`ImagePickerImageService` 实现。
- `lib/controls/satellite_diagram_control.dart` — **新建**。顶层解析函数 `diagramPath/diagramPins/diagramCenter/diagramZoom`、`SatelliteResult` typedef、`SatelliteDiagramControl`（ControlSpec 子类）、私有 `_SatelliteField`（填写控件）。
- `lib/fill/satellite_diagram_screen.dart` — **新建**。全屏地图屏（flutter_map + Esri 瓦片 + screenshot），纯输入输出，device-only。
- `lib/controls/default_controls.dart` — **改**。注册一行。
- `pubspec.yaml` — **改**。加 3 依赖。
- `test/model/pin_test.dart` — **新建**。Pin 往返/copyWith。
- `test/controls/satellite_diagram_control_test.dart` — **新建**。解析函数 / validate / resolvePdfValue / paintPdf / fillWidget / propEditor。
- `test/controls/default_controls_test.dart` — **改**。类型集合 + defaultProps 断言。

---

### Task 1: 新增依赖（flutter_map / latlong2 / screenshot）

风险点 0：先确认三包与当前 Flutter 3.27 / Dart 3.6.1 + 钉版 geolocator 13.x 无冲突。本任务无单测，gate = `pub get` 成功 + `analyze` 干净。

**Files:**
- Modify: `pubspec.yaml`（dependencies 段）

**Interfaces:**
- Produces: 项目可 `import 'package:flutter_map/flutter_map.dart';` / `'package:latlong2/latlong.dart';` / `'package:screenshot/screenshot.dart';`。

- [ ] **Step 1: 在 `pubspec.yaml` 的 `dependencies:` 段加三行**

在 `flutter_image_compress: ^2.4.0` 之后插入：

```yaml
  flutter_map: ^8.3.0
  latlong2: ^0.9.1
  screenshot: ^3.0.0
```

- [ ] **Step 2: 拉取依赖**

Run: `flutter pub get`
Expected: `Got dependencies!`（无 version solving 失败）。若报与 geolocator/其它包的 solver 冲突，记录冲突包并钉到兼容版本（参考已有 geolocator 13.x 钉版注释），重跑直到通过。

- [ ] **Step 3: 静态分析确认无破坏**

Run: `flutter analyze`
Expected: `No issues found!`（依赖加入不应引入告警）。

- [ ] **Step 4: de-risk Android 构建（关键）**

`analyze` 不跑 Android Gradle 构建;`flutter_map`/`screenshot` 的原生侧问题(Kotlin 版本 / minSdk / androidx.core)只在真正 apk 构建时暴露。沿用 Phase 3b Task 1 先例提前 de-risk:

Run: `flutter build apk --debug`
Expected: `✓ Built build/app/outputs/flutter-apk/app-debug.apk`。

若构建失败,按 `app/BUILD_NOTES.md` 的**最小**改动修(只针对实际报错):
- Kotlin 报元数据版本不兼容 → `android/settings.gradle` 的 Kotlin Gradle plugin 升到 `2.2.0`。
- `androidx.core` 版本被某插件拉高、要求更高 AGP → `android/app/build.gradle` 加 `configurations.all { resolutionStrategy.force 'androidx.core:core:1.13.1' }`。
- minSdk 过低 → 升到 23。
- **注意**:本期**不引** `connectivity_plus` / `share_plus`,BUILD_NOTES 里因这两个包而来的钉版**多半用不上**——只改实际报错项,不照搬全部。
- 任何 Android 配置改动后重跑本步,直到 `BUILD SUCCESSFUL`。

- [ ] **Step 5: Commit**

```bash
git add pubspec.yaml pubspec.lock android/
git commit -m "build(phase3d): add flutter_map/latlong2/screenshot deps + de-risk apk build"
```

---

### Task 2: `Pin` 值对象

**Files:**
- Create: `lib/model/pin.dart`
- Test: `test/model/pin_test.dart`

**Interfaces:**
- Produces: `class Pin { final double lat, lon; final String label; const Pin({required lat, required lon, label=''}); Pin copyWith({lat,lon,label}); Map<String,dynamic> toJson(); factory Pin.fromJson(Map<String,dynamic>); }`

- [ ] **Step 1: 写失败测试**

`test/model/pin_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/model/pin.dart';

void main() {
  test('default label is empty', () {
    expect(const Pin(lat: 1, lon: 2).label, '');
  });

  test('toJson / fromJson round-trips', () {
    const p = Pin(lat: 40.5, lon: 20.1, label: 'P1');
    final back = Pin.fromJson(p.toJson());
    expect(back.lat, 40.5);
    expect(back.lon, 20.1);
    expect(back.label, 'P1');
  });

  test('fromJson defaults missing label to empty', () {
    final p = Pin.fromJson(const {'lat': 1, 'lon': 2});
    expect(p.label, '');
  });

  test('fromJson coerces int coords to double', () {
    final p = Pin.fromJson(const {'lat': 1, 'lon': 2});
    expect(p.lat, 1.0);
    expect(p.lon, 2.0);
  });

  test('copyWith overrides only given fields', () {
    const p = Pin(lat: 1, lon: 2, label: 'a');
    final q = p.copyWith(label: 'b');
    expect(q.lat, 1);
    expect(q.lon, 2);
    expect(q.label, 'b');
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/model/pin_test.dart`
Expected: 编译失败（`Pin` 未定义 / `pin.dart` 不存在）。

- [ ] **Step 3: 写最小实现**

`lib/model/pin.dart`:

```dart
/// A map marker placed on a satellite diagram. `label` is an optional caption
/// (e.g. a pole number) drawn under the pin and baked into the screenshot.
/// Ported from the old app (`app/lib/models/pin.dart`), unchanged.
class Pin {
  final double lat;
  final double lon;
  final String label;

  const Pin({required this.lat, required this.lon, this.label = ''});

  Pin copyWith({double? lat, double? lon, String? label}) => Pin(
        lat: lat ?? this.lat,
        lon: lon ?? this.lon,
        label: label ?? this.label,
      );

  Map<String, dynamic> toJson() => {'lat': lat, 'lon': lon, 'label': label};

  factory Pin.fromJson(Map<String, dynamic> j) => Pin(
        lat: (j['lat'] as num).toDouble(),
        lon: (j['lon'] as num).toDouble(),
        label: j['label'] as String? ?? '',
      );
}
```

- [ ] **Step 4: 运行确认通过**

Run: `flutter test test/model/pin_test.dart`
Expected: All tests passed!

- [ ] **Step 5: Commit**

```bash
git add lib/model/pin.dart test/model/pin_test.dart
git commit -m "feat(model): Pin value object (ported, TDD)"
```

---

### Task 3: `ImageService.saveBytes`

给抽象类加存字节能力（地图屏截图落盘用）。抽象方法 + fake 契约可单测；`ImagePickerImageService.saveBytes` 用 `path_provider`，device-only，不自动化测。

**Files:**
- Modify: `lib/services/image_service.dart`
- Test: `test/services/image_service_savebytes_test.dart`（新建）

**Interfaces:**
- Produces: `abstract ImageService { Future<String?> capture(ImageSource); Future<String> saveBytes(Uint8List bytes, {String ext = 'png'}); }`

- [ ] **Step 1: 写失败测试（fake 实现契约）**

`test/services/image_service_savebytes_test.dart`:

```dart
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:scss_grid/services/image_service.dart';

class _FakeImage implements ImageService {
  @override
  Future<String?> capture(ImageSource source) async => null;
  @override
  Future<String> saveBytes(Uint8List bytes, {String ext = 'png'}) async =>
      '/tmp/fake.$ext';
}

void main() {
  test('ImageService exposes saveBytes with ext defaulting to png', () async {
    final ImageService svc = _FakeImage();
    expect(await svc.saveBytes(Uint8List.fromList(const [1, 2, 3])),
        '/tmp/fake.png');
    expect(await svc.saveBytes(Uint8List(0), ext: 'jpg'), '/tmp/fake.jpg');
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/services/image_service_savebytes_test.dart`
Expected: 编译失败（`ImageService` 无 `saveBytes`；`_FakeImage` override 不匹配）。

- [ ] **Step 3: 写最小实现**

在 `lib/services/image_service.dart` 顶部加 `import 'dart:typed_data';`（若尚无），给抽象类加方法签名：

```dart
abstract class ImageService {
  /// Pick from [source], compress, store; returns the saved file path, or null
  /// if the user cancelled.
  Future<String?> capture(ImageSource source);

  /// Persist raw [bytes] (e.g. a map screenshot) into shared storage and return
  /// the absolute file path. [ext] is the file extension without the dot.
  Future<String> saveBytes(Uint8List bytes, {String ext = 'png'});
}
```

在 `ImagePickerImageService` 类内加实现（`_dir()` 与 `_uuid` 已存在）：

```dart
  @override
  Future<String> saveBytes(Uint8List bytes, {String ext = 'png'}) async {
    final dir = await _dir();
    final target = p.join(dir.path, '${_uuid.v4()}.$ext');
    await File(target).writeAsBytes(bytes, flush: true);
    return target;
  }
```

- [ ] **Step 4: 运行确认通过 + 全量回归**

Run: `flutter test test/services/image_service_savebytes_test.dart`
Expected: All tests passed!
Run: `flutter analyze`
Expected: No issues found!

- [ ] **Step 5: Commit**

```bash
git add lib/services/image_service.dart test/services/image_service_savebytes_test.dart
git commit -m "feat(services): ImageService.saveBytes for screenshot persistence (TDD)"
```

---

### Task 4: `SatelliteDiagramControl` 核心（解析 / validate / resolvePdfValue / paintPdf / preview）

控件主体，不含交互 UI（fillWidget/propEditor 留到 Task 6，先用 ControlSpec 默认）。顶层解析函数纯逻辑、重点测健壮性。

**Files:**
- Create: `lib/controls/satellite_diagram_control.dart`
- Test: `test/controls/satellite_diagram_control_test.dart`

**Interfaces:**
- Consumes: `ControlSpec`（`lib/controls/control_spec.dart`）、`Cell`（`lib/model/cell.dart`）、`Pin`（`lib/model/pin.dart`）、`LocationService`/`ImageService`（services）、`LatLng`（`package:latlong2/latlong.dart`）。
- Produces:
  - 顶层 `String? diagramPath(Object? v)`、`List<Pin> diagramPins(Object? v)`、`LatLng? diagramCenter(Object? v)`、`double diagramZoom(Object? v)`。
  - `typedef SatelliteResult = ({List<Pin> pins, LatLng center, double zoom, String path});`
  - `class SatelliteDiagramControl extends ControlSpec`（`SatelliteDiagramControl({LocationService? location, ImageService? image})`，`type=='satelliteDiagram'`，`defaultProps()=={'key':'diagram','caption':''}`）。Task 6 再 override `fillWidget`/`propEditor`。

- [ ] **Step 1: 写失败测试**

`test/controls/satellite_diagram_control_test.dart`:

```dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:scss_grid/controls/satellite_diagram_control.dart';
import 'package:scss_grid/model/cell.dart';
import 'package:scss_grid/model/pin.dart';

const _cell = Cell(
    id: 's', col: 0, row: 0, colSpan: 4, rowSpan: 3, type: 'satelliteDiagram',
    props: {'key': 'diagram', 'caption': 'Junction A'});

void main() {
  group('value parsing helpers', () {
    test('diagramPath extracts non-empty path, else null', () {
      expect(diagramPath({'path': '/x.png'}), '/x.png');
      expect(diagramPath({'path': ''}), isNull);
      expect(diagramPath({'pins': []}), isNull);
      expect(diagramPath(null), isNull);
      expect(diagramPath('not a map'), isNull);
    });

    test('diagramPins parses well-formed pins, skips malformed', () {
      final pins = diagramPins({
        'pins': [
          {'lat': 1, 'lon': 2, 'label': 'P1'},
          {'lat': 3.5, 'lon': 4.5},
          {'lat': 'bad', 'lon': 2}, // skipped: lat not num
          'garbage', // skipped: not a map
        ],
      });
      expect(pins.length, 2);
      expect(pins[0], isA<Pin>());
      expect(pins[0].label, 'P1');
      expect(pins[1].lat, 3.5);
      expect(pins[1].label, '');
    });

    test('diagramPins on missing/wrong-typed pins → empty', () {
      expect(diagramPins(null), isEmpty);
      expect(diagramPins({'pins': 'nope'}), isEmpty);
      expect(diagramPins({}), isEmpty);
    });

    test('diagramCenter parses {lat,lon}, else null', () {
      final c = diagramCenter({'center': {'lat': 40.0, 'lon': 20.0}});
      expect(c, isA<LatLng>());
      expect(c!.latitude, 40.0);
      expect(c.longitude, 20.0);
      expect(diagramCenter({'center': {'lat': 1}}), isNull);
      expect(diagramCenter(null), isNull);
    });

    test('diagramZoom parses num, defaults 17', () {
      expect(diagramZoom({'zoom': 18.5}), 18.5);
      expect(diagramZoom({'zoom': 16}), 16.0);
      expect(diagramZoom({}), 17.0);
      expect(diagramZoom(null), 17.0);
    });
  });

  test('type, defaultProps, dataKey', () {
    final c = SatelliteDiagramControl();
    expect(c.type, 'satelliteDiagram');
    expect(c.defaultProps(), {'key': 'diagram', 'caption': ''});
    expect(c.dataKey(_cell), 'diagram');
  });

  test('validate: empty value is legal (null)', () {
    final c = SatelliteDiagramControl();
    expect(c.validate(_cell, null), isNull);
    expect(c.validate(_cell, {'path': '/x.png'}), isNull);
  });

  group('resolvePdfValue', () {
    test('null / no-path / missing-file → null', () async {
      final c = SatelliteDiagramControl();
      expect(await c.resolvePdfValue(_cell, null), isNull);
      expect(await c.resolvePdfValue(_cell, {'path': ''}), isNull);
      expect(await c.resolvePdfValue(_cell, {'path': '/does/not/exist.png'}),
          isNull);
    });

    test('existing file → bytes', () async {
      final dir = await Directory.systemTemp.createTemp('sat_test');
      final f = File('${dir.path}/snap.png');
      await f.writeAsBytes(const [9, 8, 7]);
      final c = SatelliteDiagramControl();
      final out = await c.resolvePdfValue(_cell, {'path': f.path});
      expect(out, isA<Uint8List>());
      expect((out as Uint8List).toList(), [9, 8, 7]);
      await dir.delete(recursive: true);
    });
  });

  group('paintPdf', () {
    test('non-bytes value → renders blank without throwing', () {
      final c = SatelliteDiagramControl();
      expect(() => c.paintPdf(_cell, const {'diagram': {'path': '/x.png'}}),
          returnsNormally);
      expect(() => c.paintPdf(_cell, const {}), returnsNormally);
    });

    test('bytes value → renders without throwing (with and without caption)',
        () {
      final c = SatelliteDiagramControl();
      final bytes = Uint8List.fromList(const [1, 2, 3]);
      expect(() => c.paintPdf(_cell, {'diagram': bytes}), returnsNormally);
      const noCap = Cell(
          id: 's2', col: 0, row: 0, colSpan: 4, rowSpan: 3,
          type: 'satelliteDiagram', props: {'key': 'diagram', 'caption': ''});
      expect(() => c.paintPdf(noCap, {'diagram': bytes}), returnsNormally);
    });
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/controls/satellite_diagram_control_test.dart`
Expected: 编译失败（`satellite_diagram_control.dart` 不存在）。

- [ ] **Step 3: 写最小实现**

`lib/controls/satellite_diagram_control.dart`:

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:pdf/widgets.dart' as pw;

import '../model/cell.dart';
import '../model/pin.dart';
import '../services/image_service.dart';
import '../services/location_service.dart';
import 'control_spec.dart';

/// The screen's return value: updated pins + camera state + the saved PNG path.
typedef SatelliteResult = ({
  List<Pin> pins,
  LatLng center,
  double zoom,
  String path,
});

// ---- Pure value-parsing helpers (the stored value is a JSON-safe Map). ----

Map<String, dynamic>? _asMap(Object? v) =>
    v is Map ? v.cast<String, dynamic>() : null;

/// The screenshot path inside a stored diagram value, or null if absent/empty.
String? diagramPath(Object? v) {
  final p = _asMap(v)?['path'];
  return p is String && p.isNotEmpty ? p : null;
}

/// The pins inside a stored diagram value; malformed entries are skipped.
List<Pin> diagramPins(Object? v) {
  final raw = _asMap(v)?['pins'];
  if (raw is! List) return const [];
  final out = <Pin>[];
  for (final e in raw) {
    if (e is Map && e['lat'] is num && e['lon'] is num) {
      out.add(Pin(
        lat: (e['lat'] as num).toDouble(),
        lon: (e['lon'] as num).toDouble(),
        label: e['label'] is String ? e['label'] as String : '',
      ));
    }
  }
  return out;
}

/// The saved map center, or null if absent/malformed (→ caller seeds via GPS).
LatLng? diagramCenter(Object? v) {
  final c = _asMap(v)?['center'];
  if (c is! Map) return null;
  final lat = c['lat'];
  final lon = c['lon'];
  return lat is num && lon is num
      ? LatLng(lat.toDouble(), lon.toDouble())
      : null;
}

/// The saved zoom, defaulting to 17 when absent/malformed.
double diagramZoom(Object? v) {
  final z = _asMap(v)?['zoom'];
  return z is num ? z.toDouble() : 17.0;
}

/// A satellite-map diagram control. Fill mode opens a full-screen map to drop
/// pins and capture a screenshot; the value is a Map {path, pins, center, zoom}.
/// PDF embeds the screenshot (bytes resolved via [resolvePdfValue]) plus an
/// optional caption. Supports clear (set value to null) for re-measuring.
class SatelliteDiagramControl extends ControlSpec {
  /// Injected so first-fill can center on the device's current GPS. Null → the
  /// map falls back to a fixed center (tests / non-device).
  final LocationService? location;

  /// Injected so the captured screenshot can be persisted via [ImageService
  /// .saveBytes]. Null → opening the map is a no-op (tests / non-device).
  final ImageService? image;

  SatelliteDiagramControl({this.location, this.image});

  @override
  String get type => 'satelliteDiagram';
  @override
  String get label => 'Satellite Diagram';
  @override
  IconData get icon => Icons.map_outlined;
  @override
  Map<String, dynamic> defaultProps() => {'key': 'diagram', 'caption': ''};

  @override
  String? validate(Cell cell, Object? value) => null; // empty is legal

  @override
  Future<Object?> resolvePdfValue(Cell cell, Object? value) async {
    final path = diagramPath(value);
    if (path == null) return null;
    final f = File(path);
    if (!await f.exists()) return null;
    return f.readAsBytes();
  }

  @override
  pw.Widget paintPdf(Cell cell, Map<String, dynamic> data) {
    final v = data[cell.props['key']];
    if (v is! Uint8List) return pw.SizedBox();
    pw.Widget img;
    try {
      img = pw.Image(pw.MemoryImage(v), fit: pw.BoxFit.contain);
    } catch (e) {
      debugPrint('[SatelliteDiagramControl] paintPdf: corrupt image bytes — $e');
      return pw.SizedBox();
    }
    final caption = (cell.props['caption'] as String?)?.trim() ?? '';
    if (caption.isEmpty) return img;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Expanded(child: img),
        pw.Text(caption,
            style: const pw.TextStyle(fontSize: 8),
            textAlign: pw.TextAlign.center),
      ],
    );
  }

  @override
  Widget previewWidget(Cell cell) => Container(
        alignment: Alignment.center,
        child: const Text('[satellite]',
            style: TextStyle(fontSize: 9, color: Color(0xFF9A9A9A))),
      );
}
```

- [ ] **Step 4: 运行确认通过 + 分析**

Run: `flutter test test/controls/satellite_diagram_control_test.dart`
Expected: All tests passed!
Run: `flutter analyze`
Expected: No issues found!

- [ ] **Step 5: Commit**

```bash
git add lib/controls/satellite_diagram_control.dart test/controls/satellite_diagram_control_test.dart
git commit -m "feat(controls): SatelliteDiagramControl core — parse/validate/pdf (TDD)"
```

---

### Task 5: `SatelliteDiagramScreen` 全屏地图屏（device-only 移植）

移植旧 `app/lib/screens/site_diagram_screen.dart`，解耦 `Site`/DB，改纯输入输出 + `MapController` 读相机状态。依赖 flutter_map / screenshot / geolocator 平台通道，**不写自动化测试**，gate = `flutter analyze` 干净 + Task 8 真机走查。

**Files:**
- Create: `lib/fill/satellite_diagram_screen.dart`

**Interfaces:**
- Consumes: `Pin`、`LocationService`、`SatelliteResult`（来自 `satellite_diagram_control.dart`）、`LatLng`、flutter_map、screenshot。
- Produces: `class SatelliteDiagramScreen extends StatefulWidget`，构造参数 `{required List<Pin> initialPins, LatLng? initialCenter, double initialZoom = 17, LocationService? location, required Future<String> Function(Uint8List) saveBytes}`；`Navigator.pop` 返回 `SatelliteResult?`（取消为 null）。

- [ ] **Step 1: 写实现**

`lib/fill/satellite_diagram_screen.dart`:

```dart
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:screenshot/screenshot.dart';

import '../controls/satellite_diagram_control.dart';
import '../model/pin.dart';
import '../services/location_service.dart';

/// Esri World Imagery — free satellite tiles, no API key (attribution required).
const String _esriUrl =
    'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';

const LatLng _fallbackCenter = LatLng(40.0759, 20.1389); // Gjirokastër

/// Full-screen satellite map for dropping pins and capturing a screenshot.
/// Self-contained (no Site/DB): takes initial pins/center/zoom, returns updated
/// pins + camera state + saved PNG path via [Navigator.pop]. device-only — not
/// covered by widget tests (flutter_map/screenshot/geolocator platform channels
/// are unavailable in the unit-test VM).
class SatelliteDiagramScreen extends StatefulWidget {
  final List<Pin> initialPins;
  final LatLng? initialCenter;
  final double initialZoom;
  final LocationService? location;
  final Future<String> Function(Uint8List bytes) saveBytes;

  const SatelliteDiagramScreen({
    super.key,
    required this.initialPins,
    this.initialCenter,
    this.initialZoom = 17,
    this.location,
    required this.saveBytes,
  });

  @override
  State<SatelliteDiagramScreen> createState() => _SatelliteDiagramScreenState();
}

class _SatelliteDiagramScreenState extends State<SatelliteDiagramScreen> {
  final _screenshotController = ScreenshotController();
  final _mapController = MapController();
  late List<Pin> _pins;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _pins = List.of(widget.initialPins);
    if (widget.initialCenter == null) _seedFromGps();
  }

  /// First-fill only: recenter on the device's current position once available.
  Future<void> _seedFromGps() async {
    final svc = widget.location;
    if (svc == null) return;
    final res = await svc.getCoordinate();
    if (!mounted || !res.ok) return;
    _mapController.move(LatLng(res.lat!, res.lon!), widget.initialZoom);
  }

  void _addPin(LatLng pos) {
    setState(() => _pins = [..._pins, Pin(lat: pos.latitude, lon: pos.longitude)]);
  }

  Future<void> _editPin(int index) async {
    final ctrl = TextEditingController(text: _pins[index].label);
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pin'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Label (optional)'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, 'delete'),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
          TextButton(
              onPressed: () => Navigator.pop(context, 'cancel'),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, 'ok'),
              child: const Text('OK')),
        ],
      ),
    );
    if (action == 'delete') {
      setState(() => _pins = [..._pins]..removeAt(index));
    } else if (action == 'ok') {
      setState(() {
        final list = [..._pins];
        list[index] = list[index].copyWith(label: ctrl.text.trim());
        _pins = list;
      });
    }
  }

  Future<void> _saveAndExit() async {
    setState(() => _saving = true);
    Uint8List? bytes;
    try {
      bytes = await _screenshotController.capture(
          delay: const Duration(milliseconds: 250));
    } catch (_) {
      bytes = null;
    }
    if (bytes == null) {
      if (mounted) setState(() => _saving = false);
      return;
    }
    final path = await widget.saveBytes(bytes);
    if (!mounted) return;
    final cam = _mapController.camera;
    Navigator.pop<SatelliteResult>(context,
        (pins: _pins, center: cam.center, zoom: cam.zoom, path: path));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Satellite Diagram'),
        actions: [
          _saving
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : IconButton(
                  icon: const Icon(Icons.save_outlined),
                  tooltip: 'Save snapshot',
                  onPressed: _saveAndExit,
                ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.black87,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            child: const Text(
              'Tap map to drop a pin · tap a pin to edit/delete · Save to snapshot.',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          Expanded(
            child: Screenshot(
              controller: _screenshotController,
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: widget.initialCenter ?? _fallbackCenter,
                  initialZoom: widget.initialZoom,
                  onTap: (_, latlng) => _addPin(latlng),
                ),
                children: [
                  TileLayer(
                    urlTemplate: _esriUrl,
                    userAgentPackageName: 'com.scss.scss',
                    maxNativeZoom: 19,
                  ),
                  MarkerLayer(
                    markers: [
                      for (int i = 0; i < _pins.length; i++)
                        Marker(
                          point: LatLng(_pins[i].lat, _pins[i].lon),
                          width: 120,
                          height: 60,
                          alignment: Alignment.topCenter,
                          child: GestureDetector(
                            onTap: () => _editPin(i),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.location_on,
                                    color: Colors.red, size: 36),
                                if (_pins[i].label.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4),
                                    color: Colors.white70,
                                    child: Text(_pins[i].label,
                                        style: const TextStyle(fontSize: 10)),
                                  ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: 静态分析（替代单测的 gate）**

Run: `flutter analyze`
Expected: No issues found!（确认 flutter_map 8.x API：`MapController().camera.center/.zoom`、`MapOptions.initialCenter/initialZoom`、`TileLayer.urlTemplate` 均存在。若 8.x API 有差异，按分析报错就地修正——这是移植唯一可能踩的点。）

- [ ] **Step 3: Commit**

```bash
git add lib/fill/satellite_diagram_screen.dart
git commit -m "feat(fill): SatelliteDiagramScreen — map+pins+screenshot, decoupled (device-only)"
```

---

### Task 6: 控件交互 UI（`fillWidget` + `propEditor`）

给 `SatelliteDiagramControl` 加填写控件（缩略图 + 清除 / 开地图按钮，push Task 5 的屏）和属性编辑器（key + caption）。可测部分：无值显示开图按钮、有值显示缩略图 + 清除、点清除 → `onChanged(null)`、propEditor 改 key/caption 触发回调。`image==null` 时开图为 no-op（便于测试，不真的 push）。

**Files:**
- Modify: `lib/controls/satellite_diagram_control.dart`
- Modify: `test/controls/satellite_diagram_control_test.dart`（追加 widget 测试）

**Interfaces:**
- Consumes: `SatelliteDiagramScreen`（`lib/fill/satellite_diagram_screen.dart`）、解析函数（已在本文件）。
- Produces: override `Widget fillWidget(...)`、`Widget propEditor(...)`；私有 `_SatelliteField`。

- [ ] **Step 1: 追加失败测试**

在 `test/controls/satellite_diagram_control_test.dart` 顶部补 import：

```dart
import 'package:flutter/material.dart';
```

在 `main()` 末尾追加：

```dart
  Widget host(Widget child) => MaterialApp(
      home: Scaffold(
          body: SizedBox(width: 200, height: 200, child: child)));

  testWidgets('fillWidget: no value → shows open-map button, no clear',
      (tester) async {
    await tester.pumpWidget(host(
        SatelliteDiagramControl().fillWidget(_cell, null, (_) {})));
    expect(find.byKey(const ValueKey('satellite-open')), findsOneWidget);
    expect(find.byKey(const ValueKey('satellite-clear')), findsNothing);
  });

  testWidgets('fillWidget: with value → shows thumbnail + clear that clears',
      (tester) async {
    Object? captured = 'unset';
    await tester.pumpWidget(host(SatelliteDiagramControl()
        .fillWidget(_cell, {'path': '/nonexistent.png'}, (v) => captured = v)));
    expect(find.byKey(const ValueKey('satellite-clear')), findsOneWidget);
    expect(find.byKey(const ValueKey('satellite-open')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('satellite-clear')));
    await tester.pump();
    expect(captured, isNull);
  });

  testWidgets('propEditor edits key and caption', (tester) async {
    Map<String, dynamic>? props;
    await tester.pumpWidget(host(
        SatelliteDiagramControl().propEditor(_cell, (p) => props = p)));
    await tester.enterText(
        find.byKey(const ValueKey('satellite-key')), 'diag2');
    expect(props!['key'], 'diag2');
    await tester.enterText(
        find.byKey(const ValueKey('satellite-caption')), 'Pole row');
    expect(props!['caption'], 'Pole row');
  });
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/controls/satellite_diagram_control_test.dart`
Expected: FAIL（fillWidget 当前是 ControlSpec 默认 = previewWidget，找不到 `satellite-open`；propEditor 默认空）。

- [ ] **Step 3: 写实现**

在 `satellite_diagram_control.dart` 顶部加 import：

```dart
import '../fill/satellite_diagram_screen.dart';
```

在 `SatelliteDiagramControl` 类内（`previewWidget` 之后）加 override：

```dart
  @override
  Widget propEditor(
      Cell cell, void Function(Map<String, dynamic> props) onChanged) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          key: const ValueKey('satellite-key'),
          initialValue: (cell.props['key'] as String?) ?? '',
          decoration: const InputDecoration(labelText: 'Key'),
          onChanged: (v) => onChanged({...cell.props, 'key': v}),
        ),
        const SizedBox(height: 8),
        TextFormField(
          key: const ValueKey('satellite-caption'),
          initialValue: (cell.props['caption'] as String?) ?? '',
          decoration: const InputDecoration(labelText: 'Caption'),
          onChanged: (v) => onChanged({...cell.props, 'caption': v}),
        ),
      ],
    );
  }

  @override
  Widget fillWidget(
          Cell cell, Object? value, void Function(Object? value) onChanged) =>
      _SatelliteField(
        location: location,
        image: image,
        path: diagramPath(value),
        pins: diagramPins(value),
        center: diagramCenter(value),
        zoom: diagramZoom(value),
        onChanged: onChanged,
      );
```

在文件末尾（类外）加私有控件：

```dart
/// Fill-mode widget: a screenshot thumbnail with a clear button, or an
/// open-map button when empty. Opening pushes [SatelliteDiagramScreen] and
/// stores its result as the diagram value Map.
class _SatelliteField extends StatelessWidget {
  final LocationService? location;
  final ImageService? image;
  final String? path;
  final List<Pin> pins;
  final LatLng? center;
  final double zoom;
  final void Function(Object? value) onChanged;

  const _SatelliteField({
    required this.location,
    required this.image,
    required this.path,
    required this.pins,
    required this.center,
    required this.zoom,
    required this.onChanged,
  });

  Future<void> _openMap(BuildContext context) async {
    final svc = image;
    if (svc == null) return; // tests / non-device no-op
    final result = await Navigator.of(context).push<SatelliteResult>(
      MaterialPageRoute(
        builder: (_) => SatelliteDiagramScreen(
          initialPins: pins,
          initialCenter: center,
          initialZoom: zoom,
          location: location,
          saveBytes: (bytes) => svc.saveBytes(bytes),
        ),
      ),
    );
    if (result == null) return;
    onChanged({
      'path': result.path,
      'pins': [for (final p in result.pins) p.toJson()],
      'center': {'lat': result.center.latitude, 'lon': result.center.longitude},
      'zoom': result.zoom,
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = path;
    if (p != null && p.isNotEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.file(File(p), fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  const Center(child: Icon(Icons.broken_image, size: 16))),
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              key: const ValueKey('satellite-clear'),
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
        key: const ValueKey('satellite-open'),
        iconSize: 20,
        tooltip: 'Open map',
        icon: const Icon(Icons.add_location_alt_outlined),
        onPressed: () => _openMap(context),
      ),
    );
  }
}
```

- [ ] **Step 4: 运行确认通过 + 分析**

Run: `flutter test test/controls/satellite_diagram_control_test.dart`
Expected: All tests passed!
Run: `flutter analyze`
Expected: No issues found!

- [ ] **Step 5: Commit**

```bash
git add lib/controls/satellite_diagram_control.dart test/controls/satellite_diagram_control_test.dart
git commit -m "feat(controls): SatelliteDiagramControl fill UI + propEditor (TDD)"
```

---

### Task 7: 注册接线（default_controls + 类型集合测试）

把控件登记进默认注册表，复用已注入的 `location`/`image`。`main.dart` 已以 `buildDefaultRegistry(location:..., image:...)` 接线（Phase 3a/3b 已注入），无需改动——本任务仅确认其传参齐全。

**Files:**
- Modify: `lib/controls/default_controls.dart`
- Modify: `test/controls/default_controls_test.dart`
- Verify (read-only): `lib/main.dart`（确认 `buildDefaultRegistry` 调用已传 `location` 与 `image`）

**Interfaces:**
- Consumes: `SatelliteDiagramControl`（`lib/controls/satellite_diagram_control.dart`）。
- Produces: `buildDefaultRegistry` 注册集合含 `'satelliteDiagram'`。

- [ ] **Step 1: 改失败测试**

在 `test/controls/default_controls_test.dart`：第一个 test 的断言列表加一行 `expect(r.specFor('satelliteDiagram'), isNotNull);`；第二个 test 的期望集合加 `'satelliteDiagram'`；并追加：

```dart
  test('satelliteDiagram defaultProps has key/caption', () {
    final r = buildDefaultRegistry();
    final p = r.specFor('satelliteDiagram')!.defaultProps();
    expect(p['key'], 'diagram');
    expect(p['caption'], '');
  });
```

期望集合改为：

```dart
    expect(types, {
      'title',
      'label',
      'text',
      'number',
      'coordinate',
      'image',
      'multiImage',
      'satelliteDiagram',
    });
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/controls/default_controls_test.dart`
Expected: FAIL（`specFor('satelliteDiagram')` 为 null；类型集合不含它）。

- [ ] **Step 3: 写实现**

在 `lib/controls/default_controls.dart` 加 import 与注册行：

```dart
import 'satellite_diagram_control.dart';
```

在 `r.register(MultiImageControl(image: image));` 之后加：

```dart
  r.register(SatelliteDiagramControl(location: location, image: image));
```

- [ ] **Step 4: 运行确认通过 + 全量回归**

Run: `flutter test test/controls/default_controls_test.dart`
Expected: All tests passed!
Run: `flutter test`
Expected: All tests passed!（全量绿，确认无回归）
Run: `flutter analyze`
Expected: No issues found!

- [ ] **Step 5: 确认 main.dart 接线齐全**

Read `lib/main.dart`，确认 `buildDefaultRegistry(...)` 调用已同时传 `location:` 与 `image:`（Phase 3a 传 location、3b 传 image）。若缺 `location`，补上 `location:` 实参（注入已存在的 `GeolocatorLocationService`）。仅在缺参时改动并 `flutter analyze`。

- [ ] **Step 6: Commit**

```bash
git add lib/controls/default_controls.dart test/controls/default_controls_test.dart lib/main.dart
git commit -m "feat(controls): register SatelliteDiagramControl (TDD)"
```

---

### Task 8: 真机验收走查（无自动化）

Android 权限：地图瓦片需网络（`INTERNET` 默认有）；GPS 定心需定位权限（Phase 3a 已配 `ACCESS_FINE_LOCATION`）；截图落盘走应用私有目录（无需额外权限）。确认 `AndroidManifest.xml` 已含上述权限，缺则补。

**Files:**
- Verify: `android/app/src/main/AndroidManifest.xml`（`INTERNET` + `ACCESS_FINE_LOCATION`）

- [ ] **Step 1: 构建并装机**

Run（真机三星 SM-A528B，adb 绝对路径）：
`flutter run -d <device-id>`
（adb：`/Users/xxf/Library/Android/sdk/platform-tools/adb devices` 取 device-id。）

- [ ] **Step 2: 建模式走查**

- [ ] 调色板能加入 satelliteDiagram 格（图标 `map_outlined`、label "Satellite Diagram"）。
- [ ] 检视器能改 Key 与 Caption。
- [ ] 空图 PDF 预览：该格为空（占位无异常）。

- [ ] **Step 3: 填写式走查**

- [ ] 点该格 → 全屏地图打开；首填时定位到当前 GPS（或无定位时落兜底中心）。
- [ ] 点地图空白 → 落红钉；点钉 → 弹框填标签（如 P1）/ 删除；标签显示在钉下方。
- [ ] 顶部保存 → 回到表单，格内显示截图缩略图。
- [ ] ✕ 清除 → 缩略图消失、回到开地图按钮。
- [ ] 重新打开地图 → 能看到上次的钉与中心/缩放（验证 pins/center/zoom 持久化往返）。

- [ ] **Step 4: PDF 导出走查**

- [ ] 截图嵌入该格、`fit:contain` 不变形。
- [ ] caption 非空时图下方显示标题；为空时不显示。

- [ ] **Step 5: 离线走查**

- [ ] 关网络：瓦片可能不加载，但仍能落钉、保存（用已缓存/灰底），保存的截图照常进 PDF。

- [ ] **Step 6: 记录结果**

把验收结果（含设备型号、通过/未过项）记入 `doc/PROGRESS.md` 与本插件 memory；如有视觉问题（如截图时序导致瓦片未画全），在计划末尾追加修复任务再迭代。

---

## Self-Review

**Spec coverage（逐条对照 spec）**
- 值形态 {path,pins,center,zoom} → Task 4 解析函数 + Task 6 fillWidget 写回。✅
- 钉带标签 + 改/删 → Task 5 `_editPin`。✅
- caption 画进 PDF → Task 4 `paintPdf`。✅
- 去离线橙条 → Task 5 无 connectivity。✅
- 截图 `screenshot` 包 capture(delay) → Task 5。✅
- 初始中心 GPS/兜底 → Task 5 `_seedFromGps` + `_fallbackCenter`。✅
- 清除 = onChanged(null) → Task 6 clear 按钮。✅ 空值合法 → Task 4 validate。✅
- ImageService.saveBytes → Task 3。✅
- Pin 模型移植 → Task 2。✅
- 3 依赖 + 风险点 0 → Task 1。✅
- 注册 1 行 + 接线 → Task 7。✅
- 测试分层（纯逻辑单测 + 真机验收）→ Task 2/3/4/6 单测、Task 5/8 device-only。✅
- 文件清单 7 项 → 全覆盖。✅

**Placeholder scan**：无 TBD/TODO；每个代码步骤均含完整代码。✅

**Type consistency**：`SatelliteResult` 记录字段（pins/center/zoom/path）在 Task 4 定义、Task 5 `Navigator.pop<SatelliteResult>` 构造、Task 6 `_openMap` 解构，三处一致；`saveBytes(Uint8List, {String ext})` 在 Task 3 定义、Task 5 回调签名 `Future<String> Function(Uint8List)`（可接收带可选命名参的 tear-off）、Task 6 `(bytes) => svc.saveBytes(bytes)` 一致；解析函数名 `diagramPath/diagramPins/diagramCenter/diagramZoom` 在 Task 4 定义、Task 6 使用，一致。✅
```
