# 设计 spec — 模版编辑器的 multiField 并排字段编辑

> ⚠️ **已作废 / SUPERSEDED(2026-06-21)**:讨论中方向升级为"A4 单页网格模版构建器(greenfield 重写)",本 multiField 小功能已并入新设计。见 [`2026-06-21-grid-template-builder-design.md`](./2026-06-21-grid-template-builder-design.md)。本文件仅作历史留存。

_日期:2026-06-21 · 状态:已作废,被网格构建器设计取代_

## 1. 背景与问题

表格式模版重构(WYSIWYG)已完成:模版编辑器、站点填写、PDF 三处共用 `lib/widgets/template_table.dart` 渲染。模版用行模型 `TemplateRow`,行类型含 `multiField`(一行内多个 `TemplateField` 等宽并排,如 Site Name 与 GPS 同行)。

**缺口:渲染层全支持 multiField,但编辑器无法创建/编辑它。**

- `template_editor_screen.dart` 的 `_addRow` 类型选单没有 multiField 项。
- `_editRow` 对 `multiField` 是空 `break`(第 162-164 行)。
- 没有"管理一行里多个字段(增/删/编辑某一列)"的 UI。

**已核实(避免设计建在沙子上):** 填写态按每个 `f.key` 建输入框(`site_detail_screen.dart:73` 的 `for (final f in row.fields)`),PDF 把 multiField 渲成 `pw.Row` 等宽并排(`pdf_service.dart:173-180`)。数据按 `f.key` 走,编辑器本就保证 key 唯一。**所以本工作是纯编辑器 UX,不动模型/数据库/PDF/填写态。**

## 2. 目标 / 非目标

**目标**
- 用户能在模版编辑器中创建并排字段行、编辑其中任意一列、增删列、整行移动/删除。
- 不引入新的行类型概念到"Add row"菜单——并排行一律由"在已有 field 行上加列"长出来。
- 不改数据模型、数据库结构、PDF、填写态;不需要 `build_runner`、不需要换库文件。

**非目标(YAGNI)**
- 行内列的左右重排序(列顺序 = 加列顺序;要换序可删了重加)。
- 列宽自定义(沿用渲染器的等宽 `Expanded`)。
- multiField 行里嵌设备表/图区(并排单元仅限可填字段 `TemplateField`)。
- 列数硬上限(渲染器对 N 列已用 `Expanded` 处理;实际 2-3 列由用户自行把握)。

## 3. 数据模型不变式(无模型改动)

`TemplateRow`/`TemplateField`/JSON 已支持 N 字段。确立一条由编辑器维护的不变式:

- `field` 行 = 恰好 **1** 个字段。
- `multiField` 行 = **2+** 个字段。
- field 行**加列** → 升级为 `multiField`。
- multiField 行**删列**删到只剩 1 个 → 自动降级回 `field`。

不修改 `lib/models/template_row.dart`。

## 4. 交互设计(仅在编辑态 `editing = true` 生效)

| 手势 | field 行 | multiField 行 | title / section / deviceTable / image 行 |
|---|---|---|---|
| **tap 单元格** | 编辑这一个字段 | 编辑被点中的那一列 | 编辑该行(沿用现有对话框) |
| **长按行** | 行菜单(见下) | 行菜单(见下) | 行菜单(仅 Move/Delete) |

**长按行 → 行菜单(modal bottom sheet)。** 去掉原 `_manageRow` 里的 "Edit"(tap 已接管编辑),改为纯结构操作:

```
⊕ Add column          ← 仅 field / multiField 行;新建一字段并追加到行尾
↑ Move up   ↓ Move down
🗑 Delete row
──────────────────────  ← 以下仅 multiField 行
✕ Delete column: <label-1>
✕ Delete column: <label-2>
```

- **Add column**:弹现有 `_fieldDialog` 建新字段(label/type/unit/options),追加到 `fields` 末尾;若原行是 `field` 则把 `type` 改为 `multiField`。
- **Delete column: <label>**:从 `fields` 删掉该列;若删后只剩 1 列,把 `type` 改回 `field`。
- **填写态(`editing = false`)不传这些回调**,渲染与行为完全不变(仍是真实输入框)。

## 5. 代码改动

### 5.1 `lib/widgets/template_table.dart`
- 新增回调:
  - `void Function(int rowIndex, int fieldIndex)? onFieldTap`
  - `void Function(int rowIndex)? onRowLongPress`
  - 保留现有 `onRowTap(int rowIndex)`,改为只用于 title/section/deviceTable/image 行。
- `_labelValue` 增加可选 `VoidCallback? onTap` / `VoidCallback? onLongPress`,当任一非空时用 `InkWell` 包住该字段单元格。
- 接线(均仅 `editing` 时):
  - `field` 行:其唯一单元格 `onTap → onFieldTap(i, 0)`,`onLongPress → onRowLongPress(i)`。
  - `multiField` 行:第 j 列单元格 `onTap → onFieldTap(i, j)`,`onLongPress → onRowLongPress(i)`。
  - title/section/deviceTable/image 行:整块 `onTap → onRowTap(i)`,`onLongPress → onRowLongPress(i)`。

### 5.2 `lib/screens/template_editor_screen.dart`
- 抽出两个**纯函数**(便于单测,含自动升/降类型与 key 唯一):
  - `TemplateRow addColumnTo(TemplateRow row, TemplateField field)`
  - `TemplateRow removeFieldAt(TemplateRow row, int index)`
  - key 唯一仍复用现有 `_genKey`(在 `_fieldDialog` 内为新字段生成)。
- `TemplateTable` 接线改为:`onFieldTap: _editField`、`onRowTap: _editRow`(只剩非 field 类型分支会经此进入)、`onRowLongPress: _manageRow`。
- 新增 `_editField(int rowIndex, int fieldIndex)`:`_fieldDialog(existing: row.fields[fieldIndex])` → 用结果替换该列。
- 重写 `_manageRow`:结构菜单(Add column / Move up / Move down / Delete row / [multiField] 逐列 Delete column),不再含 "Edit"。
- `_editRow`:移除 `field` 与 `multiField` 两个分支——field/multiField 的编辑现由 `_editField`(tap 改某列)与 `_manageRow`(结构)接管;`_editRow` 只保留 title/section/deviceTable/image 四类(由 `onRowTap` 触发)。
- `_addRow` 类型选单**保持不变**(不加 multiField 项)。
- 更新底部提示文案为:`Tap a cell to edit · long-press a row to add column / move / delete`。

### 5.3 不改动的文件
`models/template_row.dart`、`services/pdf_service.dart`、`screens/site_detail_screen.dart`、`templates/default_template.dart`、`data/database.dart`——均无需改。

## 6. 测试

**TDD,单元测试(`test/` 下新增或并入现有)** 针对两个纯函数:
- field 行加列 → `type == multiField` 且有 2 个字段;两字段 key 唯一。
- multiField(2 列)删 1 列 → `type == field`,剩 1 字段。
- multiField(3 列)删 1 列 → 仍 `multiField`,剩 2 字段。
- 加列时 label 与已有字段同名 → 生成的 key 自增不冲突。

**手动验收(模拟器)** 覆盖手势/弹层:在 Site Name 行长按→Add column 加 GPS→并排显示;tap GPS 单元格改 label;长按→Delete column 回单字段;保存后进站点填写页确认两列都能填、导出 PDF 两列并排。

**门槛:** `flutter analyze` 0 问题、`flutter test` 全绿。

## 7. 风险 / 取舍

- **长按可发现性低**:编辑态提示文案已点明"long-press a row";验收时确认手感。若反馈差,退路是给编辑态行加一个尾部 `⋮` 按钮(本 spec 不做)。
- **tap 目标范围**:field 行整行单元格可点;multiField 各列 `Expanded` 等宽,列多时单列偏窄但仍可点。
- **数据残留**:删列只删模版定义,历史 survey 里该 `f.key` 的旧值不主动清理(与现有删字段行为一致,无回归)。
