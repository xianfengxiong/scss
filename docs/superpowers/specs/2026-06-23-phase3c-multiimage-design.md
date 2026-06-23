# Phase 3c — MultiImage 多图控件 设计

日期: 2026-06-23
状态: 设计待评审

## 目标

新增 `MultiImageControl`(type = `multiImage`),让一个网格格子可放置多张照片。复用 Phase 3b 已有的 `ImageService`(拍照/选图/压缩/落盘),不改动该服务。

## 已确认决策

- **行×列由设计者配置**:在 builder 的 propEditor 里设"行数 rows"和"列数 cols"。两者决定**容量上限** `max = rows × cols`。
- **布局规则(PDF 与预览一致)**:
  - **列数恒定 = cols**,列宽永远 = `cellWidth / cols`,不随张数变化。
  - 实际行数 = `ceil(张数 / cols)`,行高 = `cellHeight / 实际行数`。行高**只由实际行数决定**:
    - 2 行 3 列填 3 张(≤ cols)→ 实际 1 行 → 该行占满整个 cell 高度(第二行全空,图占满"两行高度")。
    - 2 行 3 列填 4 张(> cols,已进入第二行)→ 实际 2 行 → 每行各占 1/2 高度;**第一行不占满整高**(末行只要有 1 张就算"不全空",前面的行就不能占满)。
  - 实际行**纵向均分铺满整个 cell 高度**,没有图的空行不占高度。
  - 末行不满时:图按列从左排,右侧空位**留白**(列数不变,不横向拉伸)。
- **min**:单独配置(至少几张),默认 3。`max` 由 `rows × cols` 推导,不单独配。
- **张数校验呈现**:填写控件下方**内联红字**(不阻断操作,实时反馈)。
- **caption**:**不做**,与 3b 保持一致(继续延后)。

## 数据模型

- `data[key]` 存 `List<String>`(图片路径列表)。未填为 `null`,清空后为 `null` 或 `[]`。
- 每张图沿用 `ImageService.capture()` 落盘到共享的 `survey_images/` 目录,返回独立压缩路径。
- props:`{'key': 'images', 'rows': 2, 'cols': 3, 'min': 3}`。容量 `max = rows × cols`。

## Control 实现 — `lib/controls/multi_image_control.dart`

仿照 `ImageControl` 的形状(注入可空 `ImageService? image`,null 时 add 为 no-op,便于测试)。

```
class MultiImageControl extends ControlSpec {
  final ImageService? image;
  MultiImageControl({this.image});

  type      = 'multiImage'
  label     = 'Multi Image'
  icon      = Icons.photo_library_outlined
  defaultProps() => {'key': 'images', 'rows': 2, 'cols': 3, 'min': 3}
}
```

辅助:`int _cap(Cell) => rows * cols`(容量/max),`int _cols(Cell)`、`int _min(Cell)` 读 props 并给默认值。

Override 的方法:

- **`previewWidget`**:builder 画布占位,灰字 `[multi-image]`(边框层另画外框,与 image 一致)。
- **`propEditor`**:编辑 `rows` / `cols` / `min` 三个整数(`rows ≥ 1`,`cols ≥ 1`,`0 ≤ min ≤ rows×cols`)。
- **`fillWidget`**:委托给私有 `_MultiImageField`,见下。
- **`validate(cell, value)`**:`count = (value is List) ? value.length : 0`;`count < min` → `"至少 $min 张,当前 $count"`;`count > cap` → `"最多 $cap 张,当前 $count"`;否则 `null`。作为单一真相来源,被 `_MultiImageField` 调用渲染红字,也供未来导出前汇总校验复用。
- **`resolvePdfValue(cell, value)`**:`value` 为 `List<String>` 时,逐个 `File(path)` 存在则 `readAsBytes()`,过滤掉缺失/读不出的;返回 `List<Uint8List>`。非 list / 空 → `null`。
- **`paintPdf(cell, data)`**:读 `List<Uint8List>`,按"列数恒定 + 实际行铺满高度"布局,见 PDF 布局。非 list / 空 → `pw.SizedBox()`;单张字节损坏 try/catch 跳过(同 3b 防御)。

### `_MultiImageField`(填写控件)

- 已有缩略图:按 `cols` 列网格展示 `Image.file(...)`(`errorBuilder` 给 broken_image 图标),每张右上角 clear 按钮 `ValueKey('multi-image-clear-$i')` → `onChanged(移除 index i 后的新 list)`。
- add 按钮:`ValueKey('multi-image-add')`(`Icons.add_a_photo_outlined`)→ `showModalBottomSheet` 选 Camera / Gallery → `image.capture(source)` → 非空则 `onChanged([...旧, 新path])` **追加**。`image == null` 时早返回(no-op)。
- 当 `count >= cap`(= rows×cols):隐藏 add 按钮。
- 底部内联红字:`control.validate(cell, value)` 非空时显示(红色小字)。

## PDF 布局

设 `cols`(配置)、`count`(张数)、`actualRows = ceil(count / cols)`:

- 用 `pw.Column`,共 `actualRows` 个 `pw.Row`,每个 Row 用 `pw.Expanded(flex:1)` 等高 → 纵向均分铺满整个 cell 高度。
- 每个 Row 内固定放 `cols` 个等宽槽(`pw.Expanded(flex:1)` ×cols),列宽恒 = `cellWidth / cols`。
- 图按行优先填:图 `i` 在 `row = i ~/ cols`,`col = i % cols`。
- 末行不满:缺的槽放 `pw.SizedBox()`(留白),列对齐不变。
- 图片 `fit: pw.BoxFit.contain`(保持纵横比,不变形;"占满"指占满所在布局槽)。

## 注册与接入

- `lib/controls/default_controls.dart`:新增一行 `r.register(MultiImageControl(image: image));`,复用 `buildDefaultRegistry` 已注入的同一个 `image` 服务。palette 自动显示新控件。
- PDF 异步管线(`resolve_pdf_data.dart` / `template_pdf.dart`)**无需改动** —— 已 `await spec.resolvePdfValue(...)`,天然支持返回 `List<Uint8List>`。
- fill 模式核心流程(`fill_canvas` / `fill_screen`)**无需改动** —— 校验红字在控件内部自包含呈现。

## 测试(TDD)

`test/controls/multi_image_control_test.dart`(仿 `image_control_test.dart`,手写 `_FakeImage implements ImageService`):

- `type` / `defaultProps`(含 rows2/cols3/min3)/ `dataKey`。
- 空值 → `multi-image-add` 存在,无 clear。
- N 张 → N 个 `multi-image-clear-$i`;点第 i 个 → `onChanged` 得到移除该 index 的 list。
- 达容量(rows×cols=6 张)→ add 隐藏。
- add 流程:fake 返回 path → `onChanged` 追加(长度 +1)。
- `validate`:`< min` 返回错误串、`[min, rows×cols]` 返回 `null`、`> rows×cols` 返回错误串。
- `resolvePdfValue`:list of paths → list of bytes;缺失文件被过滤;非 list / 空 → null。
- `paintPdf`:`returnsNormally`(满格 / 半行 / 单张占满 / 空 / 损坏字节)。

`test/controls/default_controls_test.dart`:期望类型集合加入 `'multiImage'`。

## 不做(本期范围外)

- caption(per-image / per-cell)
- 孤儿图片清理、按 survey 分文件夹(3b 已延后,延续)
- 导出前汇总校验阻断(本期仅内联红字;`validate()` 已留作复用钩子)
- 末行横向拉伸铺满(明确不做:列数恒定,末行右侧留白)

## 复用与依赖

- `ImageService` / `ImagePickerImageService` 原样复用,无改动。
- 无新增依赖(`image_picker` / `flutter_image_compress` / `uuid` / `path` / `path_provider` 已在 pubspec)。
