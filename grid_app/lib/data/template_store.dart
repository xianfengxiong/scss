import '../model/template.dart';

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

  @override
  Future<void> upsert(Template t) async {
    _byId[t.id] = t;
  }

  @override
  Future<Template?> get(String id) async => _byId[id];

  @override
  Future<List<Template>> all() async => _byId.values.toList(growable: false);

  @override
  Future<void> delete(String id) async {
    _byId.remove(id);
  }
}
