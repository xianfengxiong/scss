# grid_app 构建笔记

## 双端形态与同步(2026-07-26)

同一代码库出两个形态:**macOS 桌面端**(模版设计为主,首页=模版列表,AppBar「同步」= 服务端)与 **Android 手机端**(填写为主,首页=调查表列表,AppBar「同步」= 客户端)。手机端仍保留完整 builder(首页右上「Templates」进入)。

**同步使用**:手机与电脑连同一 WiFi → 电脑打开「同步」页(显示地址+6 位配对码,页面开着服务才在)→ 手机「同步」页输入地址与配对码(首次之后自动记住)→「开始同步」。双向合并规则:同 id 取 updatedAt 新者(LWW);删除经墓碑传播,删除后另一端又编辑(更晚)则复活。图片按引用清单传输,答案里只存文件名(`documents/survey_images/` 平面目录)。协议 v1,端口 17423,token 经 `x-sync-token` 头校验。

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
- Windows 端代码同源,但需在 Windows 机器构建,且 flutter_image_compress 无 Windows 实现(桌面只做设计影响不大,做填写需旁路)。

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
- 旧 app 的钉版经验另见 `app/BUILD_NOTES.md`(share_plus/connectivity_plus 相关,grid_app 未引入)。

## 安装(真机 SM-A528B)

```bash
ADB=/Users/xxf/Library/Android/sdk/platform-tools/adb
$ADB -s RZCRA03MZVX install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

- debug 签名版与 release 签名版**不能互相覆盖**:首次从 debug 换 release 须先 `$ADB -s RZCRA03MZVX uninstall com.example.scss_grid`(本机数据清空)。
- release 版不可 `run-as`(拉数据库等 debug 手段失效)。
