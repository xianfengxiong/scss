# 保存/恢复体验(#1)设计 spec

日期:2026-07-15 · 状态:用户已批准设计,待写实现计划

## 1. 背景与问题

Phase 4 真机验收发现(经 DB 实证):数据没有丢,但体验上『保存后重进全丢』——

- `TemplateListScreen._fill()` 每点一次 Fill 就新建空白 `Survey(id: 'srv_<ts>')`,没有"继续上次"。
- `FillScreen` 只有手按 Save 才落库,直接退出静默丢弃本次输入。
- 恢复唯一入口是 AppBar 小图标 → Surveys 全局列表,难发现。
- `Survey.name` 恒等于模板名、不可改、无时间戳——列表里多份同名无法区分。

用户工作形态(2026-07-15 确认):**一个模板会建多份 survey**(如每站点一份)。

## 2. 方案(已选甲)

**甲(选定)·Fill → 底部 sheet**:列该模板的 survey(最近更新倒序)+『+ 新建 Survey』;模板尚无 survey 时跳过 sheet 直接进新建命名框。恢复入口就在 Fill 按钮上,可发现性连根解决。
已否决:乙·独立 per-template 列表页(多一跳,无增益);丙·Fill 直接续填最近+长按新建(隐藏功能,不适合多份选择)。

## 3. 模型与存储(零 Drift schema 变更)

- `Survey` 加 `updatedAt`(`DateTime`),序列化进 JSON blob(ISO8601 字符串);旧数据缺字段 → 解析为 epoch(1970)兜底,排序自然垫底,显示时间时对 epoch 显示占位(如 '—')。
- `SurveyStore` 加 `Future<List<Survey>> byTemplate(String templateId)`:Drift 实现用现有 `templateId` 列 where;`InMemorySurveyStore` 过滤实现。排序统一在 store 内做:`byTemplate` 与 `all` 均按 updatedAt 倒序返回(两实现一致,UI 不再自行排序)。
- `upsert` 语义不变;`updatedAt` 由调用方在写入前盖当前时间(store 不隐式改数据)。

## 4. 新建流程

- sheet 的『+ 新建 Survey』(或模板无 survey 时直接)→ 命名对话框,预填 `『<模板名> yyyy-MM-dd』`,可直接确认。
- **确认即落库**(upsert 带 updatedAt),随后进 FillScreen。显式命名过的空 survey 是合法的"进行中"状态。
- 与 Phase 2『保存时才落库』决策的关系:该决策防的是"误点 Fill 即产生空白孤儿";现在新建有命名框把关、不存在误入路径,故新建即落库不违背其意图。

## 5. FillScreen 自动保存

- **移除 Save 按钮**(Export/PDF 保留)。
- `onChanged` → **500ms 防抖** `upsert`(每次写入前 `updatedAt = now`)。
- 退出(pop)/`dispose` 时 flush 尚未落盘的 pending 改动(同步取消 timer + 立即 upsert)。
- 效果:来电/切后台/被系统杀,最多丢最后约半秒输入。
- 图像类控件值(路径/嵌套 Map)照常随 JSON 落库,无特殊处理。

## 6. Surveys 全局列表强化(入口保留)

- 排序:updatedAt 倒序。
- subtitle:`<模板名> · <相对时间> · N fields filled`(模板名需批量取:列表加载时把 templateStore.all() 做成 id→name map;模板已删则显示 templateId 占位)。
- 行尾加改名按钮 → 对话框(预填当前名),确认 upsert(updatedAt 同步刷新)。
- 恢复(tap 行)行为不变。

## 7. 触点文件

- `lib/model/survey.dart`(+updatedAt/JSON)
- `lib/data/survey_store.dart` + `lib/data/app_database.dart`(byTemplate;Drift where)
- `lib/builder/template_list_screen.dart`(_fill 改 sheet 流程 + 新建命名框)
- `lib/fill/fill_screen.dart`(autosave,去 Save 按钮)
- `lib/fill/survey_list_screen.dart`(排序/subtitle/改名)
- 新增小组件可内联(sheet/对话框用 showModalBottomSheet/showDialog,无需新文件;若 propEditor 式复用出现再抽)

## 8. 测试

- 模型:JSON 往返含 updatedAt;缺字段兜底 epoch。
- store:byTemplate 过滤 + 倒序(两实现同一组测试跑)。
- widget:Fill 有 survey → sheet 列表可选中进 FillScreen;无 survey → 直接命名框;新建确认即 upsert。
- autosave:改值后 fake 时钟推进 → 恰一次 upsert;连续改值防抖合并;pop 时 flush;Save 按钮不存在。
- 改名:对话框确认后列表刷新、store 中 name/updatedAt 更新。

## 9. 不做(YAGNI)

- survey 复制/归档/搜索;autosave 冲突处理(单机单用户);『已保存』指示器(信任 autosave);模板列表显示 survey 计数。
