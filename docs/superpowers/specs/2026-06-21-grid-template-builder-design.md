# 设计 spec — A4 网格模版构建器(SCSS greenfield 重写)

_日期:2026-06-21 · 状态:✅ 已获用户复核通过_

> 取代 [`2026-06-21-multifield-editing-design.md`](./2026-06-21-multifield-editing-design.md)。这是对 SCSS(Smart City Survey)勘测 app 的 **greenfield 重写**:推倒原"线性行模型 + 对话框编辑器",改为"A4 网格 + 拖拽控件"的所见即所得模版构建器。

---

## 1. 背景与目标

SCSS 是一个**离线 Android 现场勘测 app**:Project → Site → Survey,在 A4 表单上记录勘测数据,含卫星图打钉、照片、GPS,导出 A4 PDF。原版用"线性 TemplateRow 行模型 + 逐行对话框编辑器",暴露两个根本问题:① 编辑器不通用,加并排字段要打补丁;② 各行各画各的,**网格线不对齐,PDF 难看**。

**本设计的目标**
- 用**所见即所得的网格模版构建器**替代行模型:在一页 A4 上拖控件、控件吸附网格 → 对齐由结构保证。
- 模版**绝不超过一页 A4、不分页**;尺寸在定义期完全确定。
- 一份模型驱动**构建 / 填写 / PDF** 三处,长一个样。
- **可扩展**:后期增加新控件**最小改动**(插件式注册,见 §10)。
- **效果好 + 更可靠**为最高优先级。

**非目标(YAGNI)**
- 多页 / 分页 / PDF 自动续页(明确排除)。
- 多设备协作、云同步(构建端与填写端是同一设备)。
- 横向 A4、多种纸张(先只做 A4 纵向)。
- 一页多个网格框(先单框;页眉等用"单框 + 跨列"表达)。
- 运行期自动缩放行高去塞内容(明确排除,见 §4)。

## 2. 技术栈决策:单一 Flutter Android app

**结论:单一 Flutter 工程,greenfield 重写,两个模式(建模 / 填写)。**

理由(紧扣"效果好 + 更可靠"):
- 最难也最不能出错的是**现场端**——离线、GPS、拍照、**卫星图打钉 + 截图快照**、本地存储。原生 Flutter 这些都成熟稳定;换 Web/PWA 恰恰是这几项最易翻车。
- 一份网格模版模型驱动构建/填写/PDF → 所见即所得是结构保证,无需在两个技术栈间同步 JSON。

**为什么不用 Web 构建器(2026-06 联网核实)**
- **pdfme**(MIT、可离线、固定 A4、JSON 模版、拖拽设计器):Web 里唯一像样的候选,但它是**绝对 x/y 定位,无网格 colspan/rowspan**,且设备能力仍得靠 Capacitor 兜底(离线地图截图是短板)。
- **GrapesJS**:响应式网页编辑器,固定 A4 需买商业 Studio SDK;PDF 走浏览器打印。
- **SurveyJS**:Survey Creator 设计器与 survey-pdf **均收费**;PDF 是自动流式排版,非固定 A4。
- **Form.io**:formio.js(MIT)是响应式 Bootstrap 栅格;精确 A4/PDF 是付费叠加件。
→ Web 既不在可靠性上赢,也不在"网格模型"上赢。

## 3. 核心概念:网格框 = 输出范围

- 模版画布 = **一页 A4 纸面**(210×297mm 纵向)。
- 画布上有**一个"网格框"控件**:自定义**行数、列数**,并**直接设定行高、列宽**;可**移动**其在 A4 上的位置。
- **框的大小由行列尺寸派生**:框宽 = 各列宽之和,框高 = 各行高之和(见 §4)。
- **网格框就是 PDF 的输出范围**:框内是内容,框外是页边距留白。
- **控件吸附到网格格子**,可**跨列(colSpan)/跨行(rowSpan)**;所有边界落在同一套网格线 → **对齐免费**。
- **行高/列宽可单独拖线调整(非均分,像 Excel)**,默认均分。
- 框被 A4 框住,**加行/加高不能越过纸面下边、加列/加宽不能越过右边 → 永不超 A4、不分页**。溢出靠物理边界杜绝,不靠运行期缩放。

## 4. 行高/列宽策略(回答"不同模版行数不同怎么办")

**行列尺寸为源、框大小派生——不是把固定框高摊给行。** 设计者**直接设定行高/列宽**,框随之变化:
- **默认所有行等高、所有列等宽**(最常见、最美观),设一个基准行高/列宽即可。
- **行数少 → 框变矮、底部留白**,而不是把几行拉得很高(避免"行少行高太高不好看")。
- 需要时**拖某条网格线**单独调高某行 / 调宽某列(非均分,像 Excel)。
- **框高 = Σ 行高,框宽 = Σ 列宽**;两者被 A4 可用区域封顶,超了就**禁止再加/再高**(物理边界,不自动缩)。
- 不同模版"行列数/疏密不同" = 框用掉页面多少不同,所见即所得。

## 5. 数据模型

```text
Template {
  id, name,
  page: { widthMm: 210, heightMm: 297 },        // A4 纵向(固定)
  grid: GridFrame,
  cells: Cell[],
}

GridFrame {
  xMm, yMm,                   // 框左上角在 A4 上的位置(可移动)
  cols: int, rows: int,
  colWidthsMm: double[cols],  // 各列宽,默认均分;拖列线改之
  rowHeightsMm: double[rows], // 各行高,默认均分;拖行线改之
  // 框宽 = Σ colWidthsMm,框高 = Σ rowHeightsMm(派生)
  // 约束:xMm + 框宽 ≤ 页宽,yMm + 框高 ≤ 页高(超出禁止)
}

Cell {
  id,
  col, row,                   // 0 基起点(网格坐标)
  colSpan, rowSpan,           // ≥1;require col+colSpan≤cols, row+rowSpan≤rows
  type: CellType,
  props: { ... }              // 随 type 而定(见 §6)
}
```

- **不变式**:cells 互不重叠;每个 cell 完全落在网格内;由构建器强制。
- **cell 的 mm 矩形** = 由 colWidthsMm/rowHeightsMm 的前缀和 + 框 x/y 推出。**构建器、填写、PDF 三处用同一函数计算**,保证 WYSIWYG。
- 模版存为 JSON(SQLite 内一列),无需对象关系映射的复杂度。

## 6. 控件调色板(默认集合,可在复核时增删)

| 类型 | props | 填写期行为 | PDF |
|---|---|---|---|
| `title` | text, align | 只读 | 居中加粗 |
| `section` | text | 只读 | 灰底加粗段头 |
| `staticText` | text, style | 只读 | 文本 |
| `field` | label, key, valueType(text/number/coordinate/select/date), unit?, options?, **labelCols** | 输入框/选择/取 GPS;label 占该 cell 跨度的前 labelCols 列、value 占其余(分界落在网格线→对齐) | label \| value 表格 |
| `checkbox` | label, key | 勾选(bool) | ☐/☑ + 文本 |
| `deviceChecklist` | rows:[{label,key}], columns:[…] | **定义期固定行**;填写只**打勾 + 填列值**,不增删行 | 固定行的勾选表 |
| `satelliteDiagram` | caption?, key | 开地图→打钉→截图,图填入;**支持清除**(清掉截图与钉,可重测) | 截图图片 |
| `image` | caption?, key | 点击→相机/相册→填入一张;**支持清除**重填 | 图片 |
| `multiImage` | key, columns(默认3), minCount(默认3), maxCount(默认6) | **外框固定**(设计期按 maxCount 占位定大小);填 N 张→排成 `ceil(N/columns)` 行**铺满外框**,图少每张更大(3张=1行更高,6张=2行);**每张可单独 ✕ 清除**;<min 提示补、>max 不让加;末行不足按列靠左 | 同款铺满网格 |

**可变内容控件通则**:凡"数量/长度在填写期才定"的控件(如 `multiImage`,未来如可变文本),一律**"外框在设计期固定 + 内部自适应铺满"**,**绝不在填写期改变外框尺寸** → §3「永不超 A4、不分页」的保证不被打破。

**注**:上表控件并非硬编码清单,而是**控件注册表**的首批条目;调色板与建模/填写/PDF 三处都泛型遍历注册表(§10.1),加控件不动这三处。

**默认网格**:cols = 12,rows 由设计者定(默认给个起始值,如 16)。

## 7. 三个面,一份模型

- **建模式**:A4 画布(按屏缩放显示)。左侧调色板拖控件→吸附网格;拖控件边缘改 colSpan/rowSpan;拖网格线改行高/列宽;拖框移动(大小由行列尺寸决定);点 cell 改其 props。强制不变式、强制不超 A4。**支持一键 PDF 预览**(渲染空模版,核对 A4 实际输出)。
- **填写模式**:**同一网格**渲染,cell 内的占位变成真实输入(输入框、勾选、取 GPS、放照片、地图截图)。图像类控件(`image` / `multiImage` 单张 / `satelliteDiagram`)均**可清除重填**。结构不可改。
- **PDF**:单页 `pw.Page`,按 §5 的 mm 矩形定位每个 cell 并渲染同款内容。**内嵌 NotoSansSC** 解决中文缺字。

WYSIWYG 由"三处共用 cell 矩形计算 + 共用渲染语义"保证。

## 8. 复用的"可靠底层"(不重写,降风险)

虽是 greenfield,但已验证可靠的设备/IO 能力**原样保留/移植**,而非重写:
- **GPS**:geolocator。
- **相机 + 压缩**:现有拍照压缩链路。
- **卫星地图 + 打钉 + 截图快照**:地图组件 + `RepaintBoundary` 截图(现场端最关键、最不能回归的能力)。
- **PDF**:`pdf` 包(MultiPage→改单 Page)。
- 依赖钉版注意见原 `BUILD_NOTES.md`。

## 9. 持久化

- **Drift / SQLite**,全新库,**greenfield 无迁移**(旧体验数据不保留)。
- 实体:`templates`(含 grid+cells 的 JSON)、`projects`、`sites`、`surveys`(survey.data 按 cell 的 key 存值)。

## 10. 架构 / 模块边界(为隔离与清晰而设计)

- `model/`:Template/GridFrame/Cell + JSON 编解码 + **cell 矩形几何**(纯函数,可单测)。
- `grid/`:网格引擎——坐标↔矩形换算、轨道尺寸拖动调整(框大小=Σ轨道、受 A4 封顶)、吸附、不变式校验(纯逻辑,UI 无关,可单测)。
- `controls/`:**控件注册表 + 每个控件一个插件**(见 §10.1)。builder/fill/pdf/palette 都泛型遍历注册表,**不写按类型的 switch**。
- `builder/`:建模式 UI(画布、调色板、拖拽、网格线拖动、属性面板)。
- `fill/`:填写模式 UI。
- `pdf/`:单页渲染器(吃同一 cell 矩形)。
- `services/`:geolocator、camera、map-snapshot、pdf 导出。
- `data/`:Drift。

判据:几何与网格引擎是纯逻辑、可独立测试;构建/填写/PDF 都只是它的"视图"。

### 10.1 控件插件化(满足"后期加新控件最小改动")

- **数据模型对控件类型无关**:Cell 只存 `type`(字符串 id)+ `props`(该类型的自由 map),所以**加新控件无需改数据模型 / 数据库 / 迁移**。
- 每个控件实现统一接口 `ControlSpec`,把它需要的一切收在**一个文件**里:
  - `type` / `label` / `icon` —— 调色板项
  - `defaultProps()` —— 拖入时的初始 props
  - `propEditor(ctx)` —— 建模式属性面板
  - `previewWidget(ctx)` —— 建模式占位渲染
  - `fillWidget(ctx)` —— 填写模式真实输入(含取值 / 清除 / 校验)
  - `paintPdf(ctx)` —— 在 cell 矩形内的 PDF 渲染
  - `validate(value)?` —— 填写期规则(如 `multiImage` 的 min/max)
- **加一个新控件 = 新增一个实现 `ControlSpec` 的文件 + 在注册表登记一行。** 调色板、建模、填写、PDF 全部泛型遍历注册表,**没有散落的 switch 要改**。§6 的现有控件即这套接口的首批实现。

## 11. 测试策略(TDD)

- **单元(重点)**:cell 矩形几何(给定 grid + cell → mm 矩形)、轨道尺寸拖动调整(框大小=Σ轨道、A4 封顶、最小轨道约束)、不变式校验(越界/重叠拒绝)、JSON 往返。
- **Widget**:拖入吸附、跨度调整、不超 A4 边界。
- **Golden**:PDF 单页布局(几个代表模版)与建模式渲染像素级一致(WYSIWYG 回归)。
- **控件插件**:每个 `ControlSpec` 可独立测(propEditor / fillWidget / paintPdf / validate),新增控件自带其测试。
- 门槛:`flutter analyze` 0 问题、`flutter test` 全绿。

## 12. 实现分期(每期单独出实现计划)

工程较大,分期推进,本 spec 为总设计;**writing-plans 先针对第 1 期**:

1. **核心地基**:数据模型 + 网格几何引擎 + **ControlSpec 接口 + 控件注册表** + 单页 PDF 渲染器 + **建模式 PDF 预览(空模版)** + 最小建模画布(放/移/跨/拖线)+ 用注册表落地一两个控件。打通"建→存→预览 PDF"最小闭环。
2. **填写闭环**:填写模式渲染同一网格;基本字段输入 + 存库 + 导出。
3. **现场能力**:GPS 字段、相机、`image`/`multiImage`(含**单张/整体清除**)、卫星图打钉截图(含**清除**)。
4. **完善控件**:deviceChecklist、select/date/checkbox、staticText 样式;调色板补全。
5. **打磨**:NotoSansSC、属性面板细节、golden 回归、release。

## 13. 风险与取舍

- **手机端建模 ergonomics**:在小屏上拖 A4 网格、拖网格线精度有限。缓解:画布支持缩放/平移、吸附、加减按钮兜底(不全靠拖)。
- **非均分轨道数学**:拖线调尺寸 + 框大小=Σ轨道 + 不超 A4 + 跨度,需仔细做成纯函数并重点单测。
- **密集模版可读性**:行项多→行矮→字小,是 A4 单页的物理上限,由设计者所见即所得地权衡(非系统隐藏)。
- **NotoSansSC 体积**:APK 增大数 MB,用子集化缓解。
- **greenfield 重写成本**:通过保留已验证的设备/IO 底层(§8)把可靠性风险降到最低。

## 14. 待复核的默认值(请确认或调整)

- 控件调色板集合(§6)。
- 默认网格 12 列、起始 16 行、基准行高约 8mm(等高等宽)。
- 单网格框(不支持一页多框)。
- 持久化用 Drift/SQLite、greenfield 无迁移。
- A4 纵向、仅单页。

## 15. 设计修订 2026-06-22 — 网格原生控件模型(取代 §6 的 `field` 模型)

用户复核建模器后定稿的控件模型调整(替代原 §6 里"一个 `field` 内含 label+value 的 flex 分界 + valueType 下拉"):

- **控件 = 网格原生 + 工具箱化**:定位/尺寸全用网格(`col/row/colSpan/rowSpan`),控件填满所占格、随网格线缩放。调色板像 VB 工具箱,**每种类型一个独立 `ControlSpec`**(插件式,1 文件 + 注册 1 行)。
- **废弃 `field` + valueType 下拉**,拆为独立控件:`label`(只读文本,props: text/align/bold)、`text`(输入,props: key/hint)、`number`(输入,props: key/unit)、`coordinate`(GPS 输入,props: key;搬 Phase 3a 的 `_CoordinateField`+`LocationService`)。`title`(居中加粗)保留。label 与 value **不再绑定**,一行"标签 │ 值"= 一个 label 格 + 一个 value 格,**对齐由网格保证**(根除原 labelCols flex 分界的错位)。
- **检视器 = VB 属性面板**:每控件自己的 `propEditor` 属性集(label 有 align/bold;value 控件有 key 等)。属性存 `cell.props` 自由 map(加属性零数据库/模型改动)。
- **输入控件 `key` 自动唯一**(`text_1`…,加入时扫描现有 key)**+ 可改**。
- **边框合并(P2b)**:控件只画内容,另起"边框层"把**占用格**的轮廓画成**以网格边界线为中心的线** → 相邻共享边重合 = 始终单倍粗;canvas 与 PDF 共用同一几何。建模画布另:① 每个控件(含 Title、不只选中的)画实线轮廓框住占用范围;② 淡网格线只在**空白格**画,控件占的格内不画。
- **放置(已在"自由放置"期完成)**:从工具箱**拖控件到目标格**、默认占该行剩余宽度;tap 落第一个空格;移动/手柄调整到任意空位,`isValid` 守卫。
- 落地分期:**P1 自由放置(已合并)→ P2a 工具箱拆分 → P2b 边框合并+网格渲染**。
