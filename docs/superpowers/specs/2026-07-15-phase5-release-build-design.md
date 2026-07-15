# Phase 5 — Android release 构建(设计 spec)

日期:2026-07-15 · 状态:用户已批准设计,待写实现计划

## 1. 背景与范围

Phase 4 deviceChecklist 已合并 main(`2e1344d`,197 测试绿),真实勘测表 100% 可建模。用户拍板:

- **Phase 4 余下控件(select / date / checkbox / staticText / 调色板补全)暂缓不做**——当前业务用不到。
- **NotoSansSC 内嵌取消**——现场用不到中文;即便偶尔输入中文,PDF 显示为方框、app 不崩,风险可接受。技术备忘(若将来恢复此项):pdf 3.11.3 的 `TtfWriter.withChars` 导出时自动按用字子集嵌入,字体资产大小只影响 APK 体积、不影响 PDF 文件大小;改造点只需 `renderTemplate` 加 `pw.Page(theme: ThemeData.withFont(base, bold))`,控件的 `pw.TextStyle` 自动继承,控件代码零改动。

**本期只做 release 构建**:正式签名 + 显示名 + release APK 产物 + 真机验证 + 文档。**零 Dart 代码改动**。

## 2. 签名(标准 key.properties 模式)

- `keytool` 生成 `grid_app/android/keystore/scss-release.jks`(RSA 2048、有效期 10000 天、alias `scss`)。
- 口令等写 `grid_app/android/key.properties`(storePassword / keyPassword / keyAlias / storeFile 相对路径)。口令由实现时生成并直接写入该文件。
- `build.gradle` 按 Flutter 官方模式读取:文件存在 → release 用正式签名;**不存在 → 回落 debug 签名**,构建永不断。
- **keystore 与 key.properties 均进 git**(用户明确决定;仓库无远端、纯本地,keystore 随仓库备份、换机可续)。⚠️ 若将来给仓库加远端(尤其公开),须先把这两个文件移出 git 历史再推。
- 需确认 `.gitignore` 不挡这两个文件(Flutter 模板常默认忽略 `key.properties`)。

## 3. 显示名

`AndroidManifest.xml` 的 `android:label`:`scss_grid` → **`SCSS Survey`**。不动 `applicationId`(仍 `com.example.scss_grid`,同 id 才能覆盖升级),图标不动(需美术素材,后续想换再说)。

## 4. 构建产物

- `flutter build apk --release --split-per-abi`,交付 `app-arm64-v8a-release.apk`(真机 SM-A528B 为 arm64,现代安卓机基本全是)。预期 ~25–35MB(对比 debug ~240MB)。
- R8 压缩/混淆用 Flutter release 默认,不加自定义 proguard 规则;所用插件(geolocator / image_picker / flutter_map / printing / drift / sqlite3_flutter_libs)均为主流包自带 consumer rules,风险低,靠真机冒烟兜底。
- 版本号维持 `1.0.0+1`;此后每次对外交付 bump build number(`+2`、`+3`…),规则写进 BUILD_NOTES。

## 5. 真机验证(SM-A528B,adb 绝对路径 `/Users/xxf/Library/Android/sdk/platform-tools/adb`)

- ⚠️ **破坏性前提(用户已确认可丢)**:release 与 debug 签名不同,装 release 前必须卸载现有 debug 版,机上测试模板/survey 清空;release 版不可 `run-as`,数据无法迁回。
- 冒烟路径:新建模板(逐控件)→ 填写(GPS / 相机 / **卫星图拉瓦片 = 验证 release manifest 的 INTERNET 生效**)→ PDF 导出 → 保存 → Surveys 恢复。
- **覆盖升级验证**:改 build number 重新构建 → `adb install -r` → 确认既有数据保留(同签名覆盖安装是 release 化的核心收益)。
- 无 Dart 改动 → `flutter test` 197 绿 + `flutter analyze` 0 保持即可;构建配置不写单测。

## 6. 文档

- 新建 `grid_app/BUILD_NOTES.md`:签名文件位置、构建命令、交付哪个 APK、版本号 bump 规则、"keystore 勿出仓库"警示。
- 更新 `doc/PROGRESS.md`:修掉滞后的『phase4-devicechecklist 待合并』描述(实际已合并 `2e1344d`、分支已删);记录本期决策(Phase 4 余控件暂缓、NotoSansSC 取消及原因)。

## 7. 已否决的替代方案

- 口令硬编码进 `build.gradle`(少一个文件,但以后想撤出 git 得改构建脚本)。
- fat APK(全架构一个文件 ~50–60MB,没必要)。
- 继续 debug 签名(换电脑/重装系统后签名变化,真机须卸载重装丢数据)。
- NotoSansSC 全量/子集内嵌(本期取消,备忘见 §1)。
