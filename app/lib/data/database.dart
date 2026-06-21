import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/gps_data.dart';
import '../models/pin.dart';
import '../models/template_row.dart';
import '../templates/default_template.dart';

part 'database.g.dart';

const _uuid = Uuid();

/// Site lifecycle status values.
class SiteStatus {
  static const draft = 'draft';
  static const completed = 'completed';
  static const exported = 'exported';
  static const all = [draft, completed, exported];
}

// --------------------------------------------------------------------------
// TypeConverters — nested objects are stored as JSON TEXT columns.
// --------------------------------------------------------------------------

class RowsConverter extends TypeConverter<List<TemplateRow>, String> {
  const RowsConverter();
  @override
  List<TemplateRow> fromSql(String fromDb) =>
      fromDb.isEmpty ? const [] : TemplateRow.decodeList(fromDb);
  @override
  String toSql(List<TemplateRow> value) => TemplateRow.encodeList(value);
}

class GpsConverter extends TypeConverter<GpsData, String> {
  const GpsConverter();
  @override
  GpsData fromSql(String fromDb) => GpsData.decode(fromDb);
  @override
  String toSql(GpsData value) => value.encode();
}

class PinsConverter extends TypeConverter<List<Pin>, String> {
  const PinsConverter();
  @override
  List<Pin> fromSql(String fromDb) {
    if (fromDb.isEmpty) return const [];
    return (jsonDecode(fromDb) as List)
        .map((e) => Pin.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  String toSql(List<Pin> value) =>
      jsonEncode(value.map((e) => e.toJson()).toList());
}

class StringListConverter extends TypeConverter<List<String>, String> {
  const StringListConverter();
  @override
  List<String> fromSql(String fromDb) {
    if (fromDb.isEmpty) return const [];
    return (jsonDecode(fromDb) as List).map((e) => e.toString()).toList();
  }

  @override
  String toSql(List<String> value) => jsonEncode(value);
}

class JsonMapConverter extends TypeConverter<Map<String, dynamic>, String> {
  const JsonMapConverter();
  @override
  Map<String, dynamic> fromSql(String fromDb) {
    if (fromDb.isEmpty) return {};
    return Map<String, dynamic>.from(jsonDecode(fromDb) as Map);
  }

  @override
  String toSql(Map<String, dynamic> value) => jsonEncode(value);
}

// --------------------------------------------------------------------------
// Tables
// --------------------------------------------------------------------------

class SurveyTemplates extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get rows => text().map(const RowsConverter())();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class Projects extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get templateId => text()();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class Sites extends Table {
  TextColumn get id => text()();
  TextColumn get projectId => text()();
  TextColumn get name => text()();
  TextColumn get city => text().withDefault(const Constant(''))();
  TextColumn get gps => text().map(const GpsConverter()).nullable()();
  TextColumn get pins => text().map(const PinsConverter())();
  TextColumn get diagramImagePath => text().nullable()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  TextColumn get imagePaths => text().map(const StringListConverter())();
  TextColumn get status =>
      text().withDefault(const Constant(SiteStatus.draft))();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class Surveys extends Table {
  TextColumn get id => text()();
  TextColumn get siteId => text()();
  TextColumn get templateId => text()();
  DateTimeColumn get timestamp =>
      dateTime().withDefault(currentDateAndTime)();
  TextColumn get data => text().map(const JsonMapConverter())();

  @override
  Set<Column> get primaryKey => {id};
}

// --------------------------------------------------------------------------
// Database
// --------------------------------------------------------------------------

@DriftDatabase(tables: [SurveyTemplates, Projects, Sites, Surveys])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  /// Seeds the default template into the library on first launch.
  Future<void> ensureSeeded() async {
    final existing = await select(surveyTemplates).get();
    if (existing.isEmpty) {
      await into(surveyTemplates).insert(
        SurveyTemplatesCompanion.insert(
          id: _uuid.v4(),
          name: kDefaultTemplateName,
          rows: defaultTemplateRows(),
        ),
      );
    }
  }

  // ---- Templates ----
  Stream<List<SurveyTemplate>> watchTemplates() => (select(surveyTemplates)
        ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
      .watch();

  Future<List<SurveyTemplate>> getTemplates() =>
      (select(surveyTemplates)
            ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
          .get();

  Future<SurveyTemplate?> getTemplate(String id) =>
      (select(surveyTemplates)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  Future<void> upsertTemplate(SurveyTemplate template) =>
      into(surveyTemplates).insertOnConflictUpdate(template);

  Future<String> createTemplate(String name, List<TemplateRow> rows) async {
    final id = _uuid.v4();
    await into(surveyTemplates).insert(SurveyTemplatesCompanion.insert(
      id: id,
      name: name,
      rows: rows,
    ));
    return id;
  }

  Future<void> deleteTemplate(String id) =>
      (delete(surveyTemplates)..where((t) => t.id.equals(id))).go();

  // ---- Projects ----
  Stream<List<Project>> watchProjects() => (select(projects)
        ..orderBy(
            [(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]))
      .watch();

  Future<Project?> getProject(String id) =>
      (select(projects)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<String> createProject(String name, String templateId) async {
    final id = _uuid.v4();
    await into(projects).insert(ProjectsCompanion.insert(
      id: id,
      name: name,
      templateId: templateId,
    ));
    return id;
  }

  Future<void> deleteProject(String id) async {
    await transaction(() async {
      final siteRows =
          await (select(sites)..where((t) => t.projectId.equals(id))).get();
      for (final s in siteRows) {
        await (delete(surveys)..where((t) => t.siteId.equals(s.id))).go();
      }
      await (delete(sites)..where((t) => t.projectId.equals(id))).go();
      await (delete(projects)..where((t) => t.id.equals(id))).go();
    });
  }

  // ---- Sites ----
  Stream<List<Site>> watchSites(String projectId) => (select(sites)
        ..where((t) => t.projectId.equals(projectId))
        ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
      .watch();

  Future<List<Site>> getSites(String projectId) => (select(sites)
        ..where((t) => t.projectId.equals(projectId))
        ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
      .get();

  Stream<Site?> watchSite(String id) =>
      (select(sites)..where((t) => t.id.equals(id))).watchSingleOrNull();

  Future<Site?> getSite(String id) =>
      (select(sites)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<String> createSite(String projectId, String name) async {
    final id = _uuid.v4();
    await into(sites).insert(SitesCompanion.insert(
      id: id,
      projectId: projectId,
      name: name,
      pins: const [],
      imagePaths: const [],
    ));
    return id;
  }

  Future<void> upsertSite(Site site) =>
      into(sites).insertOnConflictUpdate(site);

  Future<void> deleteSite(String id) async {
    await transaction(() async {
      await (delete(surveys)..where((t) => t.siteId.equals(id))).go();
      await (delete(sites)..where((t) => t.id.equals(id))).go();
    });
  }

  // ---- Surveys ----
  Future<Survey?> getSurveyForSite(String siteId) =>
      (select(surveys)..where((t) => t.siteId.equals(siteId)))
          .getSingleOrNull();

  Stream<Survey?> watchSurveyForSite(String siteId) =>
      (select(surveys)..where((t) => t.siteId.equals(siteId)))
          .watchSingleOrNull();

  Future<void> upsertSurvey(Survey survey) =>
      into(surveys).insertOnConflictUpdate(survey);

  /// Saves (creates or updates) the single primary survey for a site.
  Future<void> saveSurveyData(
      String siteId, String templateId, Map<String, dynamic> data) async {
    final existing = await getSurveyForSite(siteId);
    final survey = Survey(
      id: existing?.id ?? _uuid.v4(),
      siteId: siteId,
      templateId: templateId,
      timestamp: DateTime.now(),
      data: data,
    );
    await upsertSurvey(survey);
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'survey_v2.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
