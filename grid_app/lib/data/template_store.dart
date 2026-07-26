import '../model/template.dart';
import '../model/tombstone.dart';
import 'sync_meta_store.dart';

/// Persistence boundary for templates. Screens depend on this, not on Drift,
/// so the UI is testable with [InMemoryTemplateStore].
abstract class TemplateStore {
  Future<void> upsert(Template t);
  Future<Template?> get(String id);
  Future<List<Template>> all();
  Future<void> delete(String id);
}

class InMemoryTemplateStore implements TemplateStore {
  final Map<String, Template> _byId = {};

  /// When given, delete/upsert keep tombstones in step, mirroring the Drift
  /// store, so sync-engine tests see production semantics.
  final InMemorySyncMetaStore? meta;

  InMemoryTemplateStore({this.meta});

  @override
  Future<void> upsert(Template t) async {
    _byId[t.id] = t;
    await meta?.removeTombstone(Tombstone.kindTemplate, t.id);
  }

  @override
  Future<Template?> get(String id) async => _byId[id];

  @override
  Future<List<Template>> all() async => _byId.values.toList(growable: false);

  @override
  Future<void> delete(String id) async {
    _byId.remove(id);
    await meta?.addTombstone(Tombstone(
        kind: Tombstone.kindTemplate, id: id, deletedAt: DateTime.now()));
  }
}
