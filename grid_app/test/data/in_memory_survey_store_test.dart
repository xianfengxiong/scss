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
}
