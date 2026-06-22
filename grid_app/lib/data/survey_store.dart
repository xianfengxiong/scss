import '../model/survey.dart';

/// Persistence boundary for surveys. Screens depend on this, not on Drift,
/// so the UI is testable with [InMemorySurveyStore]. Mirrors TemplateStore.
abstract class SurveyStore {
  Future<void> upsert(Survey s);
  Future<Survey?> get(String id);
  Future<List<Survey>> all();
  Future<void> delete(String id);
}

class InMemorySurveyStore implements SurveyStore {
  final Map<String, Survey> _byId = {};

  @override
  Future<void> upsert(Survey s) async {
    _byId[s.id] = s;
  }

  @override
  Future<Survey?> get(String id) async => _byId[id];

  @override
  Future<List<Survey>> all() async => _byId.values.toList(growable: false);

  @override
  Future<void> delete(String id) async {
    _byId.remove(id);
  }
}
