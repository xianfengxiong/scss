import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/data/app_database.dart';
import 'package:scss_grid/model/survey.dart';

void main() {
  test('drift survey store round-trips a survey through SQLite (in-memory)',
      () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final store = DriftSurveyStore(db);

    const s = Survey(
      id: 's1',
      templateId: 't1',
      name: 'Castle survey',
      data: {'site_name': 'Gjirokaster', 'count': 3},
    );
    await store.upsert(s);

    final loaded = await store.get('s1');
    expect(loaded, isNotNull);
    expect(loaded!.name, 'Castle survey');
    expect(loaded.templateId, 't1');
    expect(loaded.data, {'site_name': 'Gjirokaster', 'count': 3});

    expect((await store.all()).length, 1);
    await store.delete('s1');
    expect(await store.get('s1'), isNull);
  });

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
}
