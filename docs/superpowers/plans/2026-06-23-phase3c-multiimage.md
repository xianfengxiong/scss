# Phase 3c — MultiImage 多图控件 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 新增 `MultiImageControl`（type `multiImage`），让一个网格格子放多张照片，PDF 与填写预览按"列数恒定、行高均分铺满"布局。

**Architecture:** 复用现有 `ImageService.capture()` 逐张拍照/压缩/落盘；值存 `List<String>` 路径。控件仿 `ImageControl` 形状，override `validate`/`resolvePdfValue`/`paintPdf`/`fillWidget`/`propEditor`。PDF 异步管线（`resolvePdfData`→`resolvePdfValue`→`paintPdf`）和 fill 核心流程（`fill_canvas`）结构不变。

**Tech Stack:** Flutter / Dart，`flutter_test`（手写 fake，无 mockito），`pdf`（`pw.*`），`image_picker`（`ImageSource` 枚举），包名 `package:scss_grid`。

## Global Constraints

- 所有 `flutter` / `git` 命令在 `grid_app/` 目录下执行（pubspec 所在目录）。
- 复用 `ImageService` / `ImagePickerImageService`，**不改动** `lib/services/image_service.dart`。
- 值类型：`data[key]` 存 `List<String>`（路径列表）；空为 `null`。
- 布局：**列数恒定 = `cols`**；实际行数 = `ceil(张数/cols)`；行高 = `cellHeight/实际行数`（均分铺满，空行不占高度）；末行不满右侧留白；图片 `BoxFit.contain`。
- 容量 `max = rows × cols`（不单独配）；`min` 单独配；`defaultProps` = `{'key':'images','rows':2,'cols':3,'min':3}`。
- 不做 caption。
- 测试不依赖平台通道：用 `Directory.systemTemp` 做真实文件 IO 没问题；`ImagePickerImageService` 仍只在真机验收（Task 7）。

---

## File Structure

- `lib/controls/multi_image_control.dart` — **新建**。顶层函数 `rowsForCount`、`MultiImageControl`（ControlSpec 子类）、私有 `_MultiImageField`（填写控件）。一个文件一个控件，与 `image_control.dart` 对齐。
- `lib/controls/default_controls.dart` — **改**。注册一行。
- `test/controls/multi_image_control_test.dart` — **新建**。控件全部行为测试。
- `test/controls/default_controls_test.dart` — **改**。类型集合 + defaultProps 断言。

---

### Task 1: 控件元数据 + `validate` + `rowsForCount`（纯逻辑，无 UI override）

**Files:**
- Create: `lib/controls/multi_image_control.dart`
- Test: `test/controls/multi_image_control_test.dart`

**Interfaces:**
- Produces: 顶层 `int rowsForCount(int count, int cols)`；类 `MultiImageControl extends ControlSpec`（`MultiImageControl({ImageService? image})`，`type=='multiImage'`，`defaultProps()=={'key':'images','rows':2,'cols':3,'min':3}`，`String? validate(Cell, Object?)`）。
- Consumes: `ControlSpec`（`lib/controls/control_spec.dart`）、`Cell`（`lib/model/cell.dart`）、`ImageService`（`lib/services/image_service.dart`）。

- [ ] **Step 1: 写失败测试**

新建 `test/controls/multi_image_control_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/controls/multi_image_control.dart';
import 'package:scss_grid/model/cell.dart';

Cell _cell({int rows = 2, int cols = 3, int min = 3}) => Cell(
      id: 'm',
      col: 0,
      row: 0,
      colSpan: 6,
      rowSpan: 4,
      type: 'multiImage',
      props: {'key': 'photos', 'rows': rows, 'cols': cols, 'min': min},
    );

void main() {
  test('rowsForCount = ceil(count/cols), 0 → 0', () {
    expect(rowsForCount(0, 3), 0);
    expect(rowsForCount(1, 3), 1);
    expect(rowsForCount(3, 3), 1); // 第二行全空 → 1 行（占满整高）
    expect(rowsForCount(4, 3), 2); // 进入第二行 → 2 行
    expect(rowsForCount(6, 3), 2);
  });

  test('type, defaultProps, dataKey', () {
    final c = MultiImageControl();
    expect(c.type, 'multiImage');
    expect(c.defaultProps(),
        {'key': 'images', 'rows': 2, 'cols': 3, 'min': 3});
    expect(c.dataKey(_cell()), 'photos');
  });

  test('validate: <min, in-range, >cap', () {
    final c = MultiImageControl();
    expect(c.validate(_cell(), null), '至少 3 张，当前 0');
    expect(c.validate(_cell(), ['a', 'b']), '至少 3 张，当前 2');
    expect(c.validate(_cell(), ['a', 'b', 'c']), isNull);
    expect(c.validate(_cell(), ['a', 'b', 'c', 'd', 'e', 'f']), isNull);
    expect(c.validate(_cell(), ['a', 'b', 'c', 'd', 'e', 'f', 'g']),
        '最多 6 张，当前 7'); // cap = rows2*cols3 = 6
  });
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `flutter test test/controls/multi_image_control_test.dart`
Expected: FAIL —— `Error: Couldn't resolve the package 'scss_grid' ... multi_image_control.dart` / `MultiImageControl` 未定义。

- [ ] **Step 3: 写最小实现**

新建 `lib/controls/multi_image_control.dart`：

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/widgets.dart' as pw;

import '../model/cell.dart';
import '../services/image_service.dart';
import 'control_spec.dart';

/// Grid rows needed to show [count] images in [cols] columns.
/// 0 → 0; otherwise ceil(count / cols). Row height = cellHeight / this, so
/// 3 imgs in 3 cols → 1 row (fills full height); 4 imgs → 2 rows (each half).
int rowsForCount(int count, int cols) =>
    count <= 0 ? 0 : (count + cols - 1) ~/ cols;

/// A multi-photo value control. Value is a List of file paths. Fill mode shows
/// a fixed-column thumbnail grid with per-photo clear and an add button (hidden
/// at capacity). PDF embeds photos in a fixed-column grid whose rows split the
/// cell height evenly.
class MultiImageControl extends ControlSpec {
  /// Injected by the registry so fill mode can capture photos. Null → add is a
  /// no-op (tests / non-device).
  final ImageService? image;

  MultiImageControl({this.image});

  @override
  String get type => 'multiImage';
  @override
  String get label => 'Multi Image';
  @override
  IconData get icon => Icons.photo_library_outlined;
  @override
  Map<String, dynamic> defaultProps() =>
      {'key': 'images', 'rows': 2, 'cols': 3, 'min': 3};

  int _rows(Cell c) => (c.props['rows'] as num?)?.toInt() ?? 2;
  int _cols(Cell c) => (c.props['cols'] as num?)?.toInt() ?? 3;
  int _min(Cell c) => (c.props['min'] as num?)?.toInt() ?? 0;
  int _cap(Cell c) => _rows(c) * _cols(c);

  /// Normalize a fill value into a list of path strings.
  static List<String> _paths(Object? v) =>
      v is List ? v.whereType<String>().toList() : const <String>[];

  @override
  String? validate(Cell cell, Object? value) {
    final count = _paths(value).length;
    final min = _min(cell);
    final cap = _cap(cell);
    if (count < min) return '至少 $min 张，当前 $count';
    if (count > cap) return '最多 $cap 张，当前 $count';
    return null;
  }

  @override
  pw.Widget paintPdf(Cell cell, Map<String, dynamic> data) => pw.SizedBox();
}
```

（`paintPdf` 此步为占位，Task 3 实现真实网格；`resolvePdfValue`/`fillWidget`/`propEditor` 暂用基类默认，后续任务 override。`dart:io`/`dart:typed_data`/`material`/`image_picker`/`pw` 已导入供后续任务用 —— 若本步因未用 import 报 lint 警告，不影响测试通过；Task 2/3/4 会用到它们。）

- [ ] **Step 4: 跑测试确认通过**

Run: `flutter test test/controls/multi_image_control_test.dart`
Expected: PASS（3 个测试全绿）。

- [ ] **Step 5: 提交**

```bash
git add grid_app/lib/controls/multi_image_control.dart grid_app/test/controls/multi_image_control_test.dart
git commit -m "feat(controls): MultiImageControl 元数据 + validate + rowsForCount"
```

---

### Task 2: `resolvePdfValue`（路径列表 → 字节列表，过滤缺失）

**Files:**
- Modify: `lib/controls/multi_image_control.dart`
- Test: `test/controls/multi_image_control_test.dart`

**Interfaces:**
- Produces: `Future<Object?> resolvePdfValue(Cell, Object?)` —— 返回 `List<Uint8List>`（过滤掉空/不存在/读不出的路径）；全无有效图 → `null`。
- Consumes: `MultiImageControl._paths`（Task 1）。

- [ ] **Step 1: 写失败测试**

在 `test/controls/multi_image_control_test.dart` 的 `main()` 末尾加：

```dart
  test('resolvePdfValue: paths → bytes, missing filtered, empty → null',
      () async {
    final c = MultiImageControl();
    final dir = Directory.systemTemp.createTempSync('mi_test');
    addTearDown(() => dir.deleteSync(recursive: true));
    final a = File('${dir.path}/a.bin')..writeAsBytesSync([1, 2, 3]);
    final b = File('${dir.path}/b.bin')..writeAsBytesSync([4, 5]);

    final out = await c.resolvePdfValue(
        _cell(), [a.path, '${dir.path}/missing.bin', b.path]);
    expect(out, isA<List<Uint8List>>());
    final list = out as List<Uint8List>;
    expect(list.length, 2); // missing filtered out
    expect(list[0], [1, 2, 3]);
    expect(list[1], [4, 5]);

    expect(await c.resolvePdfValue(_cell(), <String>[]), isNull);
    expect(await c.resolvePdfValue(_cell(), null), isNull);
    expect(await c.resolvePdfValue(_cell(), ['${dir.path}/none.bin']), isNull);
  });
```

确保文件顶部已 `import 'dart:io';` 和 `import 'dart:typed_data';`（若缺则补在 import 区）。

- [ ] **Step 2: 跑测试确认失败**

Run: `flutter test test/controls/multi_image_control_test.dart`
Expected: FAIL —— 基类 `resolvePdfValue` 是 identity，返回原 list 而非 `List<Uint8List>`，`isA<List<Uint8List>>()` 不满足 / 长度断言失败。

- [ ] **Step 3: 写实现**

在 `MultiImageControl` 内 `validate` 之后加 override：

```dart
  @override
  Future<Object?> resolvePdfValue(Cell cell, Object? value) async {
    final out = <Uint8List>[];
    for (final path in _paths(value)) {
      if (path.isEmpty) continue;
      final f = File(path);
      if (!await f.exists()) continue;
      out.add(await f.readAsBytes());
    }
    return out.isEmpty ? null : out;
  }
```

- [ ] **Step 4: 跑测试确认通过**

Run: `flutter test test/controls/multi_image_control_test.dart`
Expected: PASS（4 个测试全绿）。

- [ ] **Step 5: 提交**

```bash
git add grid_app/lib/controls/multi_image_control.dart grid_app/test/controls/multi_image_control_test.dart
git commit -m "feat(controls): MultiImageControl.resolvePdfValue 路径列表→字节列表"
```

---

### Task 3: `paintPdf` 固定列网格（行高均分铺满）

**Files:**
- Modify: `lib/controls/multi_image_control.dart`
- Test: `test/controls/multi_image_control_test.dart`

**Interfaces:**
- Produces: `pw.Widget paintPdf(Cell, Map)` —— `List<Uint8List>` → `pw.Column`（`rowsForCount` 个等高 `pw.Expanded` 行，每行 `cols` 个等宽 `pw.Expanded` 槽，按行优先填图，多余槽 `pw.SizedBox`）；空/非 list → `pw.SizedBox`；单张损坏 try/catch 跳过。
- Consumes: `rowsForCount`（Task 1）。

- [ ] **Step 1: 写失败测试**

在测试文件 `main()` 末尾加：

```dart
  test('paintPdf tolerates empty / bytes / non-bytes (renders without throwing)',
      () {
    final c = MultiImageControl();
    // empty list → blank, no throw
    expect(() => c.paintPdf(_cell(), const {'photos': <Uint8List>[]}),
        returnsNormally);
    // unresolved path strings (not bytes) → must not throw
    expect(() => c.paintPdf(_cell(), const {'photos': ['/x.jpg']}),
        returnsNormally);
    // resolved bytes (half-full last row: 4 imgs in 3 cols → 2 rows)
    final four = List.generate(4, (_) => Uint8List.fromList(const [1, 2, 3]));
    expect(() => c.paintPdf(_cell(), {'photos': four}), returnsNormally);
    // single image (fills full height)
    expect(
        () => c.paintPdf(
            _cell(), {'photos': [Uint8List.fromList(const [9])]}),
        returnsNormally);
  });
```

- [ ] **Step 2: 跑测试确认失败**

Run: `flutter test test/controls/multi_image_control_test.dart`
Expected: 实际上占位 `paintPdf` 返回 `pw.SizedBox` 不抛 → 这些 `returnsNormally` 可能已 PASS。**这是预期的**：本任务的测试是回归保护，真正的行为变化（多图网格）靠 Task 7 真机 PDF 验收。仍先跑一次记录基线，再实现，确保实现后仍 PASS。

- [ ] **Step 3: 写实现**

把 Task 1 的占位 `paintPdf` 替换为：

```dart
  @override
  pw.Widget paintPdf(Cell cell, Map<String, dynamic> data) {
    final v = data[cell.props['key']];
    final bytes =
        v is List ? v.whereType<Uint8List>().toList() : const <Uint8List>[];
    if (bytes.isEmpty) return pw.SizedBox();
    final cols = _cols(cell);
    final rowCount = rowsForCount(bytes.length, cols);
    return pw.Column(
      children: [
        for (var r = 0; r < rowCount; r++)
          pw.Expanded(
            child: pw.Row(
              children: [
                for (var col = 0; col < cols; col++)
                  pw.Expanded(child: _pdfCell(bytes, r * cols + col)),
              ],
            ),
          ),
      ],
    );
  }

  pw.Widget _pdfCell(List<Uint8List> bytes, int i) {
    if (i >= bytes.length) return pw.SizedBox(); // 末行不满 → 留白
    try {
      return pw.Image(pw.MemoryImage(bytes[i]), fit: pw.BoxFit.contain);
    } catch (e) {
      debugPrint('[MultiImageControl] paintPdf: corrupt image bytes — $e');
      return pw.SizedBox();
    }
  }
```

- [ ] **Step 4: 跑测试确认通过**

Run: `flutter test test/controls/multi_image_control_test.dart`
Expected: PASS（5 个测试全绿）。

- [ ] **Step 5: 提交**

```bash
git add grid_app/lib/controls/multi_image_control.dart grid_app/test/controls/multi_image_control_test.dart
git commit -m "feat(controls): MultiImageControl.paintPdf 固定列网格行高均分"
```

---

### Task 4: `fillWidget` / `_MultiImageField`（缩略图 + 单张清除 + 追加 + 内联红字）

**Files:**
- Modify: `lib/controls/multi_image_control.dart`
- Test: `test/controls/multi_image_control_test.dart`

**Interfaces:**
- Produces: `Widget fillWidget(Cell, Object?, void Function(Object?))` → `_MultiImageField`。Key 约定：add 按钮 `ValueKey('multi-image-add')`；第 i 张清除按钮 `ValueKey('multi-image-clear-$i')`。清除 → `onChanged(移除后的 list，空则 null)`；追加 → `onChanged([...旧, 新path])`；`count >= cap` 隐藏 add；`validate` 非空 → 底部红字。
- Consumes: `ImageService.capture(ImageSource)`、`MultiImageControl._paths`/`_cols`/`_cap`/`validate`（Task 1）。

- [ ] **Step 1: 写失败测试**

测试文件顶部 import 区补充（若缺）：

```dart
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:scss_grid/services/image_service.dart';
```

在 `_cell` 之后加 fake + host：

```dart
class _FakeImage implements ImageService {
  final String? path;
  _FakeImage(this.path);
  @override
  Future<String?> capture(ImageSource source) async => path;
}

Widget _host(Widget child) => MaterialApp(
    home: Scaffold(
        body: SizedBox(width: 240, height: 240, child: child)));
```

在 `main()` 末尾加：

```dart
  testWidgets('empty → add shown, no clear', (tester) async {
    await tester.pumpWidget(_host(
      MultiImageControl(image: _FakeImage('/x.jpg'))
          .fillWidget(_cell(), null, (_) {}),
    ));
    expect(find.byKey(const ValueKey('multi-image-add')), findsOneWidget);
    expect(find.byKey(const ValueKey('multi-image-clear-0')), findsNothing);
  });

  testWidgets('N photos → N clears + add still shown (below cap)',
      (tester) async {
    await tester.pumpWidget(_host(
      MultiImageControl(image: _FakeImage('/x.jpg'))
          .fillWidget(_cell(), ['/a.jpg', '/b.jpg', '/c.jpg'], (_) {}),
    ));
    expect(find.byKey(const ValueKey('multi-image-clear-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('multi-image-clear-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('multi-image-clear-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('multi-image-add')), findsOneWidget);
  });

  testWidgets('tap clear-1 → onChanged drops index 1', (tester) async {
    Object? captured = 'unset';
    await tester.pumpWidget(_host(
      MultiImageControl(image: _FakeImage(null))
          .fillWidget(_cell(), ['/a.jpg', '/b.jpg', '/c.jpg'],
              (v) => captured = v),
    ));
    await tester.tap(find.byKey(const ValueKey('multi-image-clear-1')));
    await tester.pump();
    expect(captured, ['/a.jpg', '/c.jpg']);
  });

  testWidgets('at capacity (6) → add hidden', (tester) async {
    await tester.pumpWidget(_host(
      MultiImageControl(image: _FakeImage('/x.jpg')).fillWidget(
          _cell(), ['1', '2', '3', '4', '5', '6'], (_) {}),
    ));
    expect(find.byKey(const ValueKey('multi-image-add')), findsNothing);
    expect(find.byKey(const ValueKey('multi-image-clear-5')), findsOneWidget);
  });

  testWidgets('add → bottom sheet → Camera → onChanged appends',
      (tester) async {
    Object? captured = 'unset';
    await tester.pumpWidget(_host(
      MultiImageControl(image: _FakeImage('/new.jpg'))
          .fillWidget(_cell(), ['/a.jpg'], (v) => captured = v),
    ));
    await tester.tap(find.byKey(const ValueKey('multi-image-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Camera'));
    await tester.pumpAndSettle();
    expect(captured, ['/a.jpg', '/new.jpg']);
  });

  testWidgets('below min → inline red error; in-range → none', (tester) async {
    await tester.pumpWidget(_host(
      MultiImageControl(image: _FakeImage(null))
          .fillWidget(_cell(), ['/a.jpg'], (_) {}),
    ));
    expect(find.text('至少 3 张，当前 1'), findsOneWidget);

    await tester.pumpWidget(_host(
      MultiImageControl(image: _FakeImage(null))
          .fillWidget(_cell(), ['/a.jpg', '/b.jpg', '/c.jpg'], (_) {}),
    ));
    expect(find.textContaining('至少'), findsNothing);
  });
```

- [ ] **Step 2: 跑测试确认失败**

Run: `flutter test test/controls/multi_image_control_test.dart`
Expected: FAIL —— 基类 `fillWidget` 回落到 `previewWidget`（灰字占位），找不到 `multi-image-add` 等 key。

- [ ] **Step 3: 写实现**

在 `MultiImageControl` 内（`paintPdf`/`_pdfCell` 之后）加 `previewWidget` + `fillWidget` override：

```dart
  @override
  Widget previewWidget(Cell cell) => Container(
        alignment: Alignment.center,
        child: const Text('[multi-image]',
            style: TextStyle(fontSize: 9, color: Color(0xFF9A9A9A))),
      );

  @override
  Widget fillWidget(
          Cell cell, Object? value, void Function(Object? value) onChanged) =>
      _MultiImageField(
        image: image,
        paths: _paths(value),
        cols: _cols(cell),
        cap: _cap(cell),
        error: validate(cell, value),
        onChanged: onChanged,
      );
```

在文件末尾（`MultiImageControl` 类之后）加 `_MultiImageField`：

```dart
class _MultiImageField extends StatelessWidget {
  final ImageService? image;
  final List<String> paths;
  final int cols;
  final int cap;
  final String? error;
  final void Function(Object? value) onChanged;

  const _MultiImageField({
    required this.image,
    required this.paths,
    required this.cols,
    required this.cap,
    required this.error,
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
    if (path != null) onChanged([...paths, path]);
  }

  void _remove(int i) {
    final next = [...paths]..removeAt(i);
    onChanged(next.isEmpty ? null : next);
  }

  @override
  Widget build(BuildContext context) {
    final canAdd = paths.length < cap;
    final slots = paths.length + (canAdd ? 1 : 0);
    final rowCount = slots == 0 ? 0 : (slots + cols - 1) ~/ cols;
    return Column(
      children: [
        Expanded(
          child: rowCount == 0
              ? const SizedBox.shrink()
              : Column(
                  children: [
                    for (var r = 0; r < rowCount; r++)
                      Expanded(
                        child: Row(
                          children: [
                            for (var c = 0; c < cols; c++)
                              Expanded(child: _slot(context, r * cols + c)),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(error!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 8, color: Colors.red)),
          ),
      ],
    );
  }

  Widget _slot(BuildContext context, int i) {
    if (i < paths.length) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Padding(
            padding: const EdgeInsets.all(1),
            child: Image.file(File(paths[i]), fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
                    const Center(child: Icon(Icons.broken_image, size: 14))),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              key: ValueKey('multi-image-clear-$i'),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
              iconSize: 14,
              tooltip: 'Clear',
              icon: const Icon(Icons.close),
              onPressed: () => _remove(i),
            ),
          ),
        ],
      );
    }
    if (i == paths.length && paths.length < cap) {
      return Center(
        child: IconButton(
          key: const ValueKey('multi-image-add'),
          iconSize: 18,
          tooltip: 'Add photo',
          icon: const Icon(Icons.add_a_photo_outlined),
          onPressed: () => _add(context),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `flutter test test/controls/multi_image_control_test.dart`
Expected: PASS（11 个测试全绿）。

- [ ] **Step 5: 提交**

```bash
git add grid_app/lib/controls/multi_image_control.dart grid_app/test/controls/multi_image_control_test.dart
git commit -m "feat(controls): MultiImageControl.fillWidget 缩略图网格+清除+追加+红字"
```

---

### Task 5: `propEditor`（编辑 key / rows / cols / min）

**Files:**
- Modify: `lib/controls/multi_image_control.dart`
- Test: `test/controls/multi_image_control_test.dart`

**Interfaces:**
- Produces: `Widget propEditor(Cell, void Function(Map<String,dynamic>))` —— Column of 4 个 `TextFormField`，顺序固定为 `Key`(String) / `Rows`(int) / `Cols`(int) / `Min`(int)；数字字段非法输入回落到默认值。
- Consumes: 无新依赖。

- [ ] **Step 1: 写失败测试**

在 `main()` 末尾加：

```dart
  testWidgets('propEditor: editing Rows emits int prop', (tester) async {
    Map<String, dynamic>? captured;
    await tester.pumpWidget(_host(
      MultiImageControl().propEditor(_cell(), (p) => captured = p),
    ));
    // fields order: 0=Key, 1=Rows, 2=Cols, 3=Min
    await tester.enterText(find.byType(TextFormField).at(1), '4');
    expect(captured, isNotNull);
    expect(captured!['rows'], 4);
    expect(captured!['rows'], isA<int>());
    expect(captured!['key'], 'photos'); // preserved
  });
```

- [ ] **Step 2: 跑测试确认失败**

Run: `flutter test test/controls/multi_image_control_test.dart`
Expected: FAIL —— 基类 `propEditor` 返回 `SizedBox.shrink()`，`find.byType(TextFormField)` 找不到第 2 个字段（`at(1)` 越界 / enterText 失败）。

- [ ] **Step 3: 写实现**

在 `MultiImageControl` 内（`fillWidget` 之后）加：

```dart
  @override
  Widget propEditor(
      Cell cell, void Function(Map<String, dynamic> props) onChanged) {
    Widget intField(String label, String key, int fallback) => TextFormField(
          initialValue:
              ((cell.props[key] as num?)?.toInt() ?? fallback).toString(),
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: label),
          onChanged: (v) =>
              onChanged({...cell.props, key: int.tryParse(v) ?? fallback}),
        );
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
        intField('Rows', 'rows', 2),
        const SizedBox(height: 8),
        intField('Cols', 'cols', 3),
        const SizedBox(height: 8),
        intField('Min', 'min', 3),
      ],
    );
  }
```

- [ ] **Step 4: 跑测试确认通过**

Run: `flutter test test/controls/multi_image_control_test.dart`
Expected: PASS（12 个测试全绿）。

- [ ] **Step 5: 提交**

```bash
git add grid_app/lib/controls/multi_image_control.dart grid_app/test/controls/multi_image_control_test.dart
git commit -m "feat(controls): MultiImageControl.propEditor 编辑 key/rows/cols/min"
```

---

### Task 6: 注册到默认工具箱 + 更新注册表测试

**Files:**
- Modify: `lib/controls/default_controls.dart`
- Test: `test/controls/default_controls_test.dart`

**Interfaces:**
- Consumes: `MultiImageControl({ImageService? image})`（Task 1）、`buildDefaultRegistry({LocationService?, ImageService?})`（已有）。

- [ ] **Step 1: 先改测试（写期望）**

`test/controls/default_controls_test.dart`：第一个 test 内、`expect(r.specFor('image'), isNotNull);` 之后加一行：

```dart
    expect(r.specFor('multiImage'), isNotNull);
```

第二个 test 的类型集合改为含 `multiImage`：

```dart
    expect(types,
        {'title', 'label', 'text', 'number', 'coordinate', 'image', 'multiImage'});
```

在文件 `main()` 末尾加 defaultProps 断言：

```dart
  test('multiImage defaultProps has key/rows/cols/min', () {
    final r = buildDefaultRegistry();
    final p = r.specFor('multiImage')!.defaultProps();
    expect(p['key'], 'images');
    expect(p['rows'], 2);
    expect(p['cols'], 3);
    expect(p['min'], 3);
  });
```

- [ ] **Step 2: 跑测试确认失败**

Run: `flutter test test/controls/default_controls_test.dart`
Expected: FAIL —— `specFor('multiImage')` 为 null；类型集合不含 `multiImage`。

- [ ] **Step 3: 写实现**

`lib/controls/default_controls.dart`：在 import 区加 `import 'multi_image_control.dart';`，在 `r.register(ImageControl(image: image));` 之后加：

```dart
  r.register(MultiImageControl(image: image));
```

- [ ] **Step 4: 跑测试确认通过**

Run: `flutter test test/controls/default_controls_test.dart`
Expected: PASS。

- [ ] **Step 5: 全量测试 + analyze + 提交**

Run: `flutter analyze` → Expected: No issues found.
Run: `flutter test` → Expected: 全部通过（原 130 + 新增 ~13）。

```bash
git add grid_app/lib/controls/default_controls.dart grid_app/test/controls/default_controls_test.dart
git commit -m "feat(controls): 注册 MultiImageControl 到默认工具箱"
```

---

### Task 7: 真机验收（手动）

**Files:** 无（手动验证 + 记忆更新）。

- [ ] **Step 1: 静态 + 单测全绿**

Run: `flutter analyze`（No issues）、`flutter test`（全绿）。

- [ ] **Step 2: 真机走查**

在真机/模拟器运行 app：
- builder：从工具箱拖入 `Multi Image` 控件；在 inspector 设 `rows=2 / cols=3 / min=3`。
- fill：点 add → bottom sheet → Camera/Gallery 各加几张；验证缩略图按 3 列排布；逐张点 ✕ 能删；张数 < 3 时底部出现红字"至少 3 张，当前 N"；加到 6 张后 add 按钮消失。
- PDF：导出预览，验证布局——
  - 填 3 张 → 1 行 3 列，每张占满整个格子高度；
  - 填 4 张 → 2 行，第一行 3 张 + 第二行 1 张（左对齐，右侧留白），第一行不占满整高；
  - 填 6 张 → 2 行 3 列铺满。

- [ ] **Step 3: 更新记忆 + 合并**

- 更新 `memory/scss-project-status.md` 与 `MEMORY.md`：Phase 3c multiImage 完成。
- 用 `superpowers:finishing-a-development-branch` 决定合并 `phase-3c-multiimage` → `main` 的方式。

---

## Self-Review

**1. Spec coverage（对照设计文档逐条）：**
- 行×列配置（propEditor rows/cols/min）→ Task 5 ✓
- 容量 max=rows×cols、min 单独配 → `validate`/`_cap`（Task 1）✓
- 列恒定 + 行高均分铺满 + 末行留白 → `rowsForCount`（Task 1）+ `paintPdf`（Task 3）+ `_MultiImageField`（Task 4）✓
- 单张占满整高（3 张→1 行）、4 张→2 行第一行不占满 → `rowsForCount` 测试（Task 1）+ PDF 验收（Task 7）✓
- List<String> 数据、复用 ImageService → Task 1/4 ✓
- 内联红字校验 → Task 4 ✓
- resolvePdfValue 列表→字节、过滤缺失 → Task 2 ✓
- 注册 + palette 自动显示 → Task 6 ✓
- 不做 caption → 无对应任务（明确不实现）✓
- PDF 异步管线 / fill 核心流程不改 → 无改动任务（确认无需改）✓

**2. Placeholder scan：** 无 TBD/TODO；每个代码步骤给出完整代码；命令含预期输出。✓

**3. Type consistency：**
- `rowsForCount(int,int)→int`：Task 1 定义，Task 3 `paintPdf`、Task 4 `_MultiImageField`（行内同式 `(slots+cols-1)~/cols`）一致。
- `_paths(Object?)→List<String>`：Task 1 定义，Task 2/4 复用。
- Key 字符串 `multi-image-add` / `multi-image-clear-$i`：Task 4 实现与测试一致。
- `validate` 返回串 `'至少 $min 张，当前 $count'` / `'最多 $cap 张，当前 $count'`：Task 1 实现，Task 4 红字测试 `find.text('至少 3 张，当前 1')` 一致。
- `defaultProps` `{'key':'images','rows':2,'cols':3,'min':3}`：Task 1 与 Task 6 断言一致。
