// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $SurveyTemplatesTable extends SurveyTemplates
    with TableInfo<$SurveyTemplatesTable, SurveyTemplate> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SurveyTemplatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  late final GeneratedColumnWithTypeConverter<List<TemplateRow>, String> rows =
      GeneratedColumn<String>('rows', aliasedName, false,
              type: DriftSqlType.string, requiredDuringInsert: true)
          .withConverter<List<TemplateRow>>(
              $SurveyTemplatesTable.$converterrows);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [id, name, rows, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'survey_templates';
  @override
  VerificationContext validateIntegrity(Insertable<SurveyTemplate> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SurveyTemplate map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SurveyTemplate(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      rows: $SurveyTemplatesTable.$converterrows.fromSql(attachedDatabase
          .typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}rows'])!),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $SurveyTemplatesTable createAlias(String alias) {
    return $SurveyTemplatesTable(attachedDatabase, alias);
  }

  static TypeConverter<List<TemplateRow>, String> $converterrows =
      const RowsConverter();
}

class SurveyTemplate extends DataClass implements Insertable<SurveyTemplate> {
  final String id;
  final String name;
  final List<TemplateRow> rows;
  final DateTime createdAt;
  const SurveyTemplate(
      {required this.id,
      required this.name,
      required this.rows,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    {
      map['rows'] =
          Variable<String>($SurveyTemplatesTable.$converterrows.toSql(rows));
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  SurveyTemplatesCompanion toCompanion(bool nullToAbsent) {
    return SurveyTemplatesCompanion(
      id: Value(id),
      name: Value(name),
      rows: Value(rows),
      createdAt: Value(createdAt),
    );
  }

  factory SurveyTemplate.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SurveyTemplate(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      rows: serializer.fromJson<List<TemplateRow>>(json['rows']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'rows': serializer.toJson<List<TemplateRow>>(rows),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  SurveyTemplate copyWith(
          {String? id,
          String? name,
          List<TemplateRow>? rows,
          DateTime? createdAt}) =>
      SurveyTemplate(
        id: id ?? this.id,
        name: name ?? this.name,
        rows: rows ?? this.rows,
        createdAt: createdAt ?? this.createdAt,
      );
  SurveyTemplate copyWithCompanion(SurveyTemplatesCompanion data) {
    return SurveyTemplate(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      rows: data.rows.present ? data.rows.value : this.rows,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SurveyTemplate(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('rows: $rows, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, rows, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SurveyTemplate &&
          other.id == this.id &&
          other.name == this.name &&
          other.rows == this.rows &&
          other.createdAt == this.createdAt);
}

class SurveyTemplatesCompanion extends UpdateCompanion<SurveyTemplate> {
  final Value<String> id;
  final Value<String> name;
  final Value<List<TemplateRow>> rows;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const SurveyTemplatesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.rows = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SurveyTemplatesCompanion.insert({
    required String id,
    required String name,
    required List<TemplateRow> rows,
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        rows = Value(rows);
  static Insertable<SurveyTemplate> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? rows,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (rows != null) 'rows': rows,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SurveyTemplatesCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<List<TemplateRow>>? rows,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return SurveyTemplatesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      rows: rows ?? this.rows,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (rows.present) {
      map['rows'] = Variable<String>(
          $SurveyTemplatesTable.$converterrows.toSql(rows.value));
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SurveyTemplatesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('rows: $rows, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProjectsTable extends Projects with TableInfo<$ProjectsTable, Project> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProjectsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _templateIdMeta =
      const VerificationMeta('templateId');
  @override
  late final GeneratedColumn<String> templateId = GeneratedColumn<String>(
      'template_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [id, name, templateId, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'projects';
  @override
  VerificationContext validateIntegrity(Insertable<Project> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('template_id')) {
      context.handle(
          _templateIdMeta,
          templateId.isAcceptableOrUnknown(
              data['template_id']!, _templateIdMeta));
    } else if (isInserting) {
      context.missing(_templateIdMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Project map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Project(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      templateId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}template_id'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $ProjectsTable createAlias(String alias) {
    return $ProjectsTable(attachedDatabase, alias);
  }
}

class Project extends DataClass implements Insertable<Project> {
  final String id;
  final String name;
  final String templateId;
  final DateTime createdAt;
  const Project(
      {required this.id,
      required this.name,
      required this.templateId,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['template_id'] = Variable<String>(templateId);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ProjectsCompanion toCompanion(bool nullToAbsent) {
    return ProjectsCompanion(
      id: Value(id),
      name: Value(name),
      templateId: Value(templateId),
      createdAt: Value(createdAt),
    );
  }

  factory Project.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Project(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      templateId: serializer.fromJson<String>(json['templateId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'templateId': serializer.toJson<String>(templateId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Project copyWith(
          {String? id,
          String? name,
          String? templateId,
          DateTime? createdAt}) =>
      Project(
        id: id ?? this.id,
        name: name ?? this.name,
        templateId: templateId ?? this.templateId,
        createdAt: createdAt ?? this.createdAt,
      );
  Project copyWithCompanion(ProjectsCompanion data) {
    return Project(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      templateId:
          data.templateId.present ? data.templateId.value : this.templateId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Project(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('templateId: $templateId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, templateId, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Project &&
          other.id == this.id &&
          other.name == this.name &&
          other.templateId == this.templateId &&
          other.createdAt == this.createdAt);
}

class ProjectsCompanion extends UpdateCompanion<Project> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> templateId;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ProjectsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.templateId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProjectsCompanion.insert({
    required String id,
    required String name,
    required String templateId,
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        templateId = Value(templateId);
  static Insertable<Project> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? templateId,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (templateId != null) 'template_id': templateId,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProjectsCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<String>? templateId,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return ProjectsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      templateId: templateId ?? this.templateId,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (templateId.present) {
      map['template_id'] = Variable<String>(templateId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProjectsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('templateId: $templateId, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SitesTable extends Sites with TableInfo<$SitesTable, Site> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SitesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _projectIdMeta =
      const VerificationMeta('projectId');
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
      'project_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _cityMeta = const VerificationMeta('city');
  @override
  late final GeneratedColumn<String> city = GeneratedColumn<String>(
      'city', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  @override
  late final GeneratedColumnWithTypeConverter<GpsData?, String> gps =
      GeneratedColumn<String>('gps', aliasedName, true,
              type: DriftSqlType.string, requiredDuringInsert: false)
          .withConverter<GpsData?>($SitesTable.$convertergpsn);
  @override
  late final GeneratedColumnWithTypeConverter<List<Pin>, String> pins =
      GeneratedColumn<String>('pins', aliasedName, false,
              type: DriftSqlType.string, requiredDuringInsert: true)
          .withConverter<List<Pin>>($SitesTable.$converterpins);
  static const VerificationMeta _diagramImagePathMeta =
      const VerificationMeta('diagramImagePath');
  @override
  late final GeneratedColumn<String> diagramImagePath = GeneratedColumn<String>(
      'diagram_image_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
      'notes', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String> imagePaths =
      GeneratedColumn<String>('image_paths', aliasedName, false,
              type: DriftSqlType.string, requiredDuringInsert: true)
          .withConverter<List<String>>($SitesTable.$converterimagePaths);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(SiteStatus.draft));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        projectId,
        name,
        city,
        gps,
        pins,
        diagramImagePath,
        notes,
        imagePaths,
        status,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sites';
  @override
  VerificationContext validateIntegrity(Insertable<Site> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(_projectIdMeta,
          projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta));
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('city')) {
      context.handle(
          _cityMeta, city.isAcceptableOrUnknown(data['city']!, _cityMeta));
    }
    if (data.containsKey('diagram_image_path')) {
      context.handle(
          _diagramImagePathMeta,
          diagramImagePath.isAcceptableOrUnknown(
              data['diagram_image_path']!, _diagramImagePathMeta));
    }
    if (data.containsKey('notes')) {
      context.handle(
          _notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Site map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Site(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      projectId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}project_id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      city: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}city'])!,
      gps: $SitesTable.$convertergpsn.fromSql(attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}gps'])),
      pins: $SitesTable.$converterpins.fromSql(attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}pins'])!),
      diagramImagePath: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}diagram_image_path']),
      notes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}notes'])!,
      imagePaths: $SitesTable.$converterimagePaths.fromSql(attachedDatabase
          .typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}image_paths'])!),
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $SitesTable createAlias(String alias) {
    return $SitesTable(attachedDatabase, alias);
  }

  static TypeConverter<GpsData, String> $convertergps = const GpsConverter();
  static TypeConverter<GpsData?, String?> $convertergpsn =
      NullAwareTypeConverter.wrap($convertergps);
  static TypeConverter<List<Pin>, String> $converterpins =
      const PinsConverter();
  static TypeConverter<List<String>, String> $converterimagePaths =
      const StringListConverter();
}

class Site extends DataClass implements Insertable<Site> {
  final String id;
  final String projectId;
  final String name;
  final String city;
  final GpsData? gps;
  final List<Pin> pins;
  final String? diagramImagePath;
  final String notes;
  final List<String> imagePaths;
  final String status;
  final DateTime createdAt;
  const Site(
      {required this.id,
      required this.projectId,
      required this.name,
      required this.city,
      this.gps,
      required this.pins,
      this.diagramImagePath,
      required this.notes,
      required this.imagePaths,
      required this.status,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['project_id'] = Variable<String>(projectId);
    map['name'] = Variable<String>(name);
    map['city'] = Variable<String>(city);
    if (!nullToAbsent || gps != null) {
      map['gps'] = Variable<String>($SitesTable.$convertergpsn.toSql(gps));
    }
    {
      map['pins'] = Variable<String>($SitesTable.$converterpins.toSql(pins));
    }
    if (!nullToAbsent || diagramImagePath != null) {
      map['diagram_image_path'] = Variable<String>(diagramImagePath);
    }
    map['notes'] = Variable<String>(notes);
    {
      map['image_paths'] =
          Variable<String>($SitesTable.$converterimagePaths.toSql(imagePaths));
    }
    map['status'] = Variable<String>(status);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  SitesCompanion toCompanion(bool nullToAbsent) {
    return SitesCompanion(
      id: Value(id),
      projectId: Value(projectId),
      name: Value(name),
      city: Value(city),
      gps: gps == null && nullToAbsent ? const Value.absent() : Value(gps),
      pins: Value(pins),
      diagramImagePath: diagramImagePath == null && nullToAbsent
          ? const Value.absent()
          : Value(diagramImagePath),
      notes: Value(notes),
      imagePaths: Value(imagePaths),
      status: Value(status),
      createdAt: Value(createdAt),
    );
  }

  factory Site.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Site(
      id: serializer.fromJson<String>(json['id']),
      projectId: serializer.fromJson<String>(json['projectId']),
      name: serializer.fromJson<String>(json['name']),
      city: serializer.fromJson<String>(json['city']),
      gps: serializer.fromJson<GpsData?>(json['gps']),
      pins: serializer.fromJson<List<Pin>>(json['pins']),
      diagramImagePath: serializer.fromJson<String?>(json['diagramImagePath']),
      notes: serializer.fromJson<String>(json['notes']),
      imagePaths: serializer.fromJson<List<String>>(json['imagePaths']),
      status: serializer.fromJson<String>(json['status']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'projectId': serializer.toJson<String>(projectId),
      'name': serializer.toJson<String>(name),
      'city': serializer.toJson<String>(city),
      'gps': serializer.toJson<GpsData?>(gps),
      'pins': serializer.toJson<List<Pin>>(pins),
      'diagramImagePath': serializer.toJson<String?>(diagramImagePath),
      'notes': serializer.toJson<String>(notes),
      'imagePaths': serializer.toJson<List<String>>(imagePaths),
      'status': serializer.toJson<String>(status),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Site copyWith(
          {String? id,
          String? projectId,
          String? name,
          String? city,
          Value<GpsData?> gps = const Value.absent(),
          List<Pin>? pins,
          Value<String?> diagramImagePath = const Value.absent(),
          String? notes,
          List<String>? imagePaths,
          String? status,
          DateTime? createdAt}) =>
      Site(
        id: id ?? this.id,
        projectId: projectId ?? this.projectId,
        name: name ?? this.name,
        city: city ?? this.city,
        gps: gps.present ? gps.value : this.gps,
        pins: pins ?? this.pins,
        diagramImagePath: diagramImagePath.present
            ? diagramImagePath.value
            : this.diagramImagePath,
        notes: notes ?? this.notes,
        imagePaths: imagePaths ?? this.imagePaths,
        status: status ?? this.status,
        createdAt: createdAt ?? this.createdAt,
      );
  Site copyWithCompanion(SitesCompanion data) {
    return Site(
      id: data.id.present ? data.id.value : this.id,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      name: data.name.present ? data.name.value : this.name,
      city: data.city.present ? data.city.value : this.city,
      gps: data.gps.present ? data.gps.value : this.gps,
      pins: data.pins.present ? data.pins.value : this.pins,
      diagramImagePath: data.diagramImagePath.present
          ? data.diagramImagePath.value
          : this.diagramImagePath,
      notes: data.notes.present ? data.notes.value : this.notes,
      imagePaths:
          data.imagePaths.present ? data.imagePaths.value : this.imagePaths,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Site(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('name: $name, ')
          ..write('city: $city, ')
          ..write('gps: $gps, ')
          ..write('pins: $pins, ')
          ..write('diagramImagePath: $diagramImagePath, ')
          ..write('notes: $notes, ')
          ..write('imagePaths: $imagePaths, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, projectId, name, city, gps, pins,
      diagramImagePath, notes, imagePaths, status, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Site &&
          other.id == this.id &&
          other.projectId == this.projectId &&
          other.name == this.name &&
          other.city == this.city &&
          other.gps == this.gps &&
          other.pins == this.pins &&
          other.diagramImagePath == this.diagramImagePath &&
          other.notes == this.notes &&
          other.imagePaths == this.imagePaths &&
          other.status == this.status &&
          other.createdAt == this.createdAt);
}

class SitesCompanion extends UpdateCompanion<Site> {
  final Value<String> id;
  final Value<String> projectId;
  final Value<String> name;
  final Value<String> city;
  final Value<GpsData?> gps;
  final Value<List<Pin>> pins;
  final Value<String?> diagramImagePath;
  final Value<String> notes;
  final Value<List<String>> imagePaths;
  final Value<String> status;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const SitesCompanion({
    this.id = const Value.absent(),
    this.projectId = const Value.absent(),
    this.name = const Value.absent(),
    this.city = const Value.absent(),
    this.gps = const Value.absent(),
    this.pins = const Value.absent(),
    this.diagramImagePath = const Value.absent(),
    this.notes = const Value.absent(),
    this.imagePaths = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SitesCompanion.insert({
    required String id,
    required String projectId,
    required String name,
    this.city = const Value.absent(),
    this.gps = const Value.absent(),
    required List<Pin> pins,
    this.diagramImagePath = const Value.absent(),
    this.notes = const Value.absent(),
    required List<String> imagePaths,
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        projectId = Value(projectId),
        name = Value(name),
        pins = Value(pins),
        imagePaths = Value(imagePaths);
  static Insertable<Site> custom({
    Expression<String>? id,
    Expression<String>? projectId,
    Expression<String>? name,
    Expression<String>? city,
    Expression<String>? gps,
    Expression<String>? pins,
    Expression<String>? diagramImagePath,
    Expression<String>? notes,
    Expression<String>? imagePaths,
    Expression<String>? status,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectId != null) 'project_id': projectId,
      if (name != null) 'name': name,
      if (city != null) 'city': city,
      if (gps != null) 'gps': gps,
      if (pins != null) 'pins': pins,
      if (diagramImagePath != null) 'diagram_image_path': diagramImagePath,
      if (notes != null) 'notes': notes,
      if (imagePaths != null) 'image_paths': imagePaths,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SitesCompanion copyWith(
      {Value<String>? id,
      Value<String>? projectId,
      Value<String>? name,
      Value<String>? city,
      Value<GpsData?>? gps,
      Value<List<Pin>>? pins,
      Value<String?>? diagramImagePath,
      Value<String>? notes,
      Value<List<String>>? imagePaths,
      Value<String>? status,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return SitesCompanion(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      name: name ?? this.name,
      city: city ?? this.city,
      gps: gps ?? this.gps,
      pins: pins ?? this.pins,
      diagramImagePath: diagramImagePath ?? this.diagramImagePath,
      notes: notes ?? this.notes,
      imagePaths: imagePaths ?? this.imagePaths,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (city.present) {
      map['city'] = Variable<String>(city.value);
    }
    if (gps.present) {
      map['gps'] =
          Variable<String>($SitesTable.$convertergpsn.toSql(gps.value));
    }
    if (pins.present) {
      map['pins'] =
          Variable<String>($SitesTable.$converterpins.toSql(pins.value));
    }
    if (diagramImagePath.present) {
      map['diagram_image_path'] = Variable<String>(diagramImagePath.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (imagePaths.present) {
      map['image_paths'] = Variable<String>(
          $SitesTable.$converterimagePaths.toSql(imagePaths.value));
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SitesCompanion(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('name: $name, ')
          ..write('city: $city, ')
          ..write('gps: $gps, ')
          ..write('pins: $pins, ')
          ..write('diagramImagePath: $diagramImagePath, ')
          ..write('notes: $notes, ')
          ..write('imagePaths: $imagePaths, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SurveysTable extends Surveys with TableInfo<$SurveysTable, Survey> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SurveysTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _siteIdMeta = const VerificationMeta('siteId');
  @override
  late final GeneratedColumn<String> siteId = GeneratedColumn<String>(
      'site_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _templateIdMeta =
      const VerificationMeta('templateId');
  @override
  late final GeneratedColumn<String> templateId = GeneratedColumn<String>(
      'template_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _timestampMeta =
      const VerificationMeta('timestamp');
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
      'timestamp', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  late final GeneratedColumnWithTypeConverter<Map<String, dynamic>, String>
      data = GeneratedColumn<String>('data', aliasedName, false,
              type: DriftSqlType.string, requiredDuringInsert: true)
          .withConverter<Map<String, dynamic>>($SurveysTable.$converterdata);
  @override
  List<GeneratedColumn> get $columns =>
      [id, siteId, templateId, timestamp, data];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'surveys';
  @override
  VerificationContext validateIntegrity(Insertable<Survey> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('site_id')) {
      context.handle(_siteIdMeta,
          siteId.isAcceptableOrUnknown(data['site_id']!, _siteIdMeta));
    } else if (isInserting) {
      context.missing(_siteIdMeta);
    }
    if (data.containsKey('template_id')) {
      context.handle(
          _templateIdMeta,
          templateId.isAcceptableOrUnknown(
              data['template_id']!, _templateIdMeta));
    } else if (isInserting) {
      context.missing(_templateIdMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(_timestampMeta,
          timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Survey map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Survey(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      siteId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}site_id'])!,
      templateId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}template_id'])!,
      timestamp: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}timestamp'])!,
      data: $SurveysTable.$converterdata.fromSql(attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}data'])!),
    );
  }

  @override
  $SurveysTable createAlias(String alias) {
    return $SurveysTable(attachedDatabase, alias);
  }

  static TypeConverter<Map<String, dynamic>, String> $converterdata =
      const JsonMapConverter();
}

class Survey extends DataClass implements Insertable<Survey> {
  final String id;
  final String siteId;
  final String templateId;
  final DateTime timestamp;
  final Map<String, dynamic> data;
  const Survey(
      {required this.id,
      required this.siteId,
      required this.templateId,
      required this.timestamp,
      required this.data});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['site_id'] = Variable<String>(siteId);
    map['template_id'] = Variable<String>(templateId);
    map['timestamp'] = Variable<DateTime>(timestamp);
    {
      map['data'] = Variable<String>($SurveysTable.$converterdata.toSql(data));
    }
    return map;
  }

  SurveysCompanion toCompanion(bool nullToAbsent) {
    return SurveysCompanion(
      id: Value(id),
      siteId: Value(siteId),
      templateId: Value(templateId),
      timestamp: Value(timestamp),
      data: Value(data),
    );
  }

  factory Survey.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Survey(
      id: serializer.fromJson<String>(json['id']),
      siteId: serializer.fromJson<String>(json['siteId']),
      templateId: serializer.fromJson<String>(json['templateId']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
      data: serializer.fromJson<Map<String, dynamic>>(json['data']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'siteId': serializer.toJson<String>(siteId),
      'templateId': serializer.toJson<String>(templateId),
      'timestamp': serializer.toJson<DateTime>(timestamp),
      'data': serializer.toJson<Map<String, dynamic>>(data),
    };
  }

  Survey copyWith(
          {String? id,
          String? siteId,
          String? templateId,
          DateTime? timestamp,
          Map<String, dynamic>? data}) =>
      Survey(
        id: id ?? this.id,
        siteId: siteId ?? this.siteId,
        templateId: templateId ?? this.templateId,
        timestamp: timestamp ?? this.timestamp,
        data: data ?? this.data,
      );
  Survey copyWithCompanion(SurveysCompanion data) {
    return Survey(
      id: data.id.present ? data.id.value : this.id,
      siteId: data.siteId.present ? data.siteId.value : this.siteId,
      templateId:
          data.templateId.present ? data.templateId.value : this.templateId,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      data: data.data.present ? data.data.value : this.data,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Survey(')
          ..write('id: $id, ')
          ..write('siteId: $siteId, ')
          ..write('templateId: $templateId, ')
          ..write('timestamp: $timestamp, ')
          ..write('data: $data')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, siteId, templateId, timestamp, data);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Survey &&
          other.id == this.id &&
          other.siteId == this.siteId &&
          other.templateId == this.templateId &&
          other.timestamp == this.timestamp &&
          other.data == this.data);
}

class SurveysCompanion extends UpdateCompanion<Survey> {
  final Value<String> id;
  final Value<String> siteId;
  final Value<String> templateId;
  final Value<DateTime> timestamp;
  final Value<Map<String, dynamic>> data;
  final Value<int> rowid;
  const SurveysCompanion({
    this.id = const Value.absent(),
    this.siteId = const Value.absent(),
    this.templateId = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.data = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SurveysCompanion.insert({
    required String id,
    required String siteId,
    required String templateId,
    this.timestamp = const Value.absent(),
    required Map<String, dynamic> data,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        siteId = Value(siteId),
        templateId = Value(templateId),
        data = Value(data);
  static Insertable<Survey> custom({
    Expression<String>? id,
    Expression<String>? siteId,
    Expression<String>? templateId,
    Expression<DateTime>? timestamp,
    Expression<String>? data,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (siteId != null) 'site_id': siteId,
      if (templateId != null) 'template_id': templateId,
      if (timestamp != null) 'timestamp': timestamp,
      if (data != null) 'data': data,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SurveysCompanion copyWith(
      {Value<String>? id,
      Value<String>? siteId,
      Value<String>? templateId,
      Value<DateTime>? timestamp,
      Value<Map<String, dynamic>>? data,
      Value<int>? rowid}) {
    return SurveysCompanion(
      id: id ?? this.id,
      siteId: siteId ?? this.siteId,
      templateId: templateId ?? this.templateId,
      timestamp: timestamp ?? this.timestamp,
      data: data ?? this.data,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (siteId.present) {
      map['site_id'] = Variable<String>(siteId.value);
    }
    if (templateId.present) {
      map['template_id'] = Variable<String>(templateId.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (data.present) {
      map['data'] =
          Variable<String>($SurveysTable.$converterdata.toSql(data.value));
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SurveysCompanion(')
          ..write('id: $id, ')
          ..write('siteId: $siteId, ')
          ..write('templateId: $templateId, ')
          ..write('timestamp: $timestamp, ')
          ..write('data: $data, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SurveyTemplatesTable surveyTemplates =
      $SurveyTemplatesTable(this);
  late final $ProjectsTable projects = $ProjectsTable(this);
  late final $SitesTable sites = $SitesTable(this);
  late final $SurveysTable surveys = $SurveysTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [surveyTemplates, projects, sites, surveys];
}

typedef $$SurveyTemplatesTableCreateCompanionBuilder = SurveyTemplatesCompanion
    Function({
  required String id,
  required String name,
  required List<TemplateRow> rows,
  Value<DateTime> createdAt,
  Value<int> rowid,
});
typedef $$SurveyTemplatesTableUpdateCompanionBuilder = SurveyTemplatesCompanion
    Function({
  Value<String> id,
  Value<String> name,
  Value<List<TemplateRow>> rows,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$SurveyTemplatesTableFilterComposer
    extends Composer<_$AppDatabase, $SurveyTemplatesTable> {
  $$SurveyTemplatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<List<TemplateRow>, List<TemplateRow>, String>
      get rows => $composableBuilder(
          column: $table.rows,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$SurveyTemplatesTableOrderingComposer
    extends Composer<_$AppDatabase, $SurveyTemplatesTable> {
  $$SurveyTemplatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get rows => $composableBuilder(
      column: $table.rows, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$SurveyTemplatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SurveyTemplatesTable> {
  $$SurveyTemplatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<TemplateRow>, String> get rows =>
      $composableBuilder(column: $table.rows, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$SurveyTemplatesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SurveyTemplatesTable,
    SurveyTemplate,
    $$SurveyTemplatesTableFilterComposer,
    $$SurveyTemplatesTableOrderingComposer,
    $$SurveyTemplatesTableAnnotationComposer,
    $$SurveyTemplatesTableCreateCompanionBuilder,
    $$SurveyTemplatesTableUpdateCompanionBuilder,
    (
      SurveyTemplate,
      BaseReferences<_$AppDatabase, $SurveyTemplatesTable, SurveyTemplate>
    ),
    SurveyTemplate,
    PrefetchHooks Function()> {
  $$SurveyTemplatesTableTableManager(
      _$AppDatabase db, $SurveyTemplatesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SurveyTemplatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SurveyTemplatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SurveyTemplatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<List<TemplateRow>> rows = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SurveyTemplatesCompanion(
            id: id,
            name: name,
            rows: rows,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            required List<TemplateRow> rows,
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SurveyTemplatesCompanion.insert(
            id: id,
            name: name,
            rows: rows,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SurveyTemplatesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SurveyTemplatesTable,
    SurveyTemplate,
    $$SurveyTemplatesTableFilterComposer,
    $$SurveyTemplatesTableOrderingComposer,
    $$SurveyTemplatesTableAnnotationComposer,
    $$SurveyTemplatesTableCreateCompanionBuilder,
    $$SurveyTemplatesTableUpdateCompanionBuilder,
    (
      SurveyTemplate,
      BaseReferences<_$AppDatabase, $SurveyTemplatesTable, SurveyTemplate>
    ),
    SurveyTemplate,
    PrefetchHooks Function()>;
typedef $$ProjectsTableCreateCompanionBuilder = ProjectsCompanion Function({
  required String id,
  required String name,
  required String templateId,
  Value<DateTime> createdAt,
  Value<int> rowid,
});
typedef $$ProjectsTableUpdateCompanionBuilder = ProjectsCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String> templateId,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$ProjectsTableFilterComposer
    extends Composer<_$AppDatabase, $ProjectsTable> {
  $$ProjectsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get templateId => $composableBuilder(
      column: $table.templateId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$ProjectsTableOrderingComposer
    extends Composer<_$AppDatabase, $ProjectsTable> {
  $$ProjectsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get templateId => $composableBuilder(
      column: $table.templateId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$ProjectsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProjectsTable> {
  $$ProjectsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get templateId => $composableBuilder(
      column: $table.templateId, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ProjectsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ProjectsTable,
    Project,
    $$ProjectsTableFilterComposer,
    $$ProjectsTableOrderingComposer,
    $$ProjectsTableAnnotationComposer,
    $$ProjectsTableCreateCompanionBuilder,
    $$ProjectsTableUpdateCompanionBuilder,
    (Project, BaseReferences<_$AppDatabase, $ProjectsTable, Project>),
    Project,
    PrefetchHooks Function()> {
  $$ProjectsTableTableManager(_$AppDatabase db, $ProjectsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProjectsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProjectsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProjectsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> templateId = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ProjectsCompanion(
            id: id,
            name: name,
            templateId: templateId,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            required String templateId,
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ProjectsCompanion.insert(
            id: id,
            name: name,
            templateId: templateId,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ProjectsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ProjectsTable,
    Project,
    $$ProjectsTableFilterComposer,
    $$ProjectsTableOrderingComposer,
    $$ProjectsTableAnnotationComposer,
    $$ProjectsTableCreateCompanionBuilder,
    $$ProjectsTableUpdateCompanionBuilder,
    (Project, BaseReferences<_$AppDatabase, $ProjectsTable, Project>),
    Project,
    PrefetchHooks Function()>;
typedef $$SitesTableCreateCompanionBuilder = SitesCompanion Function({
  required String id,
  required String projectId,
  required String name,
  Value<String> city,
  Value<GpsData?> gps,
  required List<Pin> pins,
  Value<String?> diagramImagePath,
  Value<String> notes,
  required List<String> imagePaths,
  Value<String> status,
  Value<DateTime> createdAt,
  Value<int> rowid,
});
typedef $$SitesTableUpdateCompanionBuilder = SitesCompanion Function({
  Value<String> id,
  Value<String> projectId,
  Value<String> name,
  Value<String> city,
  Value<GpsData?> gps,
  Value<List<Pin>> pins,
  Value<String?> diagramImagePath,
  Value<String> notes,
  Value<List<String>> imagePaths,
  Value<String> status,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$SitesTableFilterComposer extends Composer<_$AppDatabase, $SitesTable> {
  $$SitesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get projectId => $composableBuilder(
      column: $table.projectId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get city => $composableBuilder(
      column: $table.city, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<GpsData?, GpsData, String> get gps =>
      $composableBuilder(
          column: $table.gps,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnWithTypeConverterFilters<List<Pin>, List<Pin>, String> get pins =>
      $composableBuilder(
          column: $table.pins,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<String> get diagramImagePath => $composableBuilder(
      column: $table.diagramImagePath,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<List<String>, List<String>, String>
      get imagePaths => $composableBuilder(
          column: $table.imagePaths,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$SitesTableOrderingComposer
    extends Composer<_$AppDatabase, $SitesTable> {
  $$SitesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get projectId => $composableBuilder(
      column: $table.projectId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get city => $composableBuilder(
      column: $table.city, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get gps => $composableBuilder(
      column: $table.gps, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get pins => $composableBuilder(
      column: $table.pins, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get diagramImagePath => $composableBuilder(
      column: $table.diagramImagePath,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get imagePaths => $composableBuilder(
      column: $table.imagePaths, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$SitesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SitesTable> {
  $$SitesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get projectId =>
      $composableBuilder(column: $table.projectId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get city =>
      $composableBuilder(column: $table.city, builder: (column) => column);

  GeneratedColumnWithTypeConverter<GpsData?, String> get gps =>
      $composableBuilder(column: $table.gps, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<Pin>, String> get pins =>
      $composableBuilder(column: $table.pins, builder: (column) => column);

  GeneratedColumn<String> get diagramImagePath => $composableBuilder(
      column: $table.diagramImagePath, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<String>, String> get imagePaths =>
      $composableBuilder(
          column: $table.imagePaths, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$SitesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SitesTable,
    Site,
    $$SitesTableFilterComposer,
    $$SitesTableOrderingComposer,
    $$SitesTableAnnotationComposer,
    $$SitesTableCreateCompanionBuilder,
    $$SitesTableUpdateCompanionBuilder,
    (Site, BaseReferences<_$AppDatabase, $SitesTable, Site>),
    Site,
    PrefetchHooks Function()> {
  $$SitesTableTableManager(_$AppDatabase db, $SitesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SitesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SitesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SitesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> projectId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> city = const Value.absent(),
            Value<GpsData?> gps = const Value.absent(),
            Value<List<Pin>> pins = const Value.absent(),
            Value<String?> diagramImagePath = const Value.absent(),
            Value<String> notes = const Value.absent(),
            Value<List<String>> imagePaths = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SitesCompanion(
            id: id,
            projectId: projectId,
            name: name,
            city: city,
            gps: gps,
            pins: pins,
            diagramImagePath: diagramImagePath,
            notes: notes,
            imagePaths: imagePaths,
            status: status,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String projectId,
            required String name,
            Value<String> city = const Value.absent(),
            Value<GpsData?> gps = const Value.absent(),
            required List<Pin> pins,
            Value<String?> diagramImagePath = const Value.absent(),
            Value<String> notes = const Value.absent(),
            required List<String> imagePaths,
            Value<String> status = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SitesCompanion.insert(
            id: id,
            projectId: projectId,
            name: name,
            city: city,
            gps: gps,
            pins: pins,
            diagramImagePath: diagramImagePath,
            notes: notes,
            imagePaths: imagePaths,
            status: status,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SitesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SitesTable,
    Site,
    $$SitesTableFilterComposer,
    $$SitesTableOrderingComposer,
    $$SitesTableAnnotationComposer,
    $$SitesTableCreateCompanionBuilder,
    $$SitesTableUpdateCompanionBuilder,
    (Site, BaseReferences<_$AppDatabase, $SitesTable, Site>),
    Site,
    PrefetchHooks Function()>;
typedef $$SurveysTableCreateCompanionBuilder = SurveysCompanion Function({
  required String id,
  required String siteId,
  required String templateId,
  Value<DateTime> timestamp,
  required Map<String, dynamic> data,
  Value<int> rowid,
});
typedef $$SurveysTableUpdateCompanionBuilder = SurveysCompanion Function({
  Value<String> id,
  Value<String> siteId,
  Value<String> templateId,
  Value<DateTime> timestamp,
  Value<Map<String, dynamic>> data,
  Value<int> rowid,
});

class $$SurveysTableFilterComposer
    extends Composer<_$AppDatabase, $SurveysTable> {
  $$SurveysTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get siteId => $composableBuilder(
      column: $table.siteId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get templateId => $composableBuilder(
      column: $table.templateId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<Map<String, dynamic>, Map<String, dynamic>,
          String>
      get data => $composableBuilder(
          column: $table.data,
          builder: (column) => ColumnWithTypeConverterFilters(column));
}

class $$SurveysTableOrderingComposer
    extends Composer<_$AppDatabase, $SurveysTable> {
  $$SurveysTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get siteId => $composableBuilder(
      column: $table.siteId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get templateId => $composableBuilder(
      column: $table.templateId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get data => $composableBuilder(
      column: $table.data, builder: (column) => ColumnOrderings(column));
}

class $$SurveysTableAnnotationComposer
    extends Composer<_$AppDatabase, $SurveysTable> {
  $$SurveysTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get siteId =>
      $composableBuilder(column: $table.siteId, builder: (column) => column);

  GeneratedColumn<String> get templateId => $composableBuilder(
      column: $table.templateId, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Map<String, dynamic>, String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);
}

class $$SurveysTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SurveysTable,
    Survey,
    $$SurveysTableFilterComposer,
    $$SurveysTableOrderingComposer,
    $$SurveysTableAnnotationComposer,
    $$SurveysTableCreateCompanionBuilder,
    $$SurveysTableUpdateCompanionBuilder,
    (Survey, BaseReferences<_$AppDatabase, $SurveysTable, Survey>),
    Survey,
    PrefetchHooks Function()> {
  $$SurveysTableTableManager(_$AppDatabase db, $SurveysTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SurveysTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SurveysTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SurveysTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> siteId = const Value.absent(),
            Value<String> templateId = const Value.absent(),
            Value<DateTime> timestamp = const Value.absent(),
            Value<Map<String, dynamic>> data = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SurveysCompanion(
            id: id,
            siteId: siteId,
            templateId: templateId,
            timestamp: timestamp,
            data: data,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String siteId,
            required String templateId,
            Value<DateTime> timestamp = const Value.absent(),
            required Map<String, dynamic> data,
            Value<int> rowid = const Value.absent(),
          }) =>
              SurveysCompanion.insert(
            id: id,
            siteId: siteId,
            templateId: templateId,
            timestamp: timestamp,
            data: data,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SurveysTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SurveysTable,
    Survey,
    $$SurveysTableFilterComposer,
    $$SurveysTableOrderingComposer,
    $$SurveysTableAnnotationComposer,
    $$SurveysTableCreateCompanionBuilder,
    $$SurveysTableUpdateCompanionBuilder,
    (Survey, BaseReferences<_$AppDatabase, $SurveysTable, Survey>),
    Survey,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SurveyTemplatesTableTableManager get surveyTemplates =>
      $$SurveyTemplatesTableTableManager(_db, _db.surveyTemplates);
  $$ProjectsTableTableManager get projects =>
      $$ProjectsTableTableManager(_db, _db.projects);
  $$SitesTableTableManager get sites =>
      $$SitesTableTableManager(_db, _db.sites);
  $$SurveysTableTableManager get surveys =>
      $$SurveysTableTableManager(_db, _db.surveys);
}
