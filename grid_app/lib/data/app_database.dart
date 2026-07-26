import 'dart:convert';

import 'package:drift/drift.dart';

import '../model/survey.dart';
import '../model/template.dart';
import '../model/tombstone.dart';
import 'connection.dart';
import 'survey_store.dart';
import 'sync_meta_store.dart';
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

/// One row per deleted template/survey, so sync propagates deletes instead of
/// the other device resurrecting the row. `deletedAt` is ISO8601.
class TombstoneRows extends Table {
  TextColumn get kind => text()();
  TextColumn get id => text()();
  TextColumn get deletedAt => text()();

  @override
  Set<Column> get primaryKey => {kind, id};
}

/// Small key/value bag for sync bookkeeping (device id, pairing, token).
class KvRows extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [TemplateRows, SurveyRows, TombstoneRows, KvRows])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// Production constructor: opens the on-device SQLite file.
  AppDatabase.open() : super(openConnection());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        // v1 installs (Phase 1B dev DBs) only had `template_rows`; v2 adds
        // `survey_rows`; v3 adds sync bookkeeping (tombstones + kv). No data
        // backfill needed at any step.
        onUpgrade: (m, from, to) async {
          if (from < 2) await m.createTable(surveyRows);
          if (from < 3) {
            await m.createTable(tombstoneRows);
            await m.createTable(kvRows);
          }
        },
      );
}

/// Drift-backed [TemplateStore]: (de)serializes [Template] to/from the `json`
/// column. The rest of the app never sees Drift types.
class DriftTemplateStore implements TemplateStore {
  final AppDatabase _db;
  DriftTemplateStore(this._db);

  // Upsert clears any tombstone for the same id (a re-created/synced row is
  // alive again); delete leaves one so sync propagates the removal.
  @override
  Future<void> upsert(Template t) => _db.transaction(() async {
        await _db.into(_db.templateRows).insertOnConflictUpdate(
              TemplateRowsCompanion.insert(
                id: t.id,
                name: t.name,
                json: jsonEncode(t.toJson()),
              ),
            );
        await (_db.delete(_db.tombstoneRows)
              ..where((r) =>
                  r.kind.equals(Tombstone.kindTemplate) & r.id.equals(t.id)))
            .go();
      });

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
  Future<void> delete(String id) => _db.transaction(() async {
        await (_db.delete(_db.templateRows)..where((r) => r.id.equals(id)))
            .go();
        await _db.into(_db.tombstoneRows).insertOnConflictUpdate(
              TombstoneRowsCompanion.insert(
                kind: Tombstone.kindTemplate,
                id: id,
                deletedAt: DateTime.now().toUtc().toIso8601String(),
              ),
            );
      });
}

/// Drift-backed [SurveyStore]: (de)serializes [Survey] to/from the `json`
/// column. The rest of the app never sees Drift types.
class DriftSurveyStore implements SurveyStore {
  final AppDatabase _db;
  DriftSurveyStore(this._db);

  // Upsert clears any tombstone for the same id; delete leaves one. Mirrors
  // DriftTemplateStore.
  @override
  Future<void> upsert(Survey s) => _db.transaction(() async {
        await _db.into(_db.surveyRows).insertOnConflictUpdate(
              SurveyRowsCompanion.insert(
                id: s.id,
                templateId: s.templateId,
                name: s.name,
                json: jsonEncode(s.toJson()),
              ),
            );
        await (_db.delete(_db.tombstoneRows)
              ..where((r) =>
                  r.kind.equals(Tombstone.kindSurvey) & r.id.equals(s.id)))
            .go();
      });

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
  Future<void> delete(String id) => _db.transaction(() async {
        await (_db.delete(_db.surveyRows)..where((r) => r.id.equals(id))).go();
        await _db.into(_db.tombstoneRows).insertOnConflictUpdate(
              TombstoneRowsCompanion.insert(
                kind: Tombstone.kindSurvey,
                id: id,
                deletedAt: DateTime.now().toUtc().toIso8601String(),
              ),
            );
      });
}

/// Drift-backed [SyncMetaStore]: tombstones + kv rows in the same database,
/// so store writes and their sync bookkeeping share one SQLite file.
class DriftSyncMetaStore implements SyncMetaStore {
  final AppDatabase _db;
  DriftSyncMetaStore(this._db);

  @override
  Future<void> addTombstone(Tombstone t) =>
      _db.into(_db.tombstoneRows).insertOnConflictUpdate(
            TombstoneRowsCompanion.insert(
              kind: t.kind,
              id: t.id,
              deletedAt: t.deletedAt.toUtc().toIso8601String(),
            ),
          );

  @override
  Future<void> removeTombstone(String kind, String id) =>
      (_db.delete(_db.tombstoneRows)
            ..where((r) => r.kind.equals(kind) & r.id.equals(id)))
          .go();

  @override
  Future<List<Tombstone>> tombstones() async {
    final rows = await _db.select(_db.tombstoneRows).get();
    return rows
        .map((r) => Tombstone(
              kind: r.kind,
              id: r.id,
              deletedAt: DateTime.parse(r.deletedAt),
            ))
        .toList();
  }

  @override
  Future<String?> kvGet(String key) async {
    final row = await (_db.select(_db.kvRows)
          ..where((r) => r.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  @override
  Future<void> kvSet(String key, String value) =>
      _db.into(_db.kvRows).insertOnConflictUpdate(
            KvRowsCompanion.insert(key: key, value: value),
          );
}
