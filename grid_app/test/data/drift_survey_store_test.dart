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
}
