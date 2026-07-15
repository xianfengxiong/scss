import 'dart:convert';

import 'package:drift/drift.dart';

import '../model/survey.dart';
import '../model/template.dart';
import 'connection.dart';
import 'survey_store.dart';
import 'template_store.dart';

part 'app_database.g.dart';

/// One row per saved template: the template serialized to JSON text.
class TemplateRows extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get json => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// One row per saved survey: the survey serialized to JSON text. `templateId`
/// and `name` are kept as columns for listing/ordering without parsing JSON.
class SurveyRows extends Table {
  TextColumn get id => text()();
  TextColumn get templateId => text()();
  TextColumn get name => text()();
  TextColumn get json => text()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [TemplateRows, SurveyRows])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// Production constructor: opens the on-device SQLite file.
  AppDatabase.open() : super(openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        // v1 installs (Phase 1B dev DBs) only had `template_rows`; v2 adds
        // `survey_rows`. greenfield = no data backfill, just create the table.
        onUpgrade: (m, from, to) async {
          if (from < 2) await m.createTable(surveyRows);
        },
      );
}

/// Drift-backed [TemplateStore]: (de)serializes [Template] to/from the `json`
/// column. The rest of the app never sees Drift types.
class DriftTemplateStore implements TemplateStore {
  final AppDatabase _db;
  DriftTemplateStore(this._db);

  @override
  Future<void> upsert(Template t) =>
      _db.into(_db.templateRows).insertOnConflictUpdate(
            TemplateRowsCompanion.insert(
              id: t.id,
              name: t.name,
              json: jsonEncode(t.toJson()),
            ),
          );

  @override
  Future<Template?> get(String id) async {
    final row = await (_db.select(_db.templateRows)
          ..where((r) => r.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return null;
    return Template.fromJson(jsonDecode(row.json) as Map<String, dynamic>);
  }

  @override
  Future<List<Template>> all() async {
    final query = _db.select(_db.templateRows)
      ..orderBy([(r) => OrderingTerm(expression: r.name)]);
    final rows = await query.get();
    return rows
        .map((r) => Template.fromJson(jsonDecode(r.json) as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> delete(String id) =>
      (_db.delete(_db.templateRows)..where((r) => r.id.equals(id))).go();
}

/// Drift-backed [SurveyStore]: (de)serializes [Survey] to/from the `json`
/// column. The rest of the app never sees Drift types.
class DriftSurveyStore implements SurveyStore {
  final AppDatabase _db;
  DriftSurveyStore(this._db);

  @override
  Future<void> upsert(Survey s) =>
      _db.into(_db.surveyRows).insertOnConflictUpdate(
            SurveyRowsCompanion.insert(
              id: s.id,
              templateId: s.templateId,
              name: s.name,
              json: jsonEncode(s.toJson()),
            ),
          );

  @override
  Future<Survey?> get(String id) async {
    final row = await (_db.select(_db.surveyRows)
          ..where((r) => r.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return null;
    return Survey.fromJson(jsonDecode(row.json) as Map<String, dynamic>);
  }

  @override
  Future<List<Survey>> all() async {
    final rows = await _db.select(_db.surveyRows).get();
    return sortByUpdatedDesc(rows
        .map((r) => Survey.fromJson(jsonDecode(r.json) as Map<String, dynamic>))
        .toList());
  }

  @override
  Future<List<Survey>> byTemplate(String templateId) async {
    final rows = await (_db.select(_db.surveyRows)
          ..where((r) => r.templateId.equals(templateId)))
        .get();
    return sortByUpdatedDesc(rows
        .map((r) => Survey.fromJson(jsonDecode(r.json) as Map<String, dynamic>))
        .toList());
  }

  @override
  Future<void> delete(String id) =>
      (_db.delete(_db.surveyRows)..where((r) => r.id.equals(id))).go();
}
