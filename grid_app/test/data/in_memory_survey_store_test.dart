import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/data/survey_store.dart';
import 'package:scss_grid/model/survey.dart';

void main() {
  test('in-memory survey store round-trips, lists, upserts, and deletes',
      () async {
    final store = InMemorySurveyStore();
    expect(await store.all(), isEmpty);

    const s = Survey(id: 's1', templateId: 't1', name: 'A', data: {'k': 1});
    await store.upsert(s);
    expect((await store.get('s1'))!.name, 'A');
    expect((await store.all()).length, 1);

    await store.upsert(s.copyWith(name: 'B'));
    expect((await store.get('s1'))!.name, 'B'); // upsert overwrites
    expect((await store.all()).length, 1);

    await store.delete('s1');
    expect(await store.get('s1'), isNull);
    expect(await store.all(), isEmpty);
  });

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
}
