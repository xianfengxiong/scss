# 进度 — Smart City Survey System (Flutter Android)

_最后更新:2026-06-21_

## 现状一句话
**greenfield 重写进行中。** A4 网格模版构建器。**Phase 1A(纯核心)+ 1B-i(持久化+只读外壳)+ 1B-ii-a(tap/按钮编辑器)均已 TDD 实现并合并 `main`,59/59 测试绿、analyze 0,模拟器手动验收通过。** 工程在 `grid_app/`(包名 `scss_grid`)。下一步:Phase 1B-ii-b(拖拽直接操作)。

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

## 下一步:Phase 1B-ii-b(拖拽直接操作)
1. **writing-plans** 出 1B-ii-b 计划:调色板拖控件吸附到格、拖手柄改 colSpan/rowSpan、拖网格线改行高列宽(用已有 `resizeBoundary`/`addTrack`/`removeTrack`)、拖移 cell。
2. 终审建议:`BuilderScreen._canvasArea` 的 scale 与 `GridCanvas` 内部 scale 保持一致(抽共享 helper),拖拽换算靠它。延后 minor 见 `.superpowers/sdd/progress.md`。
3. 后续分期(填写闭环 → 现场能力 → 完善控件 → 打磨)见 spec §12。

## 旧版(已被取代,仅作历史)
第一阶段字段式 MVP、第二阶段表格式 TemplateRow 重构(`app/` 现有代码)均完成过并跑在模拟器上;因网格线不对齐、编辑器不通用,整体被本次 greenfield 网格设计取代。可复用的是底层服务(GPS、相机压缩、卫星图打钉+RepaintBoundary 截图、pdf 导出)与依赖钉版经验(`app/BUILD_NOTES.md`)。

## 关键文件
- **设计 spec**:`docs/superpowers/specs/2026-06-21-grid-template-builder-design.md`(主文档,先读这个)
- 旧版代码:`app/lib/`(table-form,参考/复用底层服务)
- 需求:`prd/`(完整详细.docx + Excel 真实勘测表)
