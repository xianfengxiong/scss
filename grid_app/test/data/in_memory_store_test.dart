import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/data/template_store.dart';
import 'package:scss_grid/sample/sample_template.dart';

void main() {
  test('in-memory store round-trips, lists, and deletes', () async {
    final store = InMemoryTemplateStore();
    expect(await store.all(), isEmpty);

    final t = sampleTemplate();
    await store.upsert(t);
    expect((await store.get(t.id))!.name, t.name);
    expect((await store.all()).length, 1);

    await store.upsert(t.copyWith(name: 'Renamed'));
    expect((await store.get(t.id))!.name, 'Renamed'); // upsert overwrites
    expect((await store.all()).length, 1);

    await store.delete(t.id);
    expect(await store.get(t.id), isNull);
    expect(await store.all(), isEmpty);
  });
}
