# grid_app 构建笔记

## 双端形态与同步(2026-07-26)

同一代码库出两个形态:**macOS 桌面端**(模版设计为主,首页=模版列表,AppBar「同步」= 服务端)与 **Android 手机端**(填写为主,首页=调查表列表,AppBar「同步」= 客户端)。手机端仍保留完整 builder(首页右上「Templates」进入)。

**同步使用**:手机与电脑连同一 WiFi → 电脑打开「同步」页(显示地址+6 位配对码,页面开着服务才在)→ 手机「同步」页输入地址与配对码(首次之后自动记住)→「开始同步」。双向合并规则:同 id 取 updatedAt 新者(LWW);删除经墓碑传播,删除后另一端又编辑(更晚)则复活。图片按引用清单传输,答案里只存文件名(`documents/survey_images/` 平面目录)。协议 v2(v2=模版多页 pages 格式,与 v1 端不互通——两端升级到同一版本即可),端口 17423,token 经 `x-sync-token` 头校验。

**模版多页**(2026-07-26):Template = `pages[]`,每页独立网格+控件,分页由用户显式控制(设计页页导航加/删/切页,新页沿用当前页网格);字段 key 跨页唯一,调查表答案仍是一份全局 map;PDF 按页序多页输出;旧单页模版 JSON 自动兼容读入。

## macOS 桌面端构建

```bash
cd grid_app
flutter build macos --release   # 产物 build/macos/Build/Products/Release/SCSS Survey.app
flutter run -d macos            # 开发调试
```

- 沙箱 entitlements(Debug+Release)已开 `network.client`/`network.server`/`files.user-selected.read-write`——**动 entitlements 后同步会静默断网,排查先看这里**。
- 部署目标 10.15(Podfile + pbxproj,flutter build 自动迁移过)。
- bundle id 仍为 `com.example.scssGrid`(个人工具不上店;沙箱容器路径 `~/Library/Containers/com.example.scssGrid/` 含本机库与图片,改 id = 换容器丢数据)。
- 分发给他人需 Developer ID 签名+公证(未配置);本机自用 `flutter run`/直接 open .app 即可。

## Windows 桌面端构建(2026-08-16)

代码同源:`isDesktopPlatform`(lib/services/platform_info.dart)把 Windows 一并当设计端,UI/同步/导出与 macOS 端完全一致。但 **Flutter 不支持交叉编译——必须在 Windows 机器上构建**:

1. 装 Flutter SDK(版本对齐本仓库,见下方工具链表)+ MSVC 工具链:**Build Tools for Visual Studio 2022 即可**(免费无 IDE,~6-7GB;下载页「Tools for Visual Studio」区,直链 aka.ms/vs/17/release/vs_BuildTools.exe),勾「使用 C++ 的桌面开发」工作负载(自带 MSVC v143/Windows SDK/CMake)。完整 VS Community 只在要调试 windows/runner 原生 C++ 时才需要。只装 VS Code 不行(无编译器),MinGW/Clang 不支持。
2. 装 **nuget.exe**(`winget install Microsoft.NuGet`,或手动下载 dist.nuget.org/win-x86-commandline/latest/nuget.exe 放入 PATH):geolocator_windows 的 CMake 用它拉 Microsoft.Windows.CppWinRT 包,PATH 没有就每次 build 提示 "Nuget.exe not found" 并临时下载;`flutter clean` 后重拉该包需联网(nuget.org)。
3. `flutter doctor` 确认 "Visual Studio" 一项打钩(Android toolchain 报叉可无视)。
4. 构建与运行:

```powershell
cd grid_app
flutter build windows --release   # 产物 build\windows\x64\runner\Release\
flutter run -d windows            # 开发调试
```

- **交付物**:`Release\` 整个目录就是免安装绿色版(scss_grid.exe + data\ + 若干 dll),整目录拷贝即可在别的 Windows 上运行;单拷 exe 跑不起来。窗口标题/产品名为 SCSS Survey。
- **防火墙**:首次打开「同步」页(监听 17423)Windows 会弹防火墙授权,勾选**专用网络**允许;错过弹窗手机就连不上,去「Windows 安全中心→防火墙→允许应用通过防火墙」补勾 scss_grid。
- **数据目录**:`%APPDATA%\com.example\scss_grid\`(scss_grid.sqlite + survey_images\)。Windows 走 ApplicationSupport 而非 Documents(lib/services/app_dirs.dart)——path_provider 在 Windows 的 Documents 是用户真实「文档」目录,不该往里倒库文件;macOS/Android 数据位置不变。
- **图片压缩**:flutter_image_compress 无 Windows 实现,image_service 已兜底——压缩不可用时直接存原图(Windows 上填写拍照的图片会偏大,同步与 PDF 不受影响)。
- **相机**:桌面 image_picker 无相机实现(macOS 同),图片控件走「相册」= 文件选择器。
- **中文系统编码坑**:系统代码页 936(GBK)下 MSVC 编插件源码报 C4819(被 /WX 升为 C2220「警告被视为错误」)。已在 windows/CMakeLists.txt 顶层加 `/utf-8` 修复(对 runner+全部插件生效);别去改源文件编码,也别关系统的 UTF-8 beta 选项来碰运气。
- 未做代码签名,别的机器首次运行 SmartScreen 可能拦「未知发布者」→「更多信息→仍要运行」。

## Release 构建与交付

```bash
cd grid_app
flutter build apk --release --split-per-abi
```

- **交付物**:`build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`(现代安卓机基本全是 arm64;SM-A528B 即是)。实测 22.1MB(2026-07-15,Flutter 3.44.6)。
- **版本号**:`pubspec.yaml` 的 `version: 1.0.0+N`。每次对外交付把 build number `+N` 递增(或临时用 `--build-number=N` 覆盖);Android 拒绝同号/降号覆盖安装。
- **勿用 debug 包交付**(fat debug APK ~240MB 且是 debug 签名)。

## 签名

- keystore:`android/keystore/scss-release.jks`(alias `scss`);口令见 `android/key.properties`。
- `android/app/build.gradle` 自动读取 `android/key.properties`:文件在 → 正式签名;不在 → 回落 debug 签名(构建不中断,但产物只能覆盖同为 debug 签名的旧装)。
- 验签:`$ANDROID_SDK/build-tools/<ver>/apksigner verify --print-certs <apk>`,应看到 `CN=SCSS Survey`。
- ⚠️ **keystore/key.properties 有意进 git**(随仓库备份、换机可续;2026-07-15 用户确认)。仓库远端为 **GitHub 私有仓库** `git@github.com:xianfengxiong/scss.git`——**保持 Private**;**若将来转公开,必须先把这两个文件移出 git 历史**(`git filter-repo` 或重建仓库)并更换签名 keystore(视同已泄露)。
- keystore 一旦丢失,无法再对已装用户做覆盖升级(须卸载重装、丢本机数据)——本仓库即备份,别丢仓库。

## 工具链配套(2026-07-15,Flutter 3.44.6 / Dart 3.12.2 / JDK 21)

| 组件 | 版本 | 备注 |
|---|---|---|
| Gradle wrapper | 8.7 | Flutter 3.44 下限 ≥8.7(原 8.3 会被 flutter gradle 插件直接拒) |
| AGP | 8.6.0 | Flutter 3.44 下限 ≥8.6(原 8.1.0 同上被拒) |
| Kotlin | 1.8.22 | 仅警告不阻塞,未升;Flutter 再升级若报 Kotlin 下限,升 `android/settings.gradle` 里的版本即可 |

- 升级 Flutter 后若构建报 "lower than Flutter's minimum supported version",按报错逐个抬 Gradle wrapper(`android/gradle/wrapper/gradle-wrapper.properties`)与 AGP(`android/settings.gradle`)。
- `pubspec.yaml` 里 drift 2.28.2 / drift_dev 2.28.0 / build_runner 2.4.15 的钉版理由是"Dart 3.6.1 上限",**现已升 Dart 3.12.2,钉版可择机放开**(放开属独立工作,需跑全量测试);geolocator ^13 的钉版理由(14.x 需新 Flutter API)同样可能已失效。动版本前先全量 `flutter test`。
- 旧 app 工程(含其 BUILD_NOTES 钉版经验,share_plus/connectivity_plus 相关)已于 2026-07-26 删除;需要时从 git 快照 `b8d431a` 找回。

## 安装(真机 SM-A528B)

```bash
ADB=/Users/xxf/Library/Android/sdk/platform-tools/adb
$ADB -s RZCRA03MZVX install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

- debug 签名版与 release 签名版**不能互相覆盖**:首次从 debug 换 release 须先 `$ADB -s RZCRA03MZVX uninstall com.example.scss_grid`(本机数据清空)。
- release 版不可 `run-as`(拉数据库等 debug 手段失效)。
