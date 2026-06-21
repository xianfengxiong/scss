# 进度 — Smart City Survey System (Flutter Android)

_最后更新:2026-06-21_

## 现状一句话
**方向调整:greenfield 重写。** 放弃旧的"线性行模型 + 逐行对话框编辑器",改为**所见即所得的 A4 网格模版构建器**;设计 spec 经多轮头脑风暴定稿并**已获用户复核通过**,下一步出第 1 期实现计划。**尚未开始编码。**

## ★ 2026-06-21 设计阶段成果(本次重点)
- **定稿设计 spec**:`docs/superpowers/specs/2026-06-21-grid-template-builder-design.md`(旧 `2026-06-21-multifield-editing-design.md` 已标作废,被本设计取代)。
- **技术栈拍板**:单一 **Flutter** Android app(Web 方案 pdfme/GrapesJS/SurveyJS/Form.io 经联网调研后否决,理由见 spec §2)。
- **核心模型**:A4 + 单"网格框"= PDF 输出范围;**行列尺寸为源、框大小派生**(默认等高等宽、可拖网格线非均分;框被 A4 封顶→永不超页、不分页);控件吸附网格、colSpan/rowSpan;一份模型驱动 建模/填写/PDF(WYSIWYG)。
- **关键设计点**:填写期只填不改结构;设备表定义期固定行只打勾;`multiImage` 固定外框+内部按张数铺满(图少更大,min3/max6);图像类控件支持清除;建模式空模版 PDF 预览;**控件插件化(ControlSpec 接口+注册表,加控件=1文件+登记1行)**;复用 GPS/相机/地图截图/pdf 底层,新增内嵌 NotoSansSC;Drift greenfield 无迁移。
- 头脑风暴的可视 mockup 留存在 `.superpowers/brainstorm/`。

## 下一步(明天继续)
1. **writing-plans**:针对 **spec §12 第 1 期(核心地基)** 出详细实现计划——数据模型 + 网格几何引擎 + ControlSpec 接口/注册表 + 单页 PDF 渲染器 + 建模式 PDF 预览(空模版)+ 最小建模画布(放/移/跨/拖线)。打通"建→存→预览 PDF"最小闭环。
2. 按计划 **TDD 实现**第 1 期(几何/轨道数学/不变式做成纯函数重点单测)。
3. 后续分期(填写闭环 → 现场能力 → 完善控件 → 打磨)见 spec §12。

## 旧版(已被取代,仅作历史)
第一阶段字段式 MVP、第二阶段表格式 TemplateRow 重构(`app/` 现有代码)均完成过并跑在模拟器上;因网格线不对齐、编辑器不通用,整体被本次 greenfield 网格设计取代。可复用的是底层服务(GPS、相机压缩、卫星图打钉+RepaintBoundary 截图、pdf 导出)与依赖钉版经验(`app/BUILD_NOTES.md`)。

## 关键文件
- **设计 spec**:`docs/superpowers/specs/2026-06-21-grid-template-builder-design.md`(主文档,先读这个)
- 旧版代码:`app/lib/`(table-form,参考/复用底层服务)
- 需求:`prd/`(完整详细.docx + Excel 真实勘测表)
