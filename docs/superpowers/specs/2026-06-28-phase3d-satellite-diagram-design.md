# Phase 3d — SatelliteDiagram 卫星图打钉截图控件 设计

日期: 2026-06-28
状态: 设计待评审

## 目标

新增 `SatelliteDiagramControl`(type = `satelliteDiagram`),让一个网格格子承载"开卫星地图 → 打钉 → 截图"的现场能力,截图嵌入 PDF。spec §8 标注卫星图打钉截图为"现场端最关键、最不能回归的能力",移植旧 `app/lib/screens/site_diagram_screen.dart`(已验证可用)的核心,但与数据库/`Site` 模型解耦,做成自包含控件插件(ControlSpec + 注册 1 行)。

这是 spec §12 第 3 期"现场能力"的最后一块(GPS / image / multiImage 已合并)。

## 已确认决策

- **值形态 = 截图 + 钉坐标**(非"只存路径"):`data[key]` 存一个 JSON 安全的 Map `{path, pins, center, zoom}`。重开地图回填上次的钉/中心/缩放,可微调某颗钉再重截。
- **钉带标签 + 点钉改/删**:点地图空白处落红钉;点已有钉弹框可填标签(可选,如杆号 P1)或删除;标签画在钉下方,烤进截图。沿用旧 app。
- **caption 画进 PDF**:`caption` 非空时在截图下方加一行小字标题(spec 列了 `caption?`)。
- **去掉离线橙条**:不引 `connectivity_plus`。离线时瓦片加载失败本身肉眼可见;钉与截图照常工作。少一个要钉版/验证的依赖。
- **截图技术 = `screenshot` 包**:地图瓦片异步加载,`ScreenshotController.capture(delay: 250ms)` 等瓦片画完再截;旧 app 已验证。裸 `RepaintBoundary` 需自管 post-frame/delay/pixelRatio,更易踩坑。
- **初始中心**:仅"首填(无存值)"时取当前 GPS 定心(勘测员站在现场);取不到/拒权落到固定兜底 `LatLng(40.0759, 20.1389)`(Gjirokastër,阿尔巴尼亚,旧 app 兜底)。重开直接用存的 `center/zoom`,不再请求 GPS。
- **清除粒度**:`onChanged(null)` 一次清掉截图 + 钉 + 中心(符合 spec"清掉截图与钉,可重测")。
- **空值合法**:没截图时 `validate` 返回 null、PDF 画占位(与 image 一致)。

## 架构 — 方案 A(全屏地图路由 + 专用控件)

控件 `fillWidget` 在格子里显示截图缩略图(有图:图 + ✕ 清除;无图:"开地图"按钮)。点击 `Navigator.push` 全屏 `SatelliteDiagramScreen`(打钉精度不受格子大小限制),返回 `{pins, center, zoom, path}`,控件整体存进值。PDF 嵌 `path` 截图。

否决的备选:
- **B 格内内联地图**:格子才几厘米,打钉精度极差、截图进 PDF 糊。否决。
- **C image 控件 + "地图"来源**:只能回传路径,装不下选定的钉坐标值形态。否决。

## 数据模型

`data[key]` 存:

```
{ 'path':   '<survey_images/xxx.png 绝对路径>',
  'pins':   [ {'lat': .., 'lon': .., 'label': ''}, ... ],
  'center': {'lat': .., 'lon': ..},
  'zoom':   17.0 }
```

- 未填 = `null`;清除后 = `null`。
- props: `{'key': 'diagram', 'caption': ''}`。
- 旧截图在覆盖保存时**不主动删**(与现有 image 控件一致:简单、避免误删;磁盘清理非本期范围)。

### `Pin` 模型 — `lib/model/pin.dart`(移植)

移植旧 `app/lib/models/pin.dart`:`final double lat/lon; final String label;` + `copyWith` + `toJson`/`fromJson`(label 默认 `''`)。控件值里的 `pins` 用它序列化。

## Control 实现 — `lib/controls/satellite_diagram_control.dart`

仿 `ImageControl` 形状(注入可空 `LocationService? location` 与 `ImageService? image`,null 时开图/落盘为 no-op,便于测试)。

```
class SatelliteDiagramControl extends ControlSpec {
  final LocationService? location;
  final ImageService? image;
  SatelliteDiagramControl({this.location, this.image});

  type      = 'satelliteDiagram'
  label     = 'Satellite Diagram'
  icon      = Icons.map_outlined
  defaultProps() => {'key': 'diagram', 'caption': ''}

  // 纯函数值解析(仿 multiImage._paths,重点单测):
  //   从 data[key] 的 Map 安全取出 path/pins/center/zoom,
  //   对 null / 缺字段 / 类型错乱(pins 非 List 等)均返回安全默认。

  resolvePdfValue(cell, value) async  // value['path'] 存在→读 bytes;空/缺/不存在→null
  paintPdf(cell, data)                // data[key] 是 Uint8List→pw.Image(contain);
                                      //   caption 非空→图下方加小字标题;否则 pw.SizedBox
  validate(cell, value) => null       // 空值合法
  previewWidget(cell)                 // 建模占位 '[satellite]'
  propEditor(cell, onChanged)         // key + caption 两个字段
  fillWidget(cell, value, onChanged)  // 缩略图 + 清除 / "开地图"按钮 → push 地图屏
}
```

`fillWidget` 用注入的 `image.saveBytes` 与 `location` 构造并 `Navigator.push` 地图屏;返回结果后 `onChanged({path, pins(toJson), center, zoom})`;✕ → `onChanged(null)`。

注册(`default_controls.dart`):加 `r.register(SatelliteDiagramControl(location: location, image: image))`,复用已注入服务。

## 地图屏 — `lib/fill/satellite_diagram_screen.dart`

移植旧 `site_diagram_screen.dart`,**解耦 `Site`/数据库**,纯输入输出:

```dart
class SatelliteDiagramScreen extends StatefulWidget {
  final List<Pin> initialPins;        // 重开回填;首填 []
  final LatLng? initialCenter;        // 重开=存的 center;首填 null
  final double initialZoom;           // 重开=存的 zoom;首填 17
  final LocationService? location;    // 首填取当前 GPS 定心;注入、可空
  final Future<String> Function(Uint8List) saveBytes;  // 截图落盘回调(见下)
}
// pop: null(取消) 或 ({List<Pin> pins, LatLng center, double zoom, String path})
```

- `FlutterMap` + Esri World Imagery 瓦片(免 key,`maxNativeZoom: 19`,`userAgentPackageName: 'com.scss.scss'`)。持有一个 `MapController`,保存时经 `mapController.camera.center`/`.zoom` 读当前相机状态(flutter_map 8.x API)。
- 点空白 → 落红钉;点钉 → 弹框改标签 / 删除;标签画钉下方。
- AppBar 保存:`ScreenshotController.capture(delay: 250ms)` → `saveBytes(bytes)` 落盘 → `pop` 返回 `{pins, center(MapController 读取的当前中心), zoom(当前缩放), path}`。返回不保存 = `pop(null)`。
- 首填初始中心:`location?.getCoordinate()` 成功→该点;失败/拒权/null→兜底 `LatLng(40.0759, 20.1389)`。
- **不写 widget test**:依赖平台通道(flutter_map / screenshot / geolocator),单测 VM 不可用;文件头注释写明,与 `ImagePickerImageService` 现有注释一致。

## 服务改动 — `ImageService.saveBytes`

`ImageService` 抽象类加一个方法(其余不动):

```dart
abstract class ImageService {
  Future<String?> capture(ImageSource source);
  Future<String> saveBytes(Uint8List bytes, {String ext = 'png'});  // 新增
}
```

`ImagePickerImageService.saveBytes`:写进共享 `survey_images/` 目录、`uuid` 命名、返回绝对路径(移植旧 app `saveBytes`,去掉 siteId 参数)。地图屏经注入回调使用,不直接依赖 image_picker,保持可测。

## 新增依赖 — `grid_app/pubspec.yaml`

| 包 | 用途 | 备注 |
|---|---|---|
| `flutter_map: ^8.3.0` | 卫星瓦片地图 | 旧 app 同版已验证 |
| `latlong2` | `LatLng`(flutter_map 配套) | 跟随 flutter_map |
| `screenshot: ^3.0.0` | 等瓦片画完再截图 | 旧 app 同版 |

**风险点 0(TDD 计划第一步)**:`flutter pub get` 验证三包与当前 Flutter(3.27 / Dart 3.6.1) + 已钉版 `geolocator 13.x` 无冲突;若 flutter_map 8.x 传递依赖撞车,按 geolocator 先例钉版解决。

## 测试策略

分层:纯逻辑单测 + 设备能力真机验收(与 image/multiImage 同理)。

**可单测(TDD 主体,`test/`)**
- `Pin`:`toJson`/`fromJson` 往返、`copyWith`、`label` 默认 `''`。
- 控件值解析纯函数:从 `data[key]` Map 安全取 path/pins/center/zoom;对 null、缺字段、类型错乱返回安全默认。
- `defaultProps()` / `dataKey()` 契约。
- `resolvePdfValue`:`path` 存在→bytes;空/null/文件不存在→null(临时目录写真 png 测存在分支,仿 image)。
- `paintPdf`:有 `Uint8List`→`pw.Image`;无→`pw.SizedBox`;`caption` 非空→输出含标题(结构断言,仿 multiImage)。
- `validate`:空值合法返回 null。
- 注册表:`buildDefaultRegistry` 后 `specFor('satelliteDiagram')` 非空、`all()` 含它且排序正确。

**真机验收(走查清单,不自动化)**
- 建模:调色板加 satelliteDiagram 格、检视器改 key/caption、空图 PDF 预览占位正常。
- 填写:点格→全屏地图→当前 GPS 定心(或兜底)→点图落钉→改标签/删钉→保存→缩略图回填→✕清除→重开能看到上次的钉/中心(验 pins/center/zoom 持久化往返)。
- PDF:截图嵌入、caption 标题显示、`fit:contain` 不变形。
- 真机三星 SM-A528B:离线下钉仍可用、保存的截图照常进 PDF。

## 文件清单

| 文件 | 动作 |
|---|---|
| `lib/model/pin.dart` | 新增(移植) |
| `lib/controls/satellite_diagram_control.dart` | 新增 |
| `lib/fill/satellite_diagram_screen.dart` | 新增(移植 + 解耦) |
| `lib/services/image_service.dart` | 改:加 `saveBytes` |
| `lib/controls/default_controls.dart` | 改:注册 1 行 |
| `pubspec.yaml` | 改:加 3 依赖 |
| `test/...` | 新增单测(Pin / 控件值解析 / resolvePdfValue / paintPdf / validate / 注册) |

## 非目标(本期不做)

- 多份截图 / 多图层。
- 离线瓦片缓存(瓦片在线拉取;离线时失败可见)。
- 钉之外的标注(线、面、测距)。
- 旧截图文件磁盘清理。
- 地图屏 widget 自动化测试。
