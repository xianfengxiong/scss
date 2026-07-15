# 保存/恢复体验(#1)Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fill 按钮变成"续填/新建"入口(bottom sheet),survey 可命名/改名/带更新时间,FillScreen 全自动保存(防抖 + 退出 flush),Save 按钮移除。

**Architecture:** `Survey` 加可空 `updatedAt`(JSON 内,零 Drift schema 变更);`SurveyStore` 加 `byTemplate` 且 `all`/`byTemplate` 统一按 updatedAt 倒序(排序在 store 内共享纯函数);UI 三屏各自小改。新增两个小文件:`survey_name_dialog.dart`(自持 controller 的命名对话框,新建与改名共用)、`time_label.dart`(纯函数:相对时间标签 + 日期戳)。

**Tech Stack:** Flutter 3.44.6 / Dart 3.12.2;既有 InMemory/Drift 双 store 测试惯例;widget test + `flutter_test`。

**Spec:** `docs/superpowers/specs/2026-07-15-save-restore-ux-design.md`

## Global Constraints

- 工程根:`/Users/xxf/Desktop/scss/grid_app`;所有命令在该目录跑(注意 shell cwd,git 用仓库根 `/Users/xxf/Desktop/scss`)。
- **零 Drift schema 变更**(updatedAt 存 JSON blob;`SurveyRows` 不动,`schemaVersion` 仍为 2)。
- `Survey` 的 const 构造必须保留(大量测试用 `const Survey(...)`)→ `updatedAt` 为**可空** `DateTime?`、默认 null;排序时 null 当 epoch 垫底,显示时 null 显示 `'—'`。
- UI 文案英文(与现有一致)。不新增 pub 依赖(日期格式手写,不引 intl)。
- 每任务结束:`flutter analyze` 0 issues、`flutter test` 全绿(基线 197,过程中逐步增加)。**不要用 `| tail` 之类管道跑测试(退出码会被吃掉),直接跑。**
- 工作分支:`save-restore-ux`(off main);全部完成后走 finishing-a-development-branch。
- git 提交信息结尾追加:
  `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`
  `Claude-Session: https://claude.ai/code/session_01HLu4MZHKyECaWzAHVT47eN`

---

### Task 1: `Survey.updatedAt`(模型)

**Files:**
- Modify: `grid_app/lib/model/survey.dart`
- Test: `grid_app/test/model/survey_test.dart`

**Interfaces:**
- Produces: `Survey.updatedAt`(`DateTime?`,默认 null);`toJson()` 仅在非 null 时写 `'updatedAt'`(ISO8601 字符串);`fromJson` 缺字段 → null;`copyWith({DateTime? updatedAt})` 可设置(null 参数=保留旧值,与其它字段一致)。

- [ ] **Step 0: 建分支**

```bash
cd /Users/xxf/Desktop/scss && git checkout -b save-restore-ux
```

- [ ] **Step 1: 写失败测试**(追加到 `test/model/survey_test.dart` 的 `main()` 内)

```dart
  test('updatedAt defaults to null and round-trips through JSON', () {
    const s = Survey(id: 's1', templateId: 't1', name: 'A');
    expect(s.updatedAt, isNull);
    expect(s.toJson().containsKey('updatedAt'), isFalse);

    final t = DateTime.parse('2026-07-15T10:30:00.000');
    final withTime = s.copyWith(updatedAt: t);
    final back = Survey.fromJson(withTime.toJson());
    expect(back.updatedAt, t);
  });

  test('fromJson without updatedAt yields null (legacy rows)', () {
    final back = Survey.fromJson({
      'id': 's1', 'templateId': 't1', 'name': 'A', 'data': {'k': 1},
    });
    expect(back.updatedAt, isNull);
    expect(back.data, {'k': 1});
  });
```

- [ ] **Step 2: 跑测试确认失败**

Run: `cd /Users/xxf/Desktop/scss/grid_app && flutter test test/model/survey_test.dart`
Expected: FAIL(`updatedAt` getter 不存在,编译错)

- [ ] **Step 3: 实现**(`lib/model/survey.dart` 全文替换为)

```dart
/// One filled-in instance of a template: answers keyed by each control's
/// `dataKey`. Structure lives in the template; a survey only holds values.
class Survey {
  final String id;
  final String templateId;
  final String name;

  /// Last time this survey was written (autosave/rename). Null on rows saved
  /// before this field existed; sorts as epoch, displays as '—'.
  final DateTime? updatedAt;

  /// Answers, keyed by control dataKey (e.g. a field's `props['key']`).
  /// The same map is handed to `renderTemplate` so the PDF prints what was
  /// filled (WYSIWYG).
  final Map<String, dynamic> data;

  const Survey({
    required this.id,
    required this.templateId,
    required this.name,
    this.updatedAt,
    this.data = const {},
  });

  Survey copyWith({
    String? id,
    String? templateId,
    String? name,
    DateTime? updatedAt,
    Map<String, dynamic>? data,
  }) =>
      Survey(
        id: id ?? this.id,
        templateId: templateId ?? this.templateId,
        name: name ?? this.name,
        updatedAt: updatedAt ?? this.updatedAt,
        data: data ?? this.data,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'templateId': templateId,
        'name': name,
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
        'data': data,
      };

  factory Survey.fromJson(Map<String, dynamic> j) => Survey(
        id: j['id'] as String,
        templateId: j['templateId'] as String,
        name: j['name'] as String,
        updatedAt: j['updatedAt'] == null
            ? null
            : DateTime.parse(j['updatedAt'] as String),
        data: Map<String, dynamic>.from(j['data'] as Map? ?? const {}),
      );
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `flutter test test/model/survey_test.dart`
Expected: PASS(全部,含旧 3 个)

- [ ] **Step 5: Commit**

```bash
cd /Users/xxf/Desktop/scss && git add grid_app/lib/model/survey.dart grid_app/test/model/survey_test.dart
git commit -m "feat(model): Survey.updatedAt(可空,JSON 内,兼容旧行)"
```

---

### Task 2: `SurveyStore.byTemplate` + updatedAt 倒序

**Files:**
- Modify: `grid_app/lib/data/survey_store.dart`
- Modify: `grid_app/lib/data/app_database.dart:122-130`(DriftSurveyStore.all)+ 追加 byTemplate
- Test: `grid_app/test/data/in_memory_survey_store_test.dart`、`grid_app/test/data/drift_survey_store_test.dart`

**Interfaces:**
- Consumes: Task 1 的 `Survey.updatedAt`。
- Produces: `abstract SurveyStore` 新增 `Future<List<Survey>> byTemplate(String templateId)`;`all()` 与 `byTemplate()` 均按 updatedAt 倒序(null 当 epoch 垫底);顶层纯函数 `List<Survey> sortByUpdatedDesc(List<Survey> surveys)`(两实现共用,导出自 `survey_store.dart`)。

- [ ] **Step 1: 写失败测试**(追加到 `test/data/in_memory_survey_store_test.dart` 的 `main()` 内;若该文件没有导入 `Survey`,补 `import 'package:scss_grid/model/survey.dart';`)

```dart
  test('byTemplate filters by templateId, newest first; all() also newest first',
      () async {
    final store = InMemorySurveyStore();
    final t1 = DateTime.parse('2026-07-15T08:00:00');
    final t2 = DateTime.parse('2026-07-15T09:00:00');
    await store.upsert(Survey(
        id: 'old', templateId: 'tplA', name: 'Old', updatedAt: t1));
    await store.upsert(Survey(
        id: 'new', templateId: 'tplA', name: 'New', updatedAt: t2));
    await store.upsert(Survey(
        id: 'other', templateId: 'tplB', name: 'Other', updatedAt: t2));
    await store.upsert(
        const Survey(id: 'legacy', templateId: 'tplA', name: 'Legacy'));

    final a = await store.byTemplate('tplA');
    expect(a.map((s) => s.id).toList(), ['new', 'old', 'legacy']);

    final all = await store.all();
    expect(all.first.id, isNot('legacy')); // null updatedAt 垫底
    expect(all.last.id, 'legacy');
  });
```

同样内容的 Drift 版追加到 `test/data/drift_survey_store_test.dart` 的 `main()` 内(store 换 `DriftSurveyStore(db)`、`AppDatabase(NativeDatabase.memory())` + `addTearDown(db.close)`,断言完全相同):

```dart
  test('drift byTemplate filters by templateId, newest first; all() newest first',
      () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final store = DriftSurveyStore(db);
    final t1 = DateTime.parse('2026-07-15T08:00:00');
    final t2 = DateTime.parse('2026-07-15T09:00:00');
    await store.upsert(Survey(
        id: 'old', templateId: 'tplA', name: 'Old', updatedAt: t1));
    await store.upsert(Survey(
        id: 'new', templateId: 'tplA', name: 'New', updatedAt: t2));
    await store.upsert(Survey(
        id: 'other', templateId: 'tplB', name: 'Other', updatedAt: t2));
    await store.upsert(
        const Survey(id: 'legacy', templateId: 'tplA', name: 'Legacy'));

    final a = await store.byTemplate('tplA');
    expect(a.map((s) => s.id).toList(), ['new', 'old', 'legacy']);

    final all = await store.all();
    expect(all.last.id, 'legacy');
  });
```

- [ ] **Step 2: 跑测试确认失败**

Run: `flutter test test/data/`
Expected: FAIL(`byTemplate` 不存在,编译错)

- [ ] **Step 3: 实现**

`lib/data/survey_store.dart` 全文替换为:

```dart
import '../model/survey.dart';

/// Persistence boundary for surveys. Screens depend on this, not on Drift,
/// so the UI is testable with [InMemorySurveyStore]. Mirrors TemplateStore.
abstract class SurveyStore {
  Future<void> upsert(Survey s);
  Future<Survey?> get(String id);

  /// All surveys, most recently updated first.
  Future<List<Survey>> all();

  /// Surveys of one template, most recently updated first.
  Future<List<Survey>> byTemplate(String templateId);

  Future<void> delete(String id);
}

/// Most-recently-updated first; surveys without a timestamp (legacy rows)
/// sort as epoch, i.e. last. Shared by both store implementations so ordering
/// is defined once.
List<Survey> sortByUpdatedDesc(List<Survey> surveys) {
  final epoch = DateTime.fromMillisecondsSinceEpoch(0);
  return [...surveys]..sort(
      (a, b) => (b.updatedAt ?? epoch).compareTo(a.updatedAt ?? epoch));
}

class InMemorySurveyStore implements SurveyStore {
  final Map<String, Survey> _byId = {};

  @override
  Future<void> upsert(Survey s) async {
    _byId[s.id] = s;
  }

  @override
  Future<Survey?> get(String id) async => _byId[id];

  @override
  Future<List<Survey>> all() async => sortByUpdatedDesc(_byId.values.toList());

  @override
  Future<List<Survey>> byTemplate(String templateId) async => sortByUpdatedDesc(
      _byId.values.where((s) => s.templateId == templateId).toList());

  @override
  Future<void> delete(String id) async {
    _byId.remove(id);
  }
}
```

`lib/data/app_database.dart` 的 `DriftSurveyStore.all()`(122-130 行)替换为下面两个方法(updatedAt 在 JSON 里,SQL 排不了 → 取回后用共享排序;数据量=单机勘测,足够):

```dart
  @override
  Future<List<Survey>> all() async {
    final rows = await _db.select(_db.surveyRows).get();
    return sortByUpdatedDesc(rows
        .map((r) => Survey.fromJson(jsonDecode(r.json) as Map<String, dynamic>))
        .toList());
  }

  @override
  Future<List<Survey>> byTemplate(String templateId) async {
    final rows = await (_db.select(_db.surveyRows)
          ..where((r) => r.templateId.equals(templateId)))
        .get();
    return sortByUpdatedDesc(rows
        .map((r) => Survey.fromJson(jsonDecode(r.json) as Map<String, dynamic>))
        .toList());
  }
```

- [ ] **Step 4: 跑测试确认通过**

Run: `flutter test test/data/ && flutter analyze`
Expected: 全 PASS、0 issues

- [ ] **Step 5: Commit**

```bash
cd /Users/xxf/Desktop/scss && git add grid_app/lib/data/survey_store.dart grid_app/lib/data/app_database.dart grid_app/test/data/in_memory_survey_store_test.dart grid_app/test/data/drift_survey_store_test.dart
git commit -m "feat(data): SurveyStore.byTemplate + all/byTemplate 按 updatedAt 倒序(共享 sortByUpdatedDesc)"
```

---

### Task 3: `time_label.dart` 纯函数(相对时间 + 日期戳)

**Files:**
- Create: `grid_app/lib/fill/time_label.dart`
- Test: `grid_app/test/fill/time_label_test.dart`(新建)

**Interfaces:**
- Produces: `String updatedLabel(DateTime? updatedAt, DateTime now)`(null→`'—'`;<1min→`'just now'`;<1h→`'Nm ago'`;<1d→`'Nh ago'`;<7d→`'Nd ago'`;否则 `'yyyy-MM-dd'`);`String dateStamp(DateTime d)`(`'yyyy-MM-dd'`,手写零填充)。

- [ ] **Step 1: 写失败测试**(新文件 `test/fill/time_label_test.dart` 全文)

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/fill/time_label.dart';

void main() {
  final now = DateTime.parse('2026-07-15T12:00:00');

  test('updatedLabel buckets', () {
    expect(updatedLabel(null, now), '—');
    expect(updatedLabel(now.subtract(const Duration(seconds: 30)), now),
        'just now');
    expect(updatedLabel(now.subtract(const Duration(minutes: 5)), now),
        '5m ago');
    expect(updatedLabel(now.subtract(const Duration(hours: 3)), now), '3h ago');
    expect(updatedLabel(now.subtract(const Duration(days: 2)), now), '2d ago');
    expect(updatedLabel(DateTime.parse('2026-07-01T08:00:00'), now),
        '2026-07-01');
  });

  test('dateStamp zero-pads', () {
    expect(dateStamp(DateTime(2026, 7, 5)), '2026-07-05');
    expect(dateStamp(DateTime(2026, 11, 23)), '2026-11-23');
  });
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `flutter test test/fill/time_label_test.dart`
Expected: FAIL(文件不存在,编译错)

- [ ] **Step 3: 实现**(新文件 `lib/fill/time_label.dart` 全文)

```dart
/// Pure time-formatting helpers for survey lists. No intl dependency.

String _pad2(int v) => v.toString().padLeft(2, '0');

/// 'yyyy-MM-dd', e.g. default survey names ("Site Survey 2026-07-15").
String dateStamp(DateTime d) => '${d.year}-${_pad2(d.month)}-${_pad2(d.day)}';

/// Compact "how long ago" label for a survey's last write. Null (legacy rows
/// saved before updatedAt existed) renders as '—'.
String updatedLabel(DateTime? updatedAt, DateTime now) {
  if (updatedAt == null) return '—';
  final d = now.difference(updatedAt);
  if (d.inMinutes < 1) return 'just now';
  if (d.inHours < 1) return '${d.inMinutes}m ago';
  if (d.inDays < 1) return '${d.inHours}h ago';
  if (d.inDays < 7) return '${d.inDays}d ago';
  return dateStamp(updatedAt);
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `flutter test test/fill/time_label_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
cd /Users/xxf/Desktop/scss && git add grid_app/lib/fill/time_label.dart grid_app/test/fill/time_label_test.dart
git commit -m "feat(fill): time_label 纯函数(updatedLabel/dateStamp)"
```

---

### Task 4: `SurveyNameDialog`(命名/改名共用对话框)

**Files:**
- Create: `grid_app/lib/fill/survey_name_dialog.dart`
- Test: `grid_app/test/fill/survey_name_dialog_test.dart`(新建)

**Interfaces:**
- Produces: `Future<String?> promptForSurveyName(BuildContext context, {required String title, required String initial})` — 确认返回 **trim 后的**非空名,取消/关闭返回 null;空白输入时 OK 置灰。`SurveyNameDialog` 为 StatefulWidget **自持 TextEditingController 并在自身 dispose 销毁**(Phase 3d PinLabelDialog 的教训:controller 不能由 showDialog 调用方管理,路由退场动画中会 crash)。key:输入框 `ValueKey('survey-name-field')`、OK `ValueKey('survey-name-ok')`。

- [ ] **Step 1: 写失败测试**(新文件 `test/fill/survey_name_dialog_test.dart` 全文)

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/fill/survey_name_dialog.dart';

/// Pumps a button that opens the dialog, taps it, and settles — leaving the
/// dialog open. The dialog's eventual result is delivered via [onResult]
/// (called only when the dialog closes), so tests assert on a captured
/// variable after they close the dialog themselves.
Future<void> _pumpOpener(WidgetTester tester, void Function(String?) onResult,
    {String initial = 'Init'}) async {
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (ctx) => TextButton(
        onPressed: () async {
          onResult(await promptForSurveyName(ctx,
              title: 'New survey', initial: initial));
        },
        child: const Text('open'),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('prefills initial and returns trimmed text on OK',
      (tester) async {
    String? result = 'sentinel';
    await _pumpOpener(tester, (r) => result = r, initial: 'Site A');
    expect(find.text('Site A'), findsOneWidget);

    await tester.enterText(
        find.byKey(const ValueKey('survey-name-field')), '  Site B  ');
    await tester.tap(find.byKey(const ValueKey('survey-name-ok')));
    await tester.pumpAndSettle();
    expect(result, 'Site B');
  });

  testWidgets('cancel returns null', (tester) async {
    String? result = 'sentinel';
    await _pumpOpener(tester, (r) => result = r);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });

  testWidgets('blank input disables OK', (tester) async {
    await _pumpOpener(tester, (_) {});
    await tester.enterText(
        find.byKey(const ValueKey('survey-name-field')), '   ');
    await tester.pump();
    final ok = tester.widget<TextButton>(
        find.byKey(const ValueKey('survey-name-ok')));
    expect(ok.onPressed, isNull);
  });
}
```

注意:结果经 `onResult` 回调捕获(对话框关闭时才回调),每个用例自己关对话框后对捕获变量断言——时序确定,不依赖未 await 的 future。第三个用例不关对话框、只检查按钮态(测试结束时 flutter_test 会自动处理未关闭的路由)。

- [ ] **Step 2: 跑测试确认失败**

Run: `flutter test test/fill/survey_name_dialog_test.dart`
Expected: FAIL(文件不存在,编译错)

- [ ] **Step 3: 实现**(新文件 `lib/fill/survey_name_dialog.dart` 全文)

```dart
import 'package:flutter/material.dart';

/// Prompts for a survey name. Returns the trimmed name, or null on cancel.
Future<String?> promptForSurveyName(BuildContext context,
        {required String title, required String initial}) =>
    showDialog<String>(
      context: context,
      builder: (_) => SurveyNameDialog(title: title, initial: initial),
    );

/// Owns its TextEditingController (created in state, disposed in state) so the
/// controller outlives the route's exit animation — see PinLabelDialog for the
/// crash this avoids.
class SurveyNameDialog extends StatefulWidget {
  final String title;
  final String initial;

  const SurveyNameDialog(
      {super.key, required this.title, required this.initial});

  @override
  State<SurveyNameDialog> createState() => _SurveyNameDialogState();
}

class _SurveyNameDialogState extends State<SurveyNameDialog> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        key: const ValueKey('survey-name-field'),
        controller: _ctrl,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Name'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _ctrl,
          builder: (_, value, __) => TextButton(
            key: const ValueKey('survey-name-ok'),
            onPressed: value.text.trim().isEmpty
                ? null
                : () => Navigator.of(context).pop(value.text.trim()),
            child: const Text('OK'),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `flutter test test/fill/survey_name_dialog_test.dart && flutter analyze`
Expected: PASS、0 issues

- [ ] **Step 5: Commit**

```bash
cd /Users/xxf/Desktop/scss && git add grid_app/lib/fill/survey_name_dialog.dart grid_app/test/fill/survey_name_dialog_test.dart
git commit -m "feat(fill): SurveyNameDialog(自持 controller,新建/改名共用)"
```

---

### Task 5: TemplateListScreen — Fill 续填/新建 sheet

**Files:**
- Modify: `grid_app/lib/builder/template_list_screen.dart:67-81`(_fill)
- Test: `grid_app/test/builder/template_list_screen_test.dart`(重写第二个用例 + 新增两个)

**Interfaces:**
- Consumes: `SurveyStore.byTemplate`(Task 2)、`promptForSurveyName`(Task 4)、`dateStamp`/`updatedLabel`(Task 3)。
- Produces: 行为约定 —— 点 Fill:该模板无 survey → 直接命名框;有 → bottom sheet(`ValueKey('fill-new')` 新建项 + 每份 `ValueKey('fill-resume-<id>')`);**新建确认即 `upsert`**(name=输入值,updatedAt=now)再进 FillScreen。

- [ ] **Step 1: 写失败测试**(`test/builder/template_list_screen_test.dart`:删除现有第二个用例 `'Fill action on a template starts a survey in FillScreen'`,替换为以下三个;文件头补 `import 'package:scss_grid/model/survey.dart';`)

```dart
  testWidgets('Fill with no surveys goes straight to the name dialog; '
      'OK persists and opens FillScreen', (tester) async {
    final store = InMemoryTemplateStore();
    await store.upsert(sampleTemplate().copyWith(id: 'a', name: 'Alpha'));
    final surveyStore = InMemorySurveyStore();

    await tester.pumpWidget(MaterialApp(
      home: TemplateListScreen(
          store: store,
          surveyStore: surveyStore,
          registry: buildDefaultRegistry()),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('fill-a')));
    await tester.pumpAndSettle();
    // 无既有 survey → 跳过 sheet,直接命名框(预填 'Alpha yyyy-MM-dd')
    expect(find.byKey(const ValueKey('survey-name-field')), findsOneWidget);

    await tester.enterText(
        find.byKey(const ValueKey('survey-name-field')), 'Site One');
    await tester.tap(find.byKey(const ValueKey('survey-name-ok')));
    await tester.pumpAndSettle();

    expect(find.byType(FillScreen), findsOneWidget);
    final saved = await surveyStore.all(); // 新建即落库
    expect(saved.length, 1);
    expect(saved.single.name, 'Site One');
    expect(saved.single.templateId, 'a');
    expect(saved.single.updatedAt, isNotNull);
  });

  testWidgets('Fill with existing surveys shows a sheet; tapping one resumes it',
      (tester) async {
    final store = InMemoryTemplateStore();
    await store.upsert(sampleTemplate().copyWith(id: 'a', name: 'Alpha'));
    final surveyStore = InMemorySurveyStore();
    await surveyStore.upsert(Survey(
        id: 's1',
        templateId: 'a',
        name: 'Site One',
        updatedAt: DateTime.parse('2026-07-15T08:00:00')));

    await tester.pumpWidget(MaterialApp(
      home: TemplateListScreen(
          store: store,
          surveyStore: surveyStore,
          registry: buildDefaultRegistry()),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('fill-a')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('fill-new')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('fill-resume-s1')));
    await tester.pumpAndSettle();
    expect(find.byType(FillScreen), findsOneWidget);
    expect(find.text('Site One'), findsOneWidget); // FillScreen 标题=survey 名
    expect((await surveyStore.all()).length, 1); // 续填不新建
  });

  testWidgets('sheet New survey item opens the name dialog', (tester) async {
    final store = InMemoryTemplateStore();
    await store.upsert(sampleTemplate().copyWith(id: 'a', name: 'Alpha'));
    final surveyStore = InMemorySurveyStore();
    await surveyStore.upsert(Survey(
        id: 's1',
        templateId: 'a',
        name: 'Site One',
        updatedAt: DateTime.parse('2026-07-15T08:00:00')));

    await tester.pumpWidget(MaterialApp(
      home: TemplateListScreen(
          store: store,
          surveyStore: surveyStore,
          registry: buildDefaultRegistry()),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('fill-a')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('fill-new')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('survey-name-field')), findsOneWidget);
  });
```

- [ ] **Step 2: 跑测试确认失败**

Run: `flutter test test/builder/template_list_screen_test.dart`
Expected: FAIL(现行 _fill 直接进 FillScreen,找不到 `survey-name-field`/`fill-new`)

- [ ] **Step 3: 实现**(`lib/builder/template_list_screen.dart`)

文件头部追加导入:

```dart
import '../fill/survey_name_dialog.dart';
import '../fill/time_label.dart';
```

用下面三个方法**替换**现有 `_fill`(67-81 行):

```dart
  /// Fill = resume-or-create: no surveys yet → straight to the name dialog;
  /// otherwise a sheet lists this template's surveys (newest first) plus a
  /// "New survey" item.
  Future<void> _fill(Template t) async {
    final existing = await widget.surveyStore.byTemplate(t.id);
    if (!mounted) return;
    if (existing.isEmpty) {
      await _newSurvey(t);
      return;
    }

    Survey? resume;
    var createNew = false;
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              key: const ValueKey('fill-new'),
              leading: const Icon(Icons.add),
              title: const Text('New survey'),
              onTap: () {
                createNew = true;
                Navigator.of(sheetCtx).pop();
              },
            ),
            const Divider(height: 1),
            for (final s in existing)
              ListTile(
                key: ValueKey('fill-resume-${s.id}'),
                title: Text(s.name),
                subtitle: Text(
                    '${updatedLabel(s.updatedAt, DateTime.now())} · ${s.data.length} fields'),
                onTap: () {
                  resume = s;
                  Navigator.of(sheetCtx).pop();
                },
              ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (createNew) {
      await _newSurvey(t);
    } else if (resume != null) {
      await _openFill(t, resume!);
    }
  }

  /// Name dialog → persist immediately (a named empty survey is a legitimate
  /// in-progress state; the dialog is the guard against accidental orphans).
  Future<void> _newSurvey(Template t) async {
    final name = await promptForSurveyName(context,
        title: 'New survey', initial: '${t.name} ${dateStamp(DateTime.now())}');
    if (name == null || !mounted) return;
    final survey = Survey(
      id: 'srv_${DateTime.now().millisecondsSinceEpoch}',
      templateId: t.id,
      name: name,
      updatedAt: DateTime.now(),
    );
    await widget.surveyStore.upsert(survey);
    if (!mounted) return;
    await _openFill(t, survey);
  }

  Future<void> _openFill(Template t, Survey survey) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => FillScreen(
        template: t,
        survey: survey,
        store: widget.surveyStore,
        registry: widget.registry,
      ),
    ));
  }
```

- [ ] **Step 4: 跑测试确认通过**

Run: `flutter test test/builder/template_list_screen_test.dart && flutter analyze`
Expected: PASS(注意第一个旧用例 FAB 创建模板仍须绿)、0 issues

- [ ] **Step 5: Commit**

```bash
cd /Users/xxf/Desktop/scss && git add grid_app/lib/builder/template_list_screen.dart grid_app/test/builder/template_list_screen_test.dart
git commit -m "feat(builder): Fill 变续填/新建入口(sheet+命名框,新建即落库)"
```

---

### Task 6: FillScreen autosave(防抖 + 退出 flush,去 Save)

**Files:**
- Modify: `grid_app/lib/fill/fill_screen.dart`
- Test: `grid_app/test/fill/fill_screen_test.dart`(重写第一个用例 + 新增)

**Interfaces:**
- Consumes: Task 1 `Survey.copyWith(updatedAt:)`。
- Produces: 行为约定 —— 值变更后 500ms 防抖 `upsert`(连续输入合并为一次);pop/dispose 时未落盘改动立即 flush;AppBar 无 Save 按钮(Export 保留)。

- [ ] **Step 1: 写失败测试**(`test/fill/fill_screen_test.dart`:删除第一个用例 `'renders the fill canvas and Save persists entered values'`,替换为以下;第二个用例(InteractiveViewer)保留不动;文件头补 `import 'package:scss_grid/model/template.dart';` 已有则不动)

```dart
class _CountingStore extends InMemorySurveyStore {
  int upserts = 0;
  @override
  Future<void> upsert(Survey s) {
    upserts++;
    return super.upsert(s);
  }
}
```

(放在 `main()` 之前、`_tpl()` 之后。)`main()` 内新增:

```dart
  testWidgets('autosaves after a 500ms debounce; rapid edits merge into one write',
      (tester) async {
    final store = _CountingStore();
    const survey = Survey(id: 's1', templateId: 't1', name: 'Site Survey');
    await tester.pumpWidget(MaterialApp(
      home: FillScreen(
        template: _tpl(),
        survey: survey,
        store: store,
        registry: buildDefaultRegistry(),
      ),
    ));
    expect(find.byType(FillCanvas), findsOneWidget);
    expect(find.byTooltip('Save'), findsNothing); // Save 按钮已移除

    await tester.enterText(find.byType(TextFormField), 'Gj');
    await tester.pump(const Duration(milliseconds: 200)); // 防抖窗口内
    await tester.enterText(find.byType(TextFormField), 'Gjirokaster');
    expect(store.upserts, 0); // 还没到 500ms,一次都没写

    await tester.pump(const Duration(milliseconds: 600));
    expect(store.upserts, 1); // 两次输入合并为一次写

    final saved = await store.get('s1');
    expect(saved!.data['site_name'], 'Gjirokaster');
    expect(saved.updatedAt, isNotNull);
  });

  testWidgets('pending edit is flushed when the screen is disposed',
      (tester) async {
    final store = _CountingStore();
    const survey = Survey(id: 's1', templateId: 't1', name: 'Site Survey');
    await tester.pumpWidget(MaterialApp(
      home: FillScreen(
        template: _tpl(),
        survey: survey,
        store: store,
        registry: buildDefaultRegistry(),
      ),
    ));
    await tester.enterText(find.byType(TextFormField), 'Berat');
    // 防抖未到期就销毁页面(等价于用户立刻按返回)
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pumpAndSettle();

    expect(store.upserts, 1);
    expect((await store.get('s1'))!.data['site_name'], 'Berat');
  });
```

- [ ] **Step 2: 跑测试确认失败**

Run: `flutter test test/fill/fill_screen_test.dart`
Expected: FAIL(现行仍有 Save 按钮、无 autosave;`findsNothing` 断言失败)

- [ ] **Step 3: 实现**(`lib/fill/fill_screen.dart`)

头部加 `import 'dart:async';`。`_FillScreenState` 内:

① 加字段(紧跟 `_data` 之后):

```dart
  // Autosave: debounce writes so per-keystroke onChanged doesn't hammer the
  // store; flush pending edits on dispose so backing out never loses input.
  Timer? _saveTimer;
  bool _dirty = false;
  static const _autosaveDelay = Duration(milliseconds: 500);
```

② 删除 `_save` 方法,新增:

```dart
  void _onChanged(String key, dynamic value) {
    setState(() => _data[key] = value);
    _dirty = true;
    _saveTimer?.cancel();
    _saveTimer = Timer(_autosaveDelay, _flush);
  }

  void _flush() {
    _saveTimer?.cancel();
    _saveTimer = null;
    if (!_dirty) return;
    _dirty = false;
    widget.store.upsert(widget.survey
        .copyWith(data: {..._data}, updatedAt: DateTime.now()));
  }
```

③ `dispose()` 改为(flush 在 controller 销毁前):

```dart
  @override
  void dispose() {
    _flush();
    _tc.dispose();
    super.dispose();
  }
```

④ `_current` getter:`_flush` 已内联构造,删除 `Survey get _current ...`(若 `_export` 等无他处引用;`_export` 用的是 `_data`,不受影响)。

⑤ AppBar `actions` 里删除 Save 的 `IconButton`(保留 Export);`FillCanvas` 的 `onChanged: (key, value) => setState(...)` 改为 `onChanged: _onChanged`。

- [ ] **Step 4: 跑测试确认通过**

Run: `flutter test test/fill/ && flutter analyze`
Expected: 全 PASS、0 issues

- [ ] **Step 5: Commit**

```bash
cd /Users/xxf/Desktop/scss && git add grid_app/lib/fill/fill_screen.dart grid_app/test/fill/fill_screen_test.dart
git commit -m "feat(fill): autosave(500ms 防抖+dispose flush),移除 Save 按钮"
```

---

### Task 7: SurveyListScreen — 排序展示 + 改名

**Files:**
- Modify: `grid_app/lib/fill/survey_list_screen.dart`
- Test: `grid_app/test/fill/survey_list_screen_test.dart`(新增用例;现有两个保留)

**Interfaces:**
- Consumes: `updatedLabel`(Task 3)、`promptForSurveyName`(Task 4)、store 排序(Task 2)。
- Produces: 列表最近更新在前(store 已排,UI 不再排);subtitle=`'<模板名> · <相对时间> · N fields'`(模板已删则显示 templateId);行尾 `ValueKey('rename-<id>')` 改名按钮 → 对话框 → upsert(name, updatedAt=now)+ 刷新。

- [ ] **Step 1: 写失败测试**(追加到 `test/fill/survey_list_screen_test.dart` 的 `main()` 内)

```dart
  testWidgets('newest first; subtitle shows template name and relative time',
      (tester) async {
    final templateStore = InMemoryTemplateStore();
    await templateStore.upsert(sampleTemplate()); // id 'sample'
    final surveyStore = InMemorySurveyStore();
    await surveyStore.upsert(Survey(
        id: 'old', templateId: 'sample', name: 'Old site',
        updatedAt: DateTime.now().subtract(const Duration(days: 2))));
    await surveyStore.upsert(Survey(
        id: 'new', templateId: 'sample', name: 'New site',
        updatedAt: DateTime.now()));

    await tester.pumpWidget(MaterialApp(
      home: SurveyListScreen(
        surveyStore: surveyStore,
        templateStore: templateStore,
        registry: buildDefaultRegistry(),
      ),
    ));
    await tester.pumpAndSettle();

    final newY = tester.getTopLeft(find.text('New site')).dy;
    final oldY = tester.getTopLeft(find.text('Old site')).dy;
    expect(newY, lessThan(oldY)); // 最近更新在前

    // subtitle 含模板名(sampleTemplate 的 name)与相对时间
    expect(find.textContaining(sampleTemplate().name), findsNWidgets(2));
    expect(find.textContaining('2d ago'), findsOneWidget);
  });

  testWidgets('rename button opens dialog; OK persists new name',
      (tester) async {
    final surveyStore = InMemorySurveyStore();
    await surveyStore.upsert(Survey(
        id: 's1', templateId: 'sample', name: 'Old name',
        updatedAt: DateTime.now()));

    await tester.pumpWidget(MaterialApp(
      home: SurveyListScreen(
        surveyStore: surveyStore,
        templateStore: InMemoryTemplateStore(),
        registry: buildDefaultRegistry(),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('rename-s1')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('survey-name-field')), 'New name');
    await tester.tap(find.byKey(const ValueKey('survey-name-ok')));
    await tester.pumpAndSettle();

    expect(find.text('New name'), findsOneWidget);
    expect((await surveyStore.get('s1'))!.name, 'New name');
  });
```

- [ ] **Step 2: 跑测试确认失败**

Run: `flutter test test/fill/survey_list_screen_test.dart`
Expected: FAIL(无 rename 按钮、subtitle 还是 'N fields filled')

- [ ] **Step 3: 实现**(`lib/fill/survey_list_screen.dart`)

头部追加导入:

```dart
import '../model/template.dart';
import 'survey_name_dialog.dart';
import 'time_label.dart';
```

`_SurveyListScreenState`:

① 加字段 `Map<String, String> _tplNames = {};`,`_reload` 改为同时装载模板名:

```dart
  Future<void> _reload() async {
    final list = await widget.surveyStore.all();
    final templates = await widget.templateStore.all();
    if (!mounted) return;
    setState(() {
      _surveys = list;
      _tplNames = {for (final Template t in templates) t.id: t.name};
      _loading = false;
    });
  }
```

② 新增 `_rename`:

```dart
  Future<void> _rename(Survey s) async {
    final name = await promptForSurveyName(context,
        title: 'Rename survey', initial: s.name);
    if (name == null || !mounted) return;
    await widget.surveyStore
        .upsert(s.copyWith(name: name, updatedAt: DateTime.now()));
    if (!mounted) return;
    await _reload();
  }
```

③ `ListTile` 改为:

```dart
                        child: ListTile(
                          title: Text(s.name),
                          subtitle: Text(
                              '${_tplNames[s.templateId] ?? s.templateId} · '
                              '${updatedLabel(s.updatedAt, DateTime.now())} · '
                              '${s.data.length} fields'),
                          trailing: IconButton(
                            key: ValueKey('rename-${s.id}'),
                            icon: const Icon(Icons.edit_outlined),
                            tooltip: 'Rename',
                            onPressed: () => _rename(s),
                          ),
                          onTap: () => _resume(s),
                        ),
```

- [ ] **Step 4: 跑测试确认通过**

Run: `flutter test test/fill/survey_list_screen_test.dart && flutter analyze`
Expected: 全 PASS(现有两个用例也绿:第一个 tap 'Castle survey' 恢复不受 trailing 影响)、0 issues

- [ ] **Step 5: Commit**

```bash
cd /Users/xxf/Desktop/scss && git add grid_app/lib/fill/survey_list_screen.dart grid_app/test/fill/survey_list_screen_test.dart
git commit -m "feat(fill): Surveys 列表最近在前+模板名/相对时间 subtitle+改名"
```

---

### Task 8: 全量回归 + 文档

**Files:**
- Modify: `doc/PROGRESS.md`(现状行 + 下一步)

- [ ] **Step 1: 全量回归**

Run: `cd /Users/xxf/Desktop/scss/grid_app && flutter analyze && flutter test`
Expected: 0 issues;全绿(197 基线 + 本期新增 ≈10+)。若 `test/integration/` 或 `test/app_boot_test.dart` 有因 Fill 流程变化挂掉的用例,按 Task 5 的行为约定修断言(无 survey → 先命名框)。

- [ ] **Step 2: 更新 `doc/PROGRESS.md`**

『下一步(2026-07-15 调整后)』一节:待办池里删掉『#1『保存/恢复』体验…』一项,并在该节顶部加一行:

```
0. ✅ **#1 保存/恢复体验已完成**(spec `2026-07-15-save-restore-ux-design.md`):Fill=续填/新建 sheet、survey 命名/改名/updatedAt、FillScreen autosave(500ms 防抖+退出 flush,Save 按钮移除)。
```

- [ ] **Step 3: Commit**

```bash
cd /Users/xxf/Desktop/scss && git add doc/PROGRESS.md
git commit -m "docs(progress): #1 保存/恢复体验完成"
```

- [ ] **Step 4: 真机验收(用户,human checkpoint)**

构建装机(注意 pubspec 已是 `1.0.0+2`,与真机同号可覆盖):

```bash
cd /Users/xxf/Desktop/scss/grid_app && flutter build apk --release --split-per-abi
/Users/xxf/Library/Android/sdk/platform-tools/adb -s RZCRA03MZVX install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

验收点:① Fill 无 survey → 命名框(预填模板名+日期)→ 进填写;② 填几个值**不按任何按钮**直接退出 → 再点 Fill → sheet 里能看到该份、点开值都在;③ sheet 新建第二份、两份可区分;④ Surveys 列表最近在前、能改名;⑤ Export PDF 正常。

- [ ] **Step 5: 合并**

验收通过后用 superpowers:finishing-a-development-branch 合并 `save-restore-ux` → main、删分支、`git push`。
