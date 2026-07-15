# 进度 — Smart City Survey System (Flutter Android)

_最后更新:2026-07-15_

## 现状一句话
**greenfield 重写进行中,现场能力(Phase 3)基本收官。** A4 网格模版构建器。建模(网格/拖拽/VB 工具箱/边框合并)+ 填写闭环 + PDF 导出(WYSIWYG)均已合并 `main`;控件已覆盖 title / label / text / number / coordinate(GPS) / image / multiImage / **satelliteDiagram(卫星图打钉截图)**。**最新:Phase 3d satelliteDiagram 已 TDD 实现、真机 SM-A528B 验收过、合并 main @ `f1daeb4`,173 测试绿、analyze 0。** 工程在 `grid_app/`(包名 `scss_grid`)。**Phase 4 `deviceChecklist`(网格原生设备勾选表)经 SDD 9 任务 TDD 实现 + 真机 SM-A528B 验收(2026-07-01)修 7 项 UI 问题(PDF 对勾非 X / 勾选框溢出 / 列宽可调 / 标题竖切 / 文字竖向居中 等)并端到端(建模→填写→PDF WYSIWYG)验证通过;197 测试绿、analyze 0,Phase 4 已合并 main @ `2e1344d`(快进,分支已删)。**2026-07-15 决策:Phase 4 余下控件(select/date/checkbox/staticText/调色板)暂缓——当前业务用不到;NotoSansSC 取消——现场用不到中文(偶发中文在 PDF 显示为方框、不崩,可接受)。Phase 5 = 纯 release 构建**(正式签名 keystore 进 git(纯本地仓库)/ 显示名 SCSS Survey / split-per-abi arm64 交付,见 `docs/superpowers/specs/2026-07-15-phase5-release-build-design.md` 与 `grid_app/BUILD_NOTES.md`)。另:本机 Flutter 已升 3.44.6(Dart 3.12.2),工程随之适配 Gradle 8.7 / AGP 8.6 + 修 3 处 deprecation,197 测试绿、analyze 0。**

> 注:本文件的逐阶段细节维护在 memory `scss-project-status.md`(更全更新);Phase 2 之后各阶段的完整设计/计划见 `docs/superpowers/specs/` 与 `docs/superpowers/plans/`,实现细节见 git 历史。下方为滚动汇总。

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

## 已完成:Phase 2 → 3d(均 TDD + 评审 + 真机验收 + 合并 main)
滚动汇总(细节见 memory / specs / plans / git):
- **Phase 2 填写闭环**:`Survey`(templateId+data map)+ `SurveyStore`/Drift 表 + v1→v2 迁移;`FillCanvas`/`FillScreen`/`SurveyListScreen`;一份 `data` map(按控件 `props['key']`)同驱动填写与 PDF。
- **Phase 3a coordinate(GPS)**:`geolocator ^13`(钉版)+ 定位权限;`LocationService` 抽象 + 注入控件;坐标即 `data[key]` 字符串。
- **控件模型重构 P1/P2a/P2b**:自由放置(拖控件到格)、VB 工具箱(label/text/number/coordinate 拆为独立控件,删 field)、边框合并(控件只画内容 + `controlOutlineEdges` 三处渲染器共用 → 单倍共享边、WYSIWYG)。
- **Phase 3b image 单图**:`image_picker`+压缩+`resolvePdfValue` 异步嵌图;值存路径;CAMERA 权限。
- **Phase 3c multiImage 多图** + dock 折叠属性面板 + 填写画布缩放(InteractiveViewer):值=`List<String>`;列恒定行高均分铺满;末行留白;单张清除。
- **Phase 3d satelliteDiagram 卫星图打钉截图**(@`f1daeb4`):`flutter_map`+`latlong2`+`screenshot`(**无需 connectivity_plus/Kotlin/AGP 改动**,仅 main manifest 加 `INTERNET`);值=Map`{path,pins,center,zoom}`;`PinLabelDialog` 自持控制器;Esri 瓦片 + 打钉/标签 + GPS 定心 + screenshot;PDF `pw.Center` 居中。真机迭代修 4 bug(删钉崩溃 / 落钉偏差 / 缩略图 contain+点开重开 / PDF 左对齐)。

## Phase 4 — `deviceChecklist`(真机验收通过、UI 修复完成,待合并 main)

**Phase 4 `deviceChecklist`(网格原生设备勾选表)代码完成、待真机验收**(2026-06-29,subagent-driven-development,9 任务 TDD + 各任务 sonnet 评审 + opus 全分支终审;190 测试绿、analyze 0;分支 `phase4-devicechecklist`)。设计/计划:`docs/superpowers/specs/2026-06-29-phase4-devicechecklist-design.md`、`docs/superpowers/plans/2026-06-29-phase4-devicechecklist.md`。**形态(方案 B 网格原生)**:每设备行=一个网格行、整块落网格、与相邻字段对齐成一张表;**不变式 `rowSpan==rows.length+(showHeader?1:0)` 双向同步**(拖纵向手柄→`reconcileCell` 让 rows 跟随;属性面板加/删行→`syncRowSpan` 让 rowSpan 跟随;两路 disjoint、无 loop、均过 `isValid` 守卫,破坏态不落库)。固定三列(勾选/数量/备注);值=`data[key]={rowKey:{check,number,remark}}`(JSON 安全、无 Drift schema 变更,沿用 satelliteDiagram/multiImage 嵌套值先例)。**架构触点**:`ControlSpec` 加 3 个默认 no-op 钩子(`requiredRowSpan`/`reconcile`/`defaultColSpan`)+ `editor_ops` 2 个泛型纯函数(`reconcileCell`/`syncRowSpan`)+ `builder_screen` 3 处接线(放置初始尺寸 / onSpan→reconcileCell / onPropsChanged→syncRowSpan),全程泛型无 type-switch。新文件 `lib/controls/device_checklist_control.dart`(+ register 1 行)。**opus 终审 Ready=Yes、0 Crit/0 Imp**;Minor 全 defer,pre-merge polish 已补不变式断言/删死参数。APK(debug @ `c653773`)已 `install -r` 真机 SM-A528B,**真机验收进行中(用户)**。本期列宽用默认(Number1/Remark2,propEditor 不可调,YAGNI);两个 defer:加行空间不足静默无反馈、shrink 后孤立 fill 值未清(均无害)。

**✅ 真机 SM-A528B 验收(2026-07-01)+ 修复完成、端到端验证通过**(197 测试绿、analyze 0;分支新增 3 个 fix commit `a52802d`/`71de161`/`a1eeb74`,待合并)。用户真机验收暴露 7 项、全部 TDD 修复 + adb 截图/PDF 真机核对:① **『保存后重进全丢』经 DB 实证非数据丢失**——数据正常落库,是模板列表『Fill』每次新建空白 survey、须走 AppBar『Surveys』列表恢复(用户选本期不动此工作流,列为后续独立项);② PDF 勾选画字面 `X`→ 新增 `checkMark()` 用矢量 `pw.CustomPaint` 画对勾(基础字体无 ✓);③ 填写勾选框 Material `Checkbox` 固定最小尺寸溢出矮格→ 换紧凑 13px `Icon` + 整格 `GestureDetector`;④ 设备名列太窄→ `defaultColSpan` 4→6;⑤ 列宽不可调→ propEditor 加 `numberCols`/`remarkCols` 步进器(名列≥1 守卫);⑥ 标题/表头**竖向裁切**(画布按页宽缩几何但字号固定 px 不缩)→ 标题类文字套 `FittedBox(scaleDown)`;⑦ label + 所有输入文字**没竖向居中、偏上**(Flutter 居中含字体 leading 的行框、pdf 包更贴字形→ PDF 正常)→ App 端 `TextStyle(height:1.0)` + `strutStyle(forceStrutHeight)` 收紧行度量(PDF 不动)。改动仅 `lib/controls/*`,golden 因 title/label 像素重生成。真实勘测表端到端(TestSite/Dubai + Varifocal ✓9 roof / PTZ ✓2 / Radar ✓ → PDF 逐项 WYSIWYG 一致)通过。

## 下一步(2026-07-15 调整后)
0. ✅ **#1 保存/恢复体验已完成**(spec `2026-07-15-save-restore-ux-design.md`):Fill=续填/新建 sheet、survey 命名/改名/updatedAt、FillScreen autosave(500ms 防抖+退出 flush,Save 按钮移除)。
1. ✅ **Phase 5 release 构建已完成**(spec `2026-07-15-phase5-release-build-design.md`):签名/显示名/split-per-abi/真机覆盖升级验证/BUILD_NOTES;仓库已推 GitHub 私有远端。
2. **暂缓池(用户拍板,现在用不到)**:Phase 4 余下控件(select/date/checkbox/staticText 样式/调色板补全);NotoSansSC 内嵌(取消,恢复时的技术备忘见 spec §1)。
3. **待办池**:multiImage 6 图 PDF contain 参差(杠杆=控件做高);拖移左上角吸附指针;`_colX`/`_rowY` 并入 geometry;取消选中/空白点选负路径测试;deviceChecklist 两 defer(加行空间不足静默无反馈 / shrink 后孤立 fill 值未清);pubspec 钉版(drift/geolocator)理由随 Dart 3.12 已失效、可择机放开(见 `grid_app/BUILD_NOTES.md`)。

## 旧版(已被取代,仅作历史)
第一阶段字段式 MVP、第二阶段表格式 TemplateRow 重构(`app/` 现有代码)均完成过并跑在模拟器上;因网格线不对齐、编辑器不通用,整体被本次 greenfield 网格设计取代。可复用的是底层服务(GPS、相机压缩、卫星图打钉+RepaintBoundary 截图、pdf 导出)与依赖钉版经验(`app/BUILD_NOTES.md`)。

## 关键文件
- **设计 spec**:`docs/superpowers/specs/2026-06-21-grid-template-builder-design.md`(主文档,先读这个)
- 旧版代码:`app/lib/`(table-form,参考/复用底层服务)
- 需求:`prd/`(完整详细.docx + Excel 真实勘测表)
