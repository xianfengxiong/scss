# 设计 spec — Phase 4:`deviceChecklist` 控件(网格原生设备勾选表)

_日期:2026-06-29 · 状态:待用户审阅 · 取代/补充:主设计 spec `2026-06-21-grid-template-builder-design.md` §6 的 `deviceChecklist` 条目_

## 1. 背景与目标

Phase 3(现场能力)已收官,控件覆盖 title/label/text/number/coordinate/image/multiImage/satelliteDiagram(均已合并 `main`、真机验收)。把真实勘测表(`prd/New Microsoft Excel Worksheet.xlsx`)逐区块对照,**唯一还无法建模的区块是 "Type of device to install" + Number + Remark**——Excel 里它是 6 个 CheckBox + 数量 + 备注的固定清单。补上对应的 `deviceChecklist` 控件后,这张真实勘测表即可 **100% 建模**。

- **本期范围:只做 `deviceChecklist` 一个控件**,单独一期。
- `select / date / checkbox / staticText 样式` 在这张真实表里没有直接用例,属于 spec §6 的通用调色板补全,**留到后续期**(YAGNI:本期不做)。
- 目标:在不破坏现有架构(控件插件化、网格原生、边框合并、一份模型驱动建模/填写/PDF)的前提下,落地一个**内部多行多列、与页面网格对齐**的设备勾选表控件。

## 2. 控件定位与可见形态

`deviceChecklist` 是一个占据网格矩形(`colSpan × rowSpan`)的**内嵌表格控件**:

```
+----------------------------+--------+--------+
| Type of device to install  | Number | Remark |   ← 表头行(可关)
+----------------------------+--------+--------+
| [x] POE Switch             |   3    | ...    |
| [ ] Fiber Transceiver      |        |        |   ← 每个设备行 = 一个网格行
| [x] UPS                    |   1    | ...    |
| [ ] Camera                 |        |        |
+----------------------------+--------+--------+
```

- **固定三列(本期不做可配置列,YAGNI)**:`勾选 + 设备名` 合占首列、`Number` 列、`Remark` 列。
- **设备行设计期固定**:行(设备名)在建模期定义、可增删、可改名;**填写期只打勾 + 填数量/备注,不增删行**(主设计 §6 的"定义期固定行"约束)。

## 3. 几何模型(方案 B:网格原生、整页对齐)

经可视化对比后选定**方案 B**:每个设备行严格等于一个页面网格行,使 `deviceChecklist` 与上下左右的字段对齐成整页一张表(贴合真实勘测表观感)。被否的方案 A(自包含外框、内部均分、行不与网格对齐)记录在 §8。

### 3.1 行:`rowSpan` ↔ 设备行数 双向一致

**不变式**(始终成立):

```
rowSpan == rows.length + (showHeader ? 1 : 0)
```

即:控件占用的网格行数 = 表头行(0 或 1) + 设备行数。两端**双向同步、两种操作等价**,通过两条各自单向的编辑路径合成:

| 编辑动作 | 路径 | 同步方向 |
|---|---|---|
| 拖纵向手柄 / `setSpan` 改了 `rowSpan` | 几何路径 | 框架调 `spec.reconcile(cell)`,`rows` 长度跟随新 `rowSpan`(末尾补空行 / 删末行) |
| 属性面板 "+ 加行 / − 删行" 改了 `rows` 长度 | 属性路径 | 框架调 `spec.requiredRowSpan(cell)` 得目标 `rowSpan` 并 `setSpan` 同步几何 |
| 编辑某行 `label`、改 `colSpan`、拖列宽 | — | 不触及不变式,无同步 |

- 两条路径都经现有 `BuilderScreen._commit → isValid` 守卫:同步后若**越界 / 与下方控件重叠**,则**回滚该次编辑**并内联提示("下方空间不足,先腾行或上移控件")。
- 同步是幂等的:已满足不变式时 `reconcile` / `requiredRowSpan` 不产生改动,**不会循环**。
- **纵向手柄保留可用**;"加行"既能拖手柄、也能在属性面板点按钮,二者落到同一个不变式、结果一致。

### 3.2 列:按所占网格列分段

`colSpan` 切成三段,**分界落在网格列线上**:

```
设备名列(= colSpan − numberCols − remarkCols, 守卫 ≥ 1) │ Number(numberCols 列) │ Remark(remarkCols 列)
```

- 默认 `numberCols = 1`、`remarkCols = 2`。
- 因 `colSpan` 是整数列、`rowSpan = 行数 + 表头`,**外框四边天然落在网格线上**;在默认等高等宽网格下,内部行线/列线也精确压在网格线上(§5 用 `Expanded(flex)` 按所占行/列数分配,等高等宽时即网格几何)。非均分网格下内部分隔线为比例近似(可接受,真实表为等高等宽)。

## 4. 数据模型

### 4.1 `props`(存于 `cell.props` 自由 map,零模型/数据库改动)

| 键 | 类型 | 默认 | 说明 |
|---|---|---|---|
| `key` | String | `deviceChecklist_1`(放置时扫描现有 key 自动唯一) | 控件数据键,可改 |
| `title` | String | `Type of device to install` | 首列表头文字 |
| `showHeader` | bool | `true` | 是否显示表头行 |
| `numberLabel` | String | `Number` | 第二列表头文字 |
| `remarkLabel` | String | `Remark` | 第三列表头文字 |
| `rows` | List<Map> | 4 个空行 `[{label:'', key:'r1'}, …]` | 设备行清单;每项 `{label, key}`,`key` 行内唯一、自动生成 |
| `numberCols` | int | `1` | Number 列占几网格列 |
| `remarkCols` | int | `2` | Remark 列占几网格列 |

### 4.2 填写值(沿用 satelliteDiagram/multiImage "一个控件存复杂值" 先例)

`dataKey(cell) = props['key']`;`data[key]` 为按行键索引的嵌套 Map:

```json
{
  "<rowKey>": { "check": true, "number": "3", "remark": "..." },
  "<rowKey>": { "check": false }
}
```

- `check` 默认 `false`;`number`/`remark` 为字符串;空字段省略。
- JSON 可直接序列化进既有 `Survey.data`(Drift),无 schema 变更。
- `resolvePdfValue` 用默认(无文件 IO);`validate` 返回 `null`(本期不强制"勾了必须填数量")。

## 5. 三个面 + 属性面板

**共用骨架**(复用 `multi_image_control.dart` 的 "cell 矩形内 `Column(Expanded 行)+ Row(Expanded 列)` 铺满" 写法):

- `Column`:`rowSpan` 个等高 `Expanded` 行 = 表头行(若 `showHeader`)+ 各设备行 → 每行 = 一个网格行高。
- 每行 `Row`:三个 `Expanded(flex: 设备名Cols / numberCols / remarkCols)` → 列落网格列线。
- **内部行线/列线由控件自绘淡线**;**外框**走现有共享 `border` 层(`controlOutlineEdges`,占用格外轮廓、与相邻控件共享单倍边)。

**① 建模 `previewWidget(cell)`**:表头行 `title │ numberLabel │ remarkLabel`(灰底加粗);每设备行 `☐ + rows[i].label`(空 → 淡字 "设备名")`│` 淡字 "数量" `│` 淡字 "备注"。

**② 填写 `fillWidget(cell, value, onChanged)`**:表头只读;每设备行 = 可点 `Checkbox`(切 `check`)+ 设备名(只读 `label`)`│` Number 输入(数字键盘)`│` Remark 输入(文本)。`onChanged` 回传**整个嵌套 Map**(只改对应 `rowKey` 的字段)。配合已做的填写画布缩放(InteractiveViewer)操作小输入框。

**③ PDF `paintPdf(cell, data)`**:`pw.Column(crossAxisAlignment.stretch)` + `Expanded` 行 + `pw.Row` + `Expanded(flex)` 列;勾选画 ☑/☐ 小方块 + 设备名 `│` `number` `│` `remark`,字号 9pt;内部分隔线用 `pw.Container` 边自绘,外框走 PDF `border` 层。

**④ 属性面板 `propEditor(cell, onChanged)`**:
- `Key` / `title` / `showHeader` 开关 / `numberLabel` / `remarkLabel` 文本与开关。
- **设备行清单**:可增删列表,每行一个文本框改 `label` + 删除按钮;底部 "+ 加一行"。增删即触发 §3.1 的属性路径同步(`requiredRowSpan` → `setSpan` → `isValid`)。
- `numberCols` / `remarkCols` 步进器(默认 1/2);设备名列 = `colSpan − 两者`,`< 1` 时该次编辑被守卫拒绝。

## 6. 架构触点(对现有代码的最小改动)

控件插件化的承诺是"加控件 = 1 文件 + 注册 1 行"。`deviceChecklist` 的网格原生行同步需要两个**通用小钩子**(默认 no-op,不影响其它控件):

1. **`ControlSpec.requiredRowSpan(Cell cell) → int?`**(默认 `null`):控件声明"我需要这么多网格行"。`null` = 不约束(现有控件)。`deviceChecklist` 返回 `rows.length + (showHeader?1:0)`。
2. **`ControlSpec.reconcile(Cell cell) → Cell`**(默认 `identity`):几何变更后框架调用,返回使控件内部不变式成立的 cell。`deviceChecklist` 让 `rows` 长度跟随 `rowSpan`。
3. **放置初始尺寸**:放置逻辑读 `requiredRowSpan`(配合 `defaultProps` 的 4 个空行)撑出初始 `rowSpan = 5`;新增 `ControlSpec.defaultColSpan`(默认沿用"该行剩余宽"规则,`deviceChecklist` 给 4 列,保证三列可分)。

**接线点**(均在既有文件内加分支,泛型调用钩子、不写按类型 switch):
- `builder/editor_ops.dart` 或 `builder_screen.dart` 的 `_commit`:几何编辑后调 `spec.reconcile`;属性编辑后用 `spec.requiredRowSpan` 同步 `rowSpan`;统一过 `isValid`。
- `builder/control_palette.dart` / 放置流程:用 `requiredRowSpan` / `defaultColSpan` 定初始几何。
- 注册:`controls/default_controls.dart` 加一行 `r.register(DeviceChecklistControl())`。
- 新文件:`controls/device_checklist_control.dart`(含填写期的 `_DeviceChecklistField` Stateful/Stateless,仿 `_MultiImageField`)。

## 7. 测试策略(TDD)

逐红→绿,沿用现有控件的测试组织(`test/controls/`、`test/grid/`、golden):

- **数据/几何纯函数**(无 widget):
  - 不变式同步:给定 `rowSpan` 变化 → `reconcile` 后 `rows.length` 正确(补/删);给定 `rows` 变化 → `requiredRowSpan` 返回正确值。
  - 列分段:`numberCols/remarkCols/colSpan` → 设备名列宽 ≥1 的守卫;非法配置被拒。
  - 放置初始:`requiredRowSpan`/`defaultColSpan` 给出预期初始几何。
- **`ControlSpec` 各方法**:
  - `dataKey` / `defaultProps` / `validate`(恒 null)。
  - `paintPdf`:构造 `data` → 渲染不抛、☑/☐ 与文本就位(可借 PDF 文本断言或 golden)。
- **填写 widget**:点 `Checkbox` → `onChanged` 回传的 Map 对应行 `check` 翻转;输入 Number/Remark → 对应字段写入;只改目标行、不影响其它行。
- **接线/守卫**:属性面板加行致越界 → 编辑被回滚、提示出现;拖手柄改 `rowSpan` → 设备行数随动。
- **建模 golden**:`previewWidget` 在画布上的表格骨架(表头 + N 行 + 内部线 + 外框)。
- 全量回归:现有 173 测试保持绿、`flutter analyze` 0。

## 8. 边界、取舍与 YAGNI

- **不做可配置列**:列固定为 勾选+设备名 / Number / Remark。需要别的列形态时再议(很可能是另一个控件,不是给 `deviceChecklist` 加复杂度)。
- **不做 select/date/checkbox/staticText 样式**:本期范围外。
- **方案 A(自包含外框)被否**:实现更简单且与 multiImage 同构,但内部行不与同页其它行对齐,不满足"整页一张表"诉求。保留记录以备将来权衡。
- **非均分网格下内部分隔线为近似**:真实表等高等宽,无影响;若将来要严格对齐非均分行高,再引入"按子行 mm 几何绘制"的渲染上下文(本期不需要,避免扩展三个渲染方法的签名)。
- **填写期不增删行 / 不强制校验**:符合主设计"定义期固定行";勾了不填数量也允许。

## 9. 验收标准

1. 工具箱出现 `deviceChecklist`,可拖入画布,默认表头 + 4 空行、三列。
2. 属性面板可改表头文字、增删/改名设备行、调列宽;增删行与拖纵向手柄**效果一致**,均维持不变式、越界被守卫拒绝。
3. 填写期可勾选、填数量/备注;值写入 `data[key]` 嵌套 Map 并存库。
4. PDF 导出 WYSIWYG:勾选状态 + 数量 + 备注 + 表格线与画布一致,整块落在网格上、与相邻字段对齐。
5. 用真实勘测表的 "Type of device to install" 区块建模并填写、导出验证(真机)。
6. 173 既有测试 + 新增测试全绿,`flutter analyze` 0。
