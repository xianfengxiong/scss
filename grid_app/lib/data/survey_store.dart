import '../model/survey.dart';
import '../model/tombstone.dart';
import 'sync_meta_store.dart';

/// Persistence boundary for surveys. Screens depend on this, not on Drift,
/// so the UI is testable with [InMemorySurveyStore]. Mirrors TemplateStore.
abstract class SurveyStore {
  Future<void> upsert(Survey s);
  Future<Survey?> get(String id);

  /// All surveys, most recently updated first.
  Future<List<Survey>> all();

  /// Surveys of one template, most recently updated first.
  Future<List<Survey>> byTemplate(String templateId);

  Future<void> delete(String id);
}

/// Most-recently-updated first; surveys without a timestamp (legacy rows)
/// sort as epoch, i.e. last. Shared by both store implementations so ordering
/// is defined once.
List<Survey> sortByUpdatedDesc(List<Survey> surveys) {
  final epoch = DateTime.fromMillisecondsSinceEpoch(0);
  return [...surveys]..sort(
      (a, b) => (b.updatedAt ?? epoch).compareTo(a.updatedAt ?? epoch));
}

class InMemorySurveyStore implements SurveyStore {
  final Map<String, Survey> _byId = {};

  /// When given, delete/upsert keep tombstones in step, mirroring the Drift
  /// store, so sync-engine tests see production semantics.
  final InMemorySyncMetaStore? meta;

  InMemorySurveyStore({this.meta});

  @override
  Future<void> upsert(Survey s) async {
    _byId[s.id] = s;
    await meta?.removeTombstone(Tombstone.kindSurvey, s.id);
  }

  @override
  Future<Survey?> get(String id) async => _byId[id];

  @override
  Future<List<Survey>> all() async => sortByUpdatedDesc(_byId.values.toList());

  @override
  Future<List<Survey>> byTemplate(String templateId) async => sortByUpdatedDesc(
      _byId.values.where((s) => s.templateId == templateId).toList());

  @override
  Future<void> delete(String id) async {
    _byId.remove(id);
    await meta?.addTombstone(Tombstone(
        kind: Tombstone.kindSurvey, id: id, deletedAt: DateTime.now()));
  }
}
