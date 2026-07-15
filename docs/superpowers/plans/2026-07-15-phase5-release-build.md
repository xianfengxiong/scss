# Phase 5 — Android release 构建 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 给 grid_app 配正式 release 签名(keystore 进 git)、显示名改 "SCSS Survey"、产出 split-per-abi release APK,真机验证覆盖升级,写构建文档。

**Architecture:** 零 Dart 代码改动。标准 Flutter key.properties 签名模式(文件缺失自动回落 debug 签名);keystore 与 key.properties 按用户决定纳入 git(仓库无远端、纯本地)。交付物 = `app-arm64-v8a-release.apk`。

**Tech Stack:** Flutter(stable,Dart 3.6.1)、Android Gradle(groovy DSL)、keytool(JDK)、apksigner(build-tools 37.0.0)。

**Spec:** `docs/superpowers/specs/2026-07-15-phase5-release-build-design.md`

## Global Constraints

- 仓库根:`/Users/xxf/Desktop/scss`;Flutter 工程:`grid_app/`(applicationId `com.example.scss_grid`,**不改**)。
- 真机:三星 SM-A528B,设备 id `RZCRA03MZVX`;adb 用绝对路径 `/Users/xxf/Library/Android/sdk/platform-tools/adb`。
- apksigner:`/Users/xxf/Library/Android/sdk/build-tools/37.0.0/apksigner`。
- **零 Dart 代码/依赖改动**;`flutter test`(197)与 `flutter analyze`(0)保持不变。
- keystore 口令(进 git,用户已确认):`scss2026release`;alias `scss`。
- 工作分支:`phase5-release-build`(off main),验收通过后合并。
- git 提交信息结尾追加:
  `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`
  `Claude-Session: https://claude.ai/code/session_01HLu4MZHKyECaWzAHVT47eN`

---

### Task 1: 生成 keystore + key.properties,gitignore 放行并提交

**Files:**
- Create: `grid_app/android/keystore/scss-release.jks`(keytool 生成,二进制)
- Create: `grid_app/android/key.properties`
- Modify: `.gitignore:13-15`(根)
- Modify: `grid_app/android/.gitignore`(尾部 keystore 相关 4 行)

**Interfaces:**
- Produces: `grid_app/android/key.properties`,内含键 `storePassword`/`keyPassword`/`keyAlias`/`storeFile`;Task 2 的 build.gradle 按这些键名读取。`storeFile=../keystore/scss-release.jks` 是相对 `grid_app/android/app/` 的路径(gradle `file()` 在 app module 下解析)。

- [ ] **Step 1: 建分支**

```bash
cd /Users/xxf/Desktop/scss && git checkout -b phase5-release-build
```

- [ ] **Step 2: 生成 keystore**

```bash
mkdir -p /Users/xxf/Desktop/scss/grid_app/android/keystore
keytool -genkeypair -v \
  -keystore /Users/xxf/Desktop/scss/grid_app/android/keystore/scss-release.jks \
  -alias scss -keyalg RSA -keysize 2048 -validity 10000 \
  -storepass scss2026release -keypass scss2026release \
  -dname "CN=SCSS Survey, O=SCSS, C=AE"
```

- [ ] **Step 3: 验证 keystore 可读**

```bash
keytool -list -keystore /Users/xxf/Desktop/scss/grid_app/android/keystore/scss-release.jks -storepass scss2026release
```
Expected: 输出含 `scss` 条目、`PrivateKeyEntry`。

- [ ] **Step 4: 写 key.properties**

`grid_app/android/key.properties` 全文:

```properties
storePassword=scss2026release
keyPassword=scss2026release
keyAlias=scss
storeFile=../keystore/scss-release.jks
```

- [ ] **Step 5: gitignore 放行**

根 `.gitignore`:删除这两行(保留 `**/local.properties`):

```
**/*.keystore
**/key.properties
```

`grid_app/android/.gitignore`:删除尾部这 5 行:

```
# Remember to never publicly share your keystore.
# See https://flutter.dev/to/reference-keystore
key.properties
**/*.keystore
**/*.jks
```

两处各补一行注释(放行处):

```
# 本仓库为纯本地私有仓库,release keystore/key.properties 有意纳入 git 随仓库备份;
# 若将来给仓库加远端(尤其公开),必须先把它们移出 git 历史再推(见 grid_app/BUILD_NOTES.md)。
```

- [ ] **Step 6: 确认 git 能看到这两个文件**

```bash
cd /Users/xxf/Desktop/scss && git status --short | grep -E "keystore|key.properties"
```
Expected: 两个文件均出现且**无 ignored 标记**(`git check-ignore grid_app/android/key.properties` 应无输出、退出码 1)。

- [ ] **Step 7: Commit**

```bash
git add .gitignore grid_app/android/.gitignore grid_app/android/keystore/scss-release.jks grid_app/android/key.properties
git commit -m "chore(android): release keystore + key.properties(纯本地仓库,有意进 git)"
```

---

### Task 2: build.gradle release 签名接线 + 构建验签

**Files:**
- Modify: `grid_app/android/app/build.gradle`(顶部 + `buildTypes` 块)

**Interfaces:**
- Consumes: Task 1 的 `grid_app/android/key.properties`(键 `storePassword`/`keyPassword`/`keyAlias`/`storeFile`)。
- Produces: `flutter build apk --release --split-per-abi` 产出的 `grid_app/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`,签名 CN=SCSS Survey;Task 5 安装该文件。

- [ ] **Step 1: build.gradle 加 key.properties 读取(plugins 块之后、android 块之前)**

```groovy
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.withInputStream { keystoreProperties.load(it) }
}
```

(此处 `rootProject` = `grid_app/android/`,即读 `grid_app/android/key.properties`。)

- [ ] **Step 2: android 块内加 signingConfigs、替换 buildTypes**

在 `android { ... }` 内、`buildTypes` 之前加:

```groovy
    signingConfigs {
        release {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties['keyAlias']
                keyPassword = keystoreProperties['keyPassword']
                storeFile = file(keystoreProperties['storeFile'])
                storePassword = keystoreProperties['storePassword']
            }
        }
    }
```

把现有 `buildTypes`(目前 release 挂 `signingConfigs.debug` + 两行 TODO 注释)整块替换为:

```groovy
    buildTypes {
        release {
            // key.properties 在(本仓库随 git 带钥匙)→ 正式签名;
            // 不在(异常/裁剪的 clone)→ 回落 debug 签名,构建永不断。
            signingConfig = keystorePropertiesFile.exists() ? signingConfigs.release : signingConfigs.debug
        }
    }
```

- [ ] **Step 3: 构建 release(split-per-abi)**

```bash
cd /Users/xxf/Desktop/scss/grid_app && flutter build apk --release --split-per-abi
```
Expected: BUILD SUCCESSFUL;产出 `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`(另有 armeabi-v7a、x86_64)。

- [ ] **Step 4: 验签 + 看体积**

```bash
/Users/xxf/Library/Android/sdk/build-tools/37.0.0/apksigner verify --print-certs \
  /Users/xxf/Desktop/scss/grid_app/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk | head -3
ls -lh /Users/xxf/Desktop/scss/grid_app/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```
Expected: certs 输出含 `CN=SCSS Survey`;体积约 25–35MB(远小于 debug ~240MB;超出此范围不算失败,记录实际值)。

- [ ] **Step 5: Commit**

```bash
cd /Users/xxf/Desktop/scss && git add grid_app/android/app/build.gradle
git commit -m "build(android): release 用 key.properties 正式签名,缺失回落 debug"
```

---

### Task 3: 显示名改 "SCSS Survey"

**Files:**
- Modify: `grid_app/android/app/src/main/AndroidManifest.xml:10`

**Interfaces:**
- Produces: launcher 显示名 "SCSS Survey";Task 5 真机安装后人工确认。

- [ ] **Step 1: 改 label**

`android:label="scss_grid"` → `android:label="SCSS Survey"`(仅此一行;`applicationId`/icon 不动)。

- [ ] **Step 2: 静态验证**

```bash
grep -n 'android:label' /Users/xxf/Desktop/scss/grid_app/android/app/src/main/AndroidManifest.xml
```
Expected: 唯一一处,值为 `SCSS Survey`。

- [ ] **Step 3: Commit**

```bash
cd /Users/xxf/Desktop/scss && git add grid_app/android/app/src/main/AndroidManifest.xml
git commit -m "chore(android): 桌面显示名 scss_grid → SCSS Survey"
```

---

### Task 4: BUILD_NOTES.md + PROGRESS.md 更新

**Files:**
- Create: `grid_app/BUILD_NOTES.md`
- Modify: `doc/PROGRESS.md`(第 3、6 行现状描述 + §下一步)

**Interfaces:**
- Consumes: Task 1–3 的既成事实(keystore 路径、口令、构建命令、显示名)。

- [ ] **Step 1: 写 `grid_app/BUILD_NOTES.md`**(全文)

````markdown
# grid_app 构建笔记

## Release 构建与交付

```bash
cd grid_app
flutter build apk --release --split-per-abi
```

- **交付物**:`build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`(现代安卓机基本全是 arm64;SM-A528B 即是)。
- **版本号**:`pubspec.yaml` 的 `version: 1.0.0+N`。每次对外交付把 build number `+N` 递增(或临时用 `--build-number=N` 覆盖),同号覆盖安装会被 Android 拒绝降级。
- **体积参考**:release arm64 约 25–35MB(debug fat APK ~240MB 属正常,勿用 debug 包交付)。

## 签名

- keystore:`android/keystore/scss-release.jks`(alias `scss`);口令见 `android/key.properties`。
- `android/app/build.gradle` 自动读取 `android/key.properties`:文件在 → 正式签名;不在 → 回落 debug 签名(构建不中断,但产物只能覆盖同为 debug 签名的旧装)。
- ⚠️ **本仓库为纯本地私有仓库,keystore/key.properties 有意进 git**(随仓库备份、换机可续)。**若将来给仓库加远端(尤其公开),必须先把这两个文件移出 git 历史**(`git filter-repo` 或重建仓库)再推,并另行保管 keystore。
- keystore 一旦丢失,无法再对已装用户做覆盖升级(须卸载重装、丢本机数据)——本仓库即备份,别丢仓库。

## 安装(真机 SM-A528B)

```bash
ADB=/Users/xxf/Library/Android/sdk/platform-tools/adb
$ADB -s RZCRA03MZVX install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

- debug 签名版与 release 签名版**不能互相覆盖**:首次从 debug 换 release 须先 `adb uninstall com.example.scss_grid`(本机数据清空)。
- release 版不可 `run-as`(拉数据库等 debug 手段失效)。

## 依赖钉版(动版本前先读)

见 `pubspec.yaml` 内注释:drift 2.28.2 / drift_dev 2.28.0 / build_runner 2.4.15(Dart 3.6.1 上限)、geolocator ^13(14.x 需更新 Flutter)。旧 app 的钉版经验另见 `app/BUILD_NOTES.md`(share_plus/connectivity_plus 相关,grid_app 未引入)。
````

- [ ] **Step 2: 更新 `doc/PROGRESS.md`**

① 第 3 行日期改 `_最后更新:2026-07-15_`。
② 第 6 行"现状一句话"段末尾,把 `分支 phase4-devicechecklist(main 之上 = 原实现 + 3 个 fix commit)待合并 main → Phase 4 续做 select / date / checkbox。` 替换为:

```
Phase 4 已合并 main @ `2e1344d`(快进,分支已删)。**2026-07-15 决策:Phase 4 余下控件(select/date/checkbox/staticText/调色板)暂缓——当前业务用不到;NotoSansSC 取消——现场用不到中文(偶发中文在 PDF 显示为方框、不崩,可接受)。Phase 5 = 纯 release 构建**(正式签名 keystore 进 git(纯本地仓库)/ 显示名 SCSS Survey / split-per-abi arm64 交付,见 `docs/superpowers/specs/2026-07-15-phase5-release-build-design.md` 与 `grid_app/BUILD_NOTES.md`)。
```

③ `## 下一步:合并 → Phase 4 余下控件及之后` 一节整节替换为:

```markdown
## 下一步(2026-07-15 调整后)

1. **Phase 5 release 构建**(本期,spec `2026-07-15-phase5-release-build-design.md`):签名/显示名/split-per-abi/真机覆盖升级验证/BUILD_NOTES。
2. **暂缓池(用户拍板,现在用不到)**:Phase 4 余下控件(select/date/checkbox/staticText 样式/调色板补全);NotoSansSC 内嵌(取消,恢复时的技术备忘见 spec §1)。
3. **待办池**:#1『保存/恢复』体验(autosave / Fill 续填 / Surveys 入口可发现性);multiImage 6 图 PDF contain 参差(杠杆=控件做高);拖移左上角吸附指针;`_colX`/`_rowY` 并入 geometry;取消选中/空白点选负路径测试;deviceChecklist 两 defer(加行空间不足静默无反馈 / shrink 后孤立 fill 值未清)。
```

- [ ] **Step 3: Commit**

```bash
cd /Users/xxf/Desktop/scss && git add grid_app/BUILD_NOTES.md doc/PROGRESS.md
git commit -m "docs: BUILD_NOTES(release 签名/构建/交付)+ PROGRESS 对齐 2026-07-15 决策"
```

---

### Task 5: 真机部署、覆盖升级验证、回归兜底(含人工检查点)

**Files:** 无代码改动;产物与设备操作。

**Interfaces:**
- Consumes: Task 2 的 `app-arm64-v8a-release.apk`(重建以含 Task 3 显示名)。

- [ ] **Step 1: 重建(确保包含显示名改动)**

```bash
cd /Users/xxf/Desktop/scss/grid_app && flutter build apk --release --split-per-abi
```
Expected: BUILD SUCCESSFUL。

- [ ] **Step 2: 回归兜底(零 Dart 改动的证明)**

```bash
cd /Users/xxf/Desktop/scss/grid_app && flutter analyze && flutter test
```
Expected: analyze 0 issues;197 tests passed(注意:不要用 `| tail` 管道吞退出码,直接跑、看退出码)。

- [ ] **Step 3: 卸载 debug 版、装 release(⚠️ 破坏性,用户已在 spec 阶段确认机上测试数据可丢)**

```bash
ADB=/Users/xxf/Library/Android/sdk/platform-tools/adb
$ADB -s RZCRA03MZVX uninstall com.example.scss_grid
$ADB -s RZCRA03MZVX install /Users/xxf/Desktop/scss/grid_app/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
$ADB -s RZCRA03MZVX shell monkey -p com.example.scss_grid 1
```
Expected: uninstall/install 均 `Success`;app 拉起。

- [ ] **Step 4: 基础截图核验(agent 可做)**

```bash
$ADB -s RZCRA03MZVX exec-out screencap -p > /private/tmp/claude-501/-Users-xxf-Desktop-scss/ac9b0192-1006-4f67-9a36-4089cffce7f3/scratchpad/release_home.png
```
查看截图:模板列表页正常渲染(release/R8 未把 app 弄崩)。launcher 显示名可用 `$ADB -s RZCRA03MZVX shell "cmd package resolve-activity --brief com.example.scss_grid"` 辅助,最终以人工在桌面看到 "SCSS Survey" 为准。

- [ ] **Step 5: 人工冒烟(用户,human checkpoint)**

用户在真机跑通:新建模板(放几个控件)→ Fill:GPS 取点 / 拍照 / **卫星图拉瓦片(验证 release manifest INTERNET)**/ 勾选表 → Export PDF → Save → Surveys 列表恢复。任一环节异常即停,走 systematic-debugging。

- [ ] **Step 6: 覆盖升级验证**

```bash
cd /Users/xxf/Desktop/scss/grid_app && flutter build apk --release --split-per-abi --build-number=2
$ADB -s RZCRA03MZVX install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
$ADB -s RZCRA03MZVX shell monkey -p com.example.scss_grid 1
```
Expected: `install -r` `Success`(同签名覆盖不拒);拉起后用户确认 Step 5 建的模板/survey **还在**(release 化核心收益)。

- [ ] **Step 7: 合并**

用户验收通过后,用 superpowers:finishing-a-development-branch 把 `phase5-release-build` 合并回 main、删分支。
