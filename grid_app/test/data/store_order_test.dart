import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/data/app_database.dart';
import 'package:scss_grid/sample/sample_template.dart';

void main() {
  test('all() returns templates ordered by name', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final store = DriftTemplateStore(db);
    await store.upsert(sampleTemplate().copyWith(id: 'b', name: 'Beta'));
    await store.upsert(sampleTemplate().copyWith(id: 'a', name: 'Alpha'));
    final names = (await store.all()).map((t) => t.name).toList();
    expect(names, ['Alpha', 'Beta']);
    await db.close();
  });
}
