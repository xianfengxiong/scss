# 进度 — Smart City Survey System (Flutter Android)

_最后更新:2026-06-22_

## 现状一句话
**greenfield 重写进行中。** A4 网格模版构建器。**Phase 1A + 1B-i + 1B-ii-a(tap 编辑器)+ 1B-ii-b(拖拽直接操作)均已 TDD 实现并合并 `main`,72/72 测试绿、analyze 0,模拟器手动验收通过(点选 / 拖移单元格 / 拖手柄改 colSpan-rowSpan / 拖网格线改行高列宽 均工作)。** 工程在 `grid_app/`(包名 `scss_grid`)。下一步:Phase 2(填写闭环)。

## ★ 2026-06-21 设计阶段成果(本次重点)
- **定稿设计 spec**:`docs/superpowers/specs/2026-06-21-grid-template-builder-design.md`(旧 `2026-06-21-multifield-editing-design.md` 已标作废,被本设计取代)。
- **技术栈拍板**:单一 **Flutter** Android app(Web 方案 pdfme/GrapesJS/SurveyJS/Form.io 经联网调研后否决,理由见 spec §2)。
- **核心模型**:A4 + 单"网格框"= PDF 输出范围;**行列尺寸为源、框大小派生**(默认等高等宽、可拖网格线非均分;框被 A4 封顶→永不超页、不分页);控件吸附网格、colSpan/rowSpan;一份模型驱动 建模/填写/PDF(WYSIWYG)。
- **关键设计点**:填写期只填不改结构;设备表定义期固定行只打勾;`multiImage` 固定外框+内部按张数铺满(图少更大,min3/max6);图像类控件支持清除;建模式空模版 PDF 预览;**控件插件化(ControlSpec 接口+注册表,加控件=1文件+登记1行)**;复用 GPS/相机/地图截图/pdf 底层,新增内嵌 NotoSansSC;Drift greenfield 无迁移。
- 头脑风暴的可视 mockup 留存在 `.superpowers/brainstorm/`。

## 已完成:Phase 1A(核心地基,已合并 main)
TDD 实现(subagent 驱动,6 组 12 任务,组内+全分支评审+修复)。`grid_app/lib/`:`model/`(GridFrame/Cell/Template/RectMm + JSON)、`grid/`(cellRectMm 几何、validateLayout、resizeBoundary/addTrack/removeTrack 轨道数学)、`controls/`(ControlSpec + ControlRegistry + Title/Field 控件)、`pdf/template_pdf.dart`(单页 renderTemplate)、`sample/sample_template.dart`。计划 + SDD 账本见 `docs/superpowers/plans/` + `.superpowers/sdd/`。

## 已完成:Phase 1B-i(持久化 + 只读建模外壳,已合并 main)
TDD(subagent 驱动,3 组 + 接线 + opus 终审 + 模拟器手动验收 5/5)。`grid_app/lib/data/`(`TemplateStore` 抽象 + 内存实现 + Drift `AppDatabase`/`DriftTemplateStore`,模版存 JSON)、`lib/builder/`(`GridCanvas` A4 缩放渲染、`PdfPreviewScreen` 经 printing、只读 `BuilderScreen`、`TemplateListScreen`)、控件 `previewWidget`、`main.dart` 接线。依赖钉版 drift 2.28.2/drift_dev 2.28.0(Dart 3.6.1)。模拟器验过:启动→新建→A4 画布→PDF 预览→Save→滑动删除全通。

## 已完成:Phase 1B-ii-a(tap/按钮编辑器,已合并 main)
TDD(subagent,5 组 + opus 终审 + 模拟器验收)。`grid/hit_test.dart`(点→格)、`builder/editor_ops.dart`(纯编辑变换,过 validateLayout 守卫)、控件 `propEditor`、`GridCanvas` 选中高亮+未注册占位、`ControlPalette`、`CellInspector`、`BuilderScreen` 改成编辑器(点选/加控件/检视器/行列步进器)。另:`all()` 按名排序、PDF 未注册占位、GridCanvas golden。期间修了用户实测的两个视觉 bug(PDF 字段行高用 stretch 撑齐、画布加内部网格线+显示"列×行")。

## 已完成:Phase 1B-ii-b(拖拽直接操作,已合并 main)
TDD(subagent 驱动,3 组 6 任务 + 组内评审 + 全分支终审 + 模拟器手动验收)。新增/改:
- `builder/canvas_metrics.dart`(`pageScale`/`kCanvasPad`,渲染器与手势层共用同一 scale,GridCanvas 也改用)。
- `builder/editor_ops.dart`:`moveCell`(**夹紧界内**:整宽单元格只改行不越界)、`setSpan`。
- `grid/grid_resize.dart`:`resizeColBoundary`/`resizeRowBoundary`(委托已有 `resizeBoundary`,保框总尺寸)。
- `builder/editable_canvas.dart`(`EditableCanvas`):包住 `GridCanvas` 的手势层——点选、**拖移单元格**、右/下蓝色手柄改 colSpan/rowSpan、框顶/左橙色手柄改列宽/行高;所有编辑回调过 `BuilderScreen._commit`→`isValid` 守卫。
- `builder/builder_screen.dart`:`_canvasArea` 用 `EditableCanvas`;检视器改为**画布底部叠加层**(Stack,选中不缩画布)。
- **手势层关键决策(模拟器验收时定稿)**:画布**等比铺满可用区(fit-both,无滚动视图)**——否则竖向 `SingleChildScrollView` 会吞掉"拖移"竖向手势。详见 spec/账本。
现已可在模拟器上:点选高亮、拖单元格换行、拖手柄缩放跨度、拖网格线改行高列宽。72/72 测试绿。计划 `docs/superpowers/plans/2026-06-22-grid-builder-phase1b-ii-b-drag.md`。

## 下一步:Phase 2(填写闭环)及之后
1. **填写模式**:同一模型驱动填写(只填值不改结构),字段输入 → 持久化 → A4 PDF 导出(WYSIWYG)。
2. 现场能力(GPS/相机/地图截图)→ 完善控件(deviceChecklist/image/multiImage)→ 内嵌 NotoSansSC 解决中文缺字。完整分期见 spec §12。
3. 延后的 minor(本期未做):调色板**拖控件到格**放置(当前用 tap 加控件已可);拖移采用"左上角吸附指针"(无抓取偏移);`_colX`/`_rowY` 或可并入 geometry;取消选中/空白点选的负路径测试。

## 旧版(已被取代,仅作历史)
第一阶段字段式 MVP、第二阶段表格式 TemplateRow 重构(`app/` 现有代码)均完成过并跑在模拟器上;因网格线不对齐、编辑器不通用,整体被本次 greenfield 网格设计取代。可复用的是底层服务(GPS、相机压缩、卫星图打钉+RepaintBoundary 截图、pdf 导出)与依赖钉版经验(`app/BUILD_NOTES.md`)。

## 关键文件
- **设计 spec**:`docs/superpowers/specs/2026-06-21-grid-template-builder-design.md`(主文档,先读这个)
- 旧版代码:`app/lib/`(table-form,参考/复用底层服务)
- 需求:`prd/`(完整详细.docx + Excel 真实勘测表)
