import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/data/app_database.dart';
import 'package:scss_grid/data/survey_store.dart';
import 'package:scss_grid/data/sync_meta_store.dart';
import 'package:scss_grid/data/template_store.dart';
import 'package:scss_grid/model/survey.dart';
import 'package:scss_grid/model/tombstone.dart';
import 'package:scss_grid/sample/sample_template.dart';

void main() {
  group('DriftSyncMetaStore', () {
    late AppDatabase db;
    late DriftSyncMetaStore meta;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      meta = DriftSyncMetaStore(db);
    });

    tearDown(() => db.close());

    test('kv set/get round-trips and overwrites', () async {
      expect(await meta.kvGet('deviceId'), isNull);
      await meta.kvSet('deviceId', 'abc');
      expect(await meta.kvGet('deviceId'), 'abc');
      await meta.kvSet('deviceId', 'def');
      expect(await meta.kvGet('deviceId'), 'def');
    });

    test('tombstones add/list/remove, keyed by (kind, id)', () async {
      final at = DateTime(2026, 7, 26);
      await meta.addTombstone(
          Tombstone(kind: Tombstone.kindTemplate, id: 'x', deletedAt: at));
      await meta.addTombstone(
          Tombstone(kind: Tombstone.kindSurvey, id: 'x', deletedAt: at));
      expect((await meta.tombstones()).length, 2);
      await meta.removeTombstone(Tombstone.kindTemplate, 'x');
      final left = await meta.tombstones();
      expect(left.single.kind, Tombstone.kindSurvey);
      expect(left.single.deletedAt, at);
    });

    test('template delete leaves a tombstone; re-upsert clears it', () async {
      final store = DriftTemplateStore(db);
      final t = sampleTemplate().copyWith(id: 'tpl_1');
      await store.upsert(t);
      await store.delete('tpl_1');
      expect((await meta.tombstones()).single.id, 'tpl_1');

      await store.upsert(t); // synced back / re-created → alive again
      expect(await meta.tombstones(), isEmpty);
    });

    test('survey delete leaves a tombstone; re-upsert clears it', () async {
      final store = DriftSurveyStore(db);
      const s = Survey(id: 'srv_1', templateId: 'tpl_1', name: 'S');
      await store.upsert(s);
      await store.delete('srv_1');
      final tomb = (await meta.tombstones()).single;
      expect(tomb.kind, Tombstone.kindSurvey);
      expect(tomb.id, 'srv_1');

      await store.upsert(s);
      expect(await meta.tombstones(), isEmpty);
    });
  });

  group('InMemory stores mirror tombstone semantics', () {
    test('delete adds, upsert clears', () async {
      final meta = InMemorySyncMetaStore();
      final templates = InMemoryTemplateStore(meta: meta);
      final surveys = InMemorySurveyStore(meta: meta);

      await templates.upsert(sampleTemplate().copyWith(id: 'tpl_1'));
      await surveys
          .upsert(const Survey(id: 'srv_1', templateId: 'tpl_1', name: 'S'));
      await templates.delete('tpl_1');
      await surveys.delete('srv_1');
      expect((await meta.tombstones()).length, 2);

      await templates.upsert(sampleTemplate().copyWith(id: 'tpl_1'));
      await surveys
          .upsert(const Survey(id: 'srv_1', templateId: 'tpl_1', name: 'S'));
      expect(await meta.tombstones(), isEmpty);
    });

    test('kv round-trips', () async {
      final meta = InMemorySyncMetaStore();
      await meta.kvSet('k', 'v');
      expect(await meta.kvGet('k'), 'v');
      expect(await meta.kvGet('missing'), isNull);
    });
  });
}
