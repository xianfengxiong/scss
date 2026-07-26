import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/data/app_database.dart';
import 'package:scss_grid/sample/sample_template.dart';

void main() {
  test('drift store round-trips a template through SQLite (in-memory)', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final store = DriftTemplateStore(db);

    final t = sampleTemplate();
    await store.upsert(t);

    final loaded = await store.get(t.id);
    expect(loaded, isNotNull);
    expect(loaded!.name, t.name);
    expect(loaded.allCells.length, t.allCells.length);
    expect(loaded.pages[0].grid.cols, t.pages[0].grid.cols);

    expect((await store.all()).length, 1);
    await store.delete(t.id);
    expect(await store.get(t.id), isNull);
  });
}
