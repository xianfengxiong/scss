import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/data/app_database.dart';
import 'package:scss_grid/sample/sample_template.dart';

void main() {
  test('drift store round-trips a template through SQLite (in-memory)', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final store = DriftTemplateStore(db);

    final t = sampleTemplate();
    await store.upsert(t);

    final loaded = await store.get(t.id);
    expect(loaded, isNotNull);
    expect(loaded!.name, t.name);
    expect(loaded.cells.length, t.cells.length);
    expect(loaded.grid.cols, t.grid.cols);

    expect((await store.all()).length, 1);
    await store.delete(t.id);
    expect(await store.get(t.id), isNull);

    await db.close();
  });
}
