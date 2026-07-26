# Smart City Survey System — Android App (Flutter)

> **⚠️ 历史文档(2026-06 立项背景)。** 现状与此已有很大出入:app 已是 macOS 桌面(设计)+ Android(填写)双端形态,局域网双向同步、模版多页、批量 PDF 导出、双语界面均已实现。当前进度见 `PROGRESS.md`,构建手册见 `grid_app/BUILD_NOTES.md`。

## Context（为什么做）

团队目前用 Excel 记录现场工程勘测（真实样本见 `New Microsoft Excel Worksheet.xlsx`——Site **647**，阿尔巴尼亚 Gjirokastër），照片靠手工管理。目标是做一个**离线优先的 Android App**：现场采集 GPS + 照片 + 结构化工程数据，并导出标准化的 **A4 单页 PDF 报告**，取代"Excel + 手工拍照"的流程，沉淀标准化、可导出的数据资产。

**源文档（项目根目录）：**
- `完整详细.docx` —— PRD（"Smart City Survey System"），原本定义为 Web **PWA**。
- `New Microsoft Excel Worksheet.xlsx` —— 真实勘测表单，**默认模版字段的来源**。

**本轮与用户确认的决策：**
1. **技术栈：** Flutter（Dart）→ **原生 Android APK**（*替换* PRD 的 PWA 架构）。
2. **节奏：** MVP 优先；但**模版编辑器**与**地图**经用户确认为刚需，已纳入核心（不再延后）。
3. **模版：** 维护**共享模版库**（多份命名模版），**项目从库中各选一个**，仍可编辑；库中预置一份从真实表单派生的默认模版。
4. **站点示意图：** Site diagram = **卫星地图 + 图钉标注**；策略为**联网标注 + 保存快照**，PDF 与离线查看用快照（现场确认基本有网，策略足够）。
5. **Site 粒度（现场确认）：** 一个 Site = 一个路口/区域；多杆位/多设备用**多个图钉**表示，对应一份表单、一张示意图、一页 PDF。
6. **PDF 生成（现场确认）：** 不绑定现场或网络——**现场或办公室随时可生成**，基于本地数据 + 已存卫星快照**离线也能出**；Site 记录**可后期编辑并重新生成 PDF**（`exported` 后不锁定记录，可反复重导/覆盖）。

数据层级沿用 PRD：`Project → Site → Survey`，外加共享的 `SurveyTemplate` 库。UI/字段全英文（PRD §2.5）。

---

## 技术栈与依赖

| 关注点 | 选择 |
|---|---|
| App | Flutter, Material 3, Android |
| 状态/DI | `provider` + Drift 响应式流（`.watch()`） |
| 离线存储 | `drift` + `sqlite3_flutter_libs`（SQLite）；嵌套对象用 JSON `TEXT` 列 + `TypeConverter` |
| 文件 | `path_provider`, `path`（压缩图片、地图快照落盘） |
| GPS | `geolocator` |
| 拍照 | `image_picker` + `flutter_image_compress`（<500KB） |
| **地图** | `flutter_map` + `latlong2`（Esri World Imagery 卫星瓦片，无需 API key） |
| **地图快照** | `screenshot`（捕获地图+图钉为静态图，供 PDF/离线） |
| 网络检测 | `connectivity_plus`（在线/离线，门控地图） |
| PDF | `pdf`（构建 A4）+ `printing`（单文档保存/分享/打印）+ `share_plus`（多文件分享：每 Site 一份模式） |
| 杂项 | `uuid`, `intl` |

状态管理保持轻量：仓储层暴露 Drift 流，UI 用 `StreamBuilder`，`provider` 注入仓储。

---

## 数据模型（Drift / SQLite）

嵌套/复杂值以 JSON `TEXT` 存储（文档式，贴合 PRD 的 IndexedDB 形态）：

- **survey_templates**（**模版库**，多份）：`id`、`name`、`sections`（JSON：`[{title, fields:[{key,label,type,required,unit?,options?}]}]`）。首次启动预置真实表单派生的默认模版。
- **projects**：`id`、`name`、**`templateId`**（从库中选定的模版）、`createdAt`
- **sites**：`id`、`projectId`、`name`、`city`、`gps`（JSON：`{lat,lon,accuracy,source,status}`）、`pins`（JSON：`[{lat,lon,label}]`，可编辑图钉）、`diagramImagePath`（卫星地图+图钉的快照路径）、`notes`、`imagePaths`（JSON `List<String>`，≤6）、`status`（`draft|completed|exported`）、`createdAt`
- **surveys**：`id`、`siteId`、`templateId`、`timestamp`、`data`（JSON `Map<String,dynamic>`，键为字段 `key`）

**字段类型：** `text | number | select | coordinate | deviceList`（在 PRD 的 `text|number|select` 上扩展 `coordinate` 经纬度文本、`deviceList` 可增行的"设备类型/数量/备注"，以忠实表达真实表单）。

**图片/快照：** 压缩 JPEG 与地图快照写入 `…/ApplicationDocuments/site_images/<siteId>/...`，DB 仅存相对路径（保持 DB 精简、完全离线）。

**模型取舍：** GPS、照片、示意图、notes 挂在 **Site**（物理资产，PDF 按 Site 出页）；**Survey** 只存模版结构化 `data` + 时间戳。MVP 每个 Site 一份主 Survey（schema 允许多份）。

**共享模版语义（用户已选）：** 编辑某模版会影响所有引用它的项目；表单按"当前模版"渲染，已删字段的历史 `data` 保留但不显示。MVP 可接受。

---

## 默认模版（从真实表单派生，预置入库）

`templates/default_template.dart`，分节 → 字段：

1. **Devices to Install** — `deviceList`（设备类型 / 数量 / 备注，原表 6 行）
2. **Poles & Structures** — cabinets on poles、new poles、new pole-arm length(m)、new pole height(m)、existing poles、existing pole-arm length(m)（number）
3. **Traffic Layout** — directions、lanes、junction boxes、traffic-light detectors（number）
4. **Network & Power** — PoE switches、fiber-optic transceivers、new UPS w/ battery（number）；power-supply / fiber-optic distribution cabinet coordinate（coordinate）
5. **Cable Estimates** — estimated fibre / electricity / LAN cable / pipe，单位 meters（number）
6. **Cameras** — number of current cameras（number）
7. **Other** — other considerations（text）

Site 级（非模版）：name、city、GPS、卫星示意图（图钉+快照）、照片、notes、status。

---

## MVP 范围（本期，全离线优先）

端到端可用流程：**新建项目（选模版）→ 建 Site → 采集 GPS / 卫星图打钉 / 拍照 / 填表单 → 保存/编辑 → 导出 PDF**。

1. **模版库 + 编辑器（刚需）** —— 列表（预置默认 + 自建）；新建/克隆/重命名/删除模版；编辑器增删/排序 section 与 field（key/label/type/required/unit/options）。
2. **Project List** —— 增删项目；新建时**从模版库选定一个模版**。
3. **Site List**（按项目）—— 增删 Site，显示状态。
4. **Site Detail** —— 编辑 name/city；**GPS 采集**（自动+精度+手动）；**卫星示意图**（见下）；**拍照**（相机/相册、压缩<500KB、宫格、≤6、可删）；notes；status。
5. **卫星地图示意图** —— `flutter_map` + Esri 卫星瓦片，以 Site GPS 居中；点按增/移/删**图钉**（可加标签；多个图钉代表该勘测点的多杆位/多设备）；**"保存快照"**按钮捕获当前地图+图钉为图片并落盘（`diagramImagePath`），同时持久化 `pins`。在线方可加载新瓦片；离线显示已存快照/占位。
6. **Survey Form** —— 按所属项目模版渲染各类字段，保存 `data`。
7. **PDF 导出** —— 单 Site 一页 A4（PRD §8）：HEADER（项目/站点/日期）· **GPS + 卫星示意图快照** · SURVEY SUMMARY（每节一行 `Title: label=value | label=value`）· PHOTO GRID（≤6、每行 3、cover）· NOTES。文件名 `Project_Site_YYYYMMDD.pdf`，经 `printing` 保存+分享。**可随时反复生成**（现场/办公室）、记录编辑后**重新生成覆盖**、**离线**用已存快照也能出。
   - **项目级"导出全部 Site"（导出时可选两种模式）**：① **合并为一份多页 PDF**（每 Site 一页，`Project_All_YYYYMMDD.pdf`，便于整体归档）；② **每个 Site 各一份单页 PDF**（多文件，`Project_<Site>_YYYYMMDD.pdf`，便于单独分发，一次性分享/存同一目录）。
8. **离线存储** —— 以上全部（SQLite + 落盘图片/快照）。

## 延后到后续迭代（已缩减）

- 离线预下载地图瓦片（本期为"联网标注+快照"）。
- 图钉拖拽精修、多 Survey 历史、模版字段更高级类型与校验。
- 项目数据 **Excel/CSV 汇总**导出 —— 后续需要时再加。

---

## 工程结构（`lib/`）

```
lib/
├── main.dart                      # 初始化 DB、预置默认模版、runApp
├── app.dart                       # MaterialApp、路由、主题
├── data/
│   ├── database.dart              # Drift DB + 表 + JSON TypeConverter
│   ├── models/                    # Project, Site, Survey, SurveyTemplate, FieldDef, GpsData, Pin, DeviceRow
│   └── repositories/              # project / site / survey / template 仓储
├── templates/default_template.dart
├── screens/
│   ├── template_list_screen.dart        # 模版库
│   ├── template_editor_screen.dart      # 模版编辑器（section/field 增删）
│   ├── project_list_screen.dart         # 含"选模版"
│   ├── site_list_screen.dart
│   ├── site_detail_screen.dart
│   ├── site_diagram_screen.dart         # 卫星地图 + 图钉 + 保存快照
│   └── survey_form_screen.dart
├── widgets/
│   ├── gps_capture.dart
│   ├── photo_grid.dart
│   ├── field_renderer.dart        # 按类型渲染字段
│   ├── field_editor.dart          # 模版编辑器里的字段编辑
│   └── device_list_field.dart
└── services/
    ├── location_service.dart      # geolocator 封装
    ├── image_service.dart         # 选图+压缩+落盘
    ├── map_snapshot_service.dart  # 捕获地图+图钉快照
    └── pdf_service.dart           # 构建+分享 A4 报告（单 Site；项目级=合并一份 或 每 Site 一份，导出时可选）
```

`android/app/src/main/AndroidManifest.xml` 权限：`INTERNET`（地图瓦片）、`ACCESS_FINE_LOCATION`、`ACCESS_COARSE_LOCATION`、`CAMERA`。卫星瓦片用 Esri World Imagery（免 key，需署名）；若日后要 Google 卫星图需 Google Maps API key（本期不用）。

---

## 构建顺序（获批后）

1. 在根目录初始化 Flutter（`flutter create .`，包名如 `com.scss.survey`），加依赖，设 `minSdk` ~23。
2. Drift DB + models + JSON 转换器 + 仓储；接 `provider`。
3. 默认模版预置 → **模版库列表 + 编辑器**（增删 section/field）。
4. Project List（选模版）→ Site List → Site Detail（CRUD，Drift 流）。
5. `location_service` + `gps_capture`；`image_service` + `photo_grid`。
6. **卫星地图示意图**：`flutter_map`+Esri 瓦片、图钉增移删、`map_snapshot_service` 保存快照、`connectivity_plus` 门控在线/离线。
7. `field_renderer`/`device_list_field` + Survey Form。
8. `pdf_service`（§8 的 A4 版式，含卫星快照）+ Site Detail 单 Site 导出/分享 + **项目级"导出全部 Site"两模式**（合并一份多页 / 每 Site 一份单页，Site List 入口、导出时选择；多文件分享用 `share_plus`）。
9. Android 权限、图标/名称、Material 3 主题、移动端单手布局。
10. 验证（见下）。

实现期会用任务列表跟踪以上步骤。

---

## 验证

- **静态/单测：** `flutter analyze`；`flutter test` —— 仓储 CRUD 往返、默认模版完整性、**模版编辑后字段持久化**、PDF "survey summary" 行格式化（`Title: k=v | k=v`）。
- **可编译为 APK：** `flutter build apk --debug`。
  - ✅ **Java（已确认）：** PATH `java` = **17.0.12 LTS**（sdkman，`JAVA_HOME` 指向 Java 17），满足 Android Gradle；Flutter 按"Android Studio 自带 JDK → `JAVA_HOME`"顺序选 JDK。Android SDK 位于 `~/Library/Android/sdk`。构建前会先跑 `flutter doctor` 确认 Android toolchain 与 licenses。
- **运行冒烟：** 在模拟器/真机（`adb`、`emulator` 在 `~/Library/Android/sdk` 下，仅未加入 PATH）走完整流程：建模版/选模版 → 建项目 → 建 Site → 采 GPS → 卫星图打钉并保存快照 → 拍照 → 填表单 → 导出 PDF；确认 PDF 含 HEADER、GPS、卫星示意图、分节汇总、照片宫格、notes，文件名 `Project_Site_YYYYMMDD.pdf`。
- **离线校验：** 开飞行模式确认除"加载新瓦片"外全流程可用并跨重启持久化；PDF 用已存的地图快照。
- **模版库校验：** 两个项目选不同模版，各自 Site 表单字段不同、互不影响。
- **可编辑重导：** 修改某 Site 记录后重新生成 PDF，内容反映更新且可反复覆盖。
- **项目级导出两模式：** ① 合并一份多页 PDF（每 Site 一页）；② 每个 Site 各一份单页 PDF（多文件）。两种都能成功生成/分享。
