import 'dart:convert';

import 'package:drift/drift.dart';

import '../model/template.dart';
import 'connection.dart';
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

@DriftDatabase(tables: [TemplateRows])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// Production constructor: opens the on-device SQLite file.
  AppDatabase.open() : super(openConnection());

  @override
  int get schemaVersion => 1;
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
