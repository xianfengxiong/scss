// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $TemplateRowsTable extends TemplateRows
    with TableInfo<$TemplateRowsTable, TemplateRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TemplateRowsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
      'json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, name, json];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'template_rows';
  @override
  VerificationContext validateIntegrity(Insertable<TemplateRow> instance,
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
    if (data.containsKey('json')) {
      context.handle(
          _jsonMeta, json.isAcceptableOrUnknown(data['json']!, _jsonMeta));
    } else if (isInserting) {
      context.missing(_jsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TemplateRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TemplateRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      json: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}json'])!,
    );
  }

  @override
  $TemplateRowsTable createAlias(String alias) {
    return $TemplateRowsTable(attachedDatabase, alias);
  }
}

class TemplateRow extends DataClass implements Insertable<TemplateRow> {
  final String id;
  final String name;
  final String json;
  const TemplateRow({required this.id, required this.name, required this.json});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['json'] = Variable<String>(json);
    return map;
  }

  TemplateRowsCompanion toCompanion(bool nullToAbsent) {
    return TemplateRowsCompanion(
      id: Value(id),
      name: Value(name),
      json: Value(json),
    );
  }

  factory TemplateRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TemplateRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      json: serializer.fromJson<String>(json['json']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'json': serializer.toJson<String>(json),
    };
  }

  TemplateRow copyWith({String? id, String? name, String? json}) => TemplateRow(
        id: id ?? this.id,
        name: name ?? this.name,
        json: json ?? this.json,
      );
  TemplateRow copyWithCompanion(TemplateRowsCompanion data) {
    return TemplateRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      json: data.json.present ? data.json.value : this.json,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TemplateRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('json: $json')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, json);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TemplateRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.json == this.json);
}

class TemplateRowsCompanion extends UpdateCompanion<TemplateRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> json;
  final Value<int> rowid;
  const TemplateRowsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.json = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TemplateRowsCompanion.insert({
    required String id,
    required String name,
    required String json,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        json = Value(json);
  static Insertable<TemplateRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? json,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (json != null) 'json': json,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TemplateRowsCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<String>? json,
      Value<int>? rowid}) {
    return TemplateRowsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      json: json ?? this.json,
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
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TemplateRowsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('json: $json, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SurveyRowsTable extends SurveyRows
    with TableInfo<$SurveyRowsTable, SurveyRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SurveyRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _templateIdMeta =
      const VerificationMeta('templateId');
  @override
  late final GeneratedColumn<String> templateId = GeneratedColumn<String>(
      'template_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
      'json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, templateId, name, json];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'survey_rows';
  @override
  VerificationContext validateIntegrity(Insertable<SurveyRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('template_id')) {
      context.handle(
          _templateIdMeta,
          templateId.isAcceptableOrUnknown(
              data['template_id']!, _templateIdMeta));
    } else if (isInserting) {
      context.missing(_templateIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('json')) {
      context.handle(
          _jsonMeta, json.isAcceptableOrUnknown(data['json']!, _jsonMeta));
    } else if (isInserting) {
      context.missing(_jsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SurveyRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SurveyRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      templateId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}template_id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      json: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}json'])!,
    );
  }

  @override
  $SurveyRowsTable createAlias(String alias) {
    return $SurveyRowsTable(attachedDatabase, alias);
  }
}

class SurveyRow extends DataClass implements Insertable<SurveyRow> {
  final String id;
  final String templateId;
  final String name;
  final String json;
  const SurveyRow(
      {required this.id,
      required this.templateId,
      required this.name,
      required this.json});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['template_id'] = Variable<String>(templateId);
    map['name'] = Variable<String>(name);
    map['json'] = Variable<String>(json);
    return map;
  }

  SurveyRowsCompanion toCompanion(bool nullToAbsent) {
    return SurveyRowsCompanion(
      id: Value(id),
      templateId: Value(templateId),
      name: Value(name),
      json: Value(json),
    );
  }

  factory SurveyRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SurveyRow(
      id: serializer.fromJson<String>(json['id']),
      templateId: serializer.fromJson<String>(json['templateId']),
      name: serializer.fromJson<String>(json['name']),
      json: serializer.fromJson<String>(json['json']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'templateId': serializer.toJson<String>(templateId),
      'name': serializer.toJson<String>(name),
      'json': serializer.toJson<String>(json),
    };
  }

  SurveyRow copyWith(
          {String? id, String? templateId, String? name, String? json}) =>
      SurveyRow(
        id: id ?? this.id,
        templateId: templateId ?? this.templateId,
        name: name ?? this.name,
        json: json ?? this.json,
      );
  SurveyRow copyWithCompanion(SurveyRowsCompanion data) {
    return SurveyRow(
      id: data.id.present ? data.id.value : this.id,
      templateId:
          data.templateId.present ? data.templateId.value : this.templateId,
      name: data.name.present ? data.name.value : this.name,
      json: data.json.present ? data.json.value : this.json,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SurveyRow(')
          ..write('id: $id, ')
          ..write('templateId: $templateId, ')
          ..write('name: $name, ')
          ..write('json: $json')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, templateId, name, json);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SurveyRow &&
          other.id == this.id &&
          other.templateId == this.templateId &&
          other.name == this.name &&
          other.json == this.json);
}

class SurveyRowsCompanion extends UpdateCompanion<SurveyRow> {
  final Value<String> id;
  final Value<String> templateId;
  final Value<String> name;
  final Value<String> json;
  final Value<int> rowid;
  const SurveyRowsCompanion({
    this.id = const Value.absent(),
    this.templateId = const Value.absent(),
    this.name = const Value.absent(),
    this.json = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SurveyRowsCompanion.insert({
    required String id,
    required String templateId,
    required String name,
    required String json,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        templateId = Value(templateId),
        name = Value(name),
        json = Value(json);
  static Insertable<SurveyRow> custom({
    Expression<String>? id,
    Expression<String>? templateId,
    Expression<String>? name,
    Expression<String>? json,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (templateId != null) 'template_id': templateId,
      if (name != null) 'name': name,
      if (json != null) 'json': json,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SurveyRowsCompanion copyWith(
      {Value<String>? id,
      Value<String>? templateId,
      Value<String>? name,
      Value<String>? json,
      Value<int>? rowid}) {
    return SurveyRowsCompanion(
      id: id ?? this.id,
      templateId: templateId ?? this.templateId,
      name: name ?? this.name,
      json: json ?? this.json,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (templateId.present) {
      map['template_id'] = Variable<String>(templateId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SurveyRowsCompanion(')
          ..write('id: $id, ')
          ..write('templateId: $templateId, ')
          ..write('name: $name, ')
          ..write('json: $json, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TombstoneRowsTable extends TombstoneRows
    with TableInfo<$TombstoneRowsTable, TombstoneRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TombstoneRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
      'kind', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<String> deletedAt = GeneratedColumn<String>(
      'deleted_at', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [kind, id, deletedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tombstone_rows';
  @override
  VerificationContext validateIntegrity(Insertable<TombstoneRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('kind')) {
      context.handle(
          _kindMeta, kind.isAcceptableOrUnknown(data['kind']!, _kindMeta));
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    } else if (isInserting) {
      context.missing(_deletedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {kind, id};
  @override
  TombstoneRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TombstoneRow(
      kind: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}kind'])!,
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}deleted_at'])!,
    );
  }

  @override
  $TombstoneRowsTable createAlias(String alias) {
    return $TombstoneRowsTable(attachedDatabase, alias);
  }
}

class TombstoneRow extends DataClass implements Insertable<TombstoneRow> {
  final String kind;
  final String id;
  final String deletedAt;
  const TombstoneRow(
      {required this.kind, required this.id, required this.deletedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['kind'] = Variable<String>(kind);
    map['id'] = Variable<String>(id);
    map['deleted_at'] = Variable<String>(deletedAt);
    return map;
  }

  TombstoneRowsCompanion toCompanion(bool nullToAbsent) {
    return TombstoneRowsCompanion(
      kind: Value(kind),
      id: Value(id),
      deletedAt: Value(deletedAt),
    );
  }

  factory TombstoneRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TombstoneRow(
      kind: serializer.fromJson<String>(json['kind']),
      id: serializer.fromJson<String>(json['id']),
      deletedAt: serializer.fromJson<String>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'kind': serializer.toJson<String>(kind),
      'id': serializer.toJson<String>(id),
      'deletedAt': serializer.toJson<String>(deletedAt),
    };
  }

  TombstoneRow copyWith({String? kind, String? id, String? deletedAt}) =>
      TombstoneRow(
        kind: kind ?? this.kind,
        id: id ?? this.id,
        deletedAt: deletedAt ?? this.deletedAt,
      );
  TombstoneRow copyWithCompanion(TombstoneRowsCompanion data) {
    return TombstoneRow(
      kind: data.kind.present ? data.kind.value : this.kind,
      id: data.id.present ? data.id.value : this.id,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TombstoneRow(')
          ..write('kind: $kind, ')
          ..write('id: $id, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(kind, id, deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TombstoneRow &&
          other.kind == this.kind &&
          other.id == this.id &&
          other.deletedAt == this.deletedAt);
}

class TombstoneRowsCompanion extends UpdateCompanion<TombstoneRow> {
  final Value<String> kind;
  final Value<String> id;
  final Value<String> deletedAt;
  final Value<int> rowid;
  const TombstoneRowsCompanion({
    this.kind = const Value.absent(),
    this.id = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TombstoneRowsCompanion.insert({
    required String kind,
    required String id,
    required String deletedAt,
    this.rowid = const Value.absent(),
  })  : kind = Value(kind),
        id = Value(id),
        deletedAt = Value(deletedAt);
  static Insertable<TombstoneRow> custom({
    Expression<String>? kind,
    Expression<String>? id,
    Expression<String>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (kind != null) 'kind': kind,
      if (id != null) 'id': id,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TombstoneRowsCompanion copyWith(
      {Value<String>? kind,
      Value<String>? id,
      Value<String>? deletedAt,
      Value<int>? rowid}) {
    return TombstoneRowsCompanion(
      kind: kind ?? this.kind,
      id: id ?? this.id,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<String>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TombstoneRowsCompanion(')
          ..write('kind: $kind, ')
          ..write('id: $id, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $KvRowsTable extends KvRows with TableInfo<$KvRowsTable, KvRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $KvRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
      'key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
      'value', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'kv_rows';
  @override
  VerificationContext validateIntegrity(Insertable<KvRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
          _keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
          _valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  KvRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return KvRow(
      key: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      value: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}value'])!,
    );
  }

  @override
  $KvRowsTable createAlias(String alias) {
    return $KvRowsTable(attachedDatabase, alias);
  }
}

class KvRow extends DataClass implements Insertable<KvRow> {
  final String key;
  final String value;
  const KvRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  KvRowsCompanion toCompanion(bool nullToAbsent) {
    return KvRowsCompanion(
      key: Value(key),
      value: Value(value),
    );
  }

  factory KvRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return KvRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  KvRow copyWith({String? key, String? value}) => KvRow(
        key: key ?? this.key,
        value: value ?? this.value,
      );
  KvRow copyWithCompanion(KvRowsCompanion data) {
    return KvRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('KvRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is KvRow && other.key == this.key && other.value == this.value);
}

class KvRowsCompanion extends UpdateCompanion<KvRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const KvRowsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  KvRowsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  })  : key = Value(key),
        value = Value(value);
  static Insertable<KvRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  KvRowsCompanion copyWith(
      {Value<String>? key, Value<String>? value, Value<int>? rowid}) {
    return KvRowsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('KvRowsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $TemplateRowsTable templateRows = $TemplateRowsTable(this);
  late final $SurveyRowsTable surveyRows = $SurveyRowsTable(this);
  late final $TombstoneRowsTable tombstoneRows = $TombstoneRowsTable(this);
  late final $KvRowsTable kvRows = $KvRowsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [templateRows, surveyRows, tombstoneRows, kvRows];
}

typedef $$TemplateRowsTableCreateCompanionBuilder = TemplateRowsCompanion
    Function({
  required String id,
  required String name,
  required String json,
  Value<int> rowid,
});
typedef $$TemplateRowsTableUpdateCompanionBuilder = TemplateRowsCompanion
    Function({
  Value<String> id,
  Value<String> name,
  Value<String> json,
  Value<int> rowid,
});

class $$TemplateRowsTableFilterComposer
    extends Composer<_$AppDatabase, $TemplateRowsTable> {
  $$TemplateRowsTableFilterComposer({
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

  ColumnFilters<String> get json => $composableBuilder(
      column: $table.json, builder: (column) => ColumnFilters(column));
}

class $$TemplateRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $TemplateRowsTable> {
  $$TemplateRowsTableOrderingComposer({
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

  ColumnOrderings<String> get json => $composableBuilder(
      column: $table.json, builder: (column) => ColumnOrderings(column));
}

class $$TemplateRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TemplateRowsTable> {
  $$TemplateRowsTableAnnotationComposer({
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

  GeneratedColumn<String> get json =>
      $composableBuilder(column: $table.json, builder: (column) => column);
}

class $$TemplateRowsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $TemplateRowsTable,
    TemplateRow,
    $$TemplateRowsTableFilterComposer,
    $$TemplateRowsTableOrderingComposer,
    $$TemplateRowsTableAnnotationComposer,
    $$TemplateRowsTableCreateCompanionBuilder,
    $$TemplateRowsTableUpdateCompanionBuilder,
    (
      TemplateRow,
      BaseReferences<_$AppDatabase, $TemplateRowsTable, TemplateRow>
    ),
    TemplateRow,
    PrefetchHooks Function()> {
  $$TemplateRowsTableTableManager(_$AppDatabase db, $TemplateRowsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TemplateRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TemplateRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TemplateRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> json = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TemplateRowsCompanion(
            id: id,
            name: name,
            json: json,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            required String json,
            Value<int> rowid = const Value.absent(),
          }) =>
              TemplateRowsCompanion.insert(
            id: id,
            name: name,
            json: json,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$TemplateRowsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $TemplateRowsTable,
    TemplateRow,
    $$TemplateRowsTableFilterComposer,
    $$TemplateRowsTableOrderingComposer,
    $$TemplateRowsTableAnnotationComposer,
    $$TemplateRowsTableCreateCompanionBuilder,
    $$TemplateRowsTableUpdateCompanionBuilder,
    (
      TemplateRow,
      BaseReferences<_$AppDatabase, $TemplateRowsTable, TemplateRow>
    ),
    TemplateRow,
    PrefetchHooks Function()>;
typedef $$SurveyRowsTableCreateCompanionBuilder = SurveyRowsCompanion Function({
  required String id,
  required String templateId,
  required String name,
  required String json,
  Value<int> rowid,
});
typedef $$SurveyRowsTableUpdateCompanionBuilder = SurveyRowsCompanion Function({
  Value<String> id,
  Value<String> templateId,
  Value<String> name,
  Value<String> json,
  Value<int> rowid,
});

class $$SurveyRowsTableFilterComposer
    extends Composer<_$AppDatabase, $SurveyRowsTable> {
  $$SurveyRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get templateId => $composableBuilder(
      column: $table.templateId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get json => $composableBuilder(
      column: $table.json, builder: (column) => ColumnFilters(column));
}

class $$SurveyRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $SurveyRowsTable> {
  $$SurveyRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get templateId => $composableBuilder(
      column: $table.templateId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get json => $composableBuilder(
      column: $table.json, builder: (column) => ColumnOrderings(column));
}

class $$SurveyRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SurveyRowsTable> {
  $$SurveyRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get templateId => $composableBuilder(
      column: $table.templateId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get json =>
      $composableBuilder(column: $table.json, builder: (column) => column);
}

class $$SurveyRowsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SurveyRowsTable,
    SurveyRow,
    $$SurveyRowsTableFilterComposer,
    $$SurveyRowsTableOrderingComposer,
    $$SurveyRowsTableAnnotationComposer,
    $$SurveyRowsTableCreateCompanionBuilder,
    $$SurveyRowsTableUpdateCompanionBuilder,
    (SurveyRow, BaseReferences<_$AppDatabase, $SurveyRowsTable, SurveyRow>),
    SurveyRow,
    PrefetchHooks Function()> {
  $$SurveyRowsTableTableManager(_$AppDatabase db, $SurveyRowsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SurveyRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SurveyRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SurveyRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> templateId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> json = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SurveyRowsCompanion(
            id: id,
            templateId: templateId,
            name: name,
            json: json,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String templateId,
            required String name,
            required String json,
            Value<int> rowid = const Value.absent(),
          }) =>
              SurveyRowsCompanion.insert(
            id: id,
            templateId: templateId,
            name: name,
            json: json,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SurveyRowsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SurveyRowsTable,
    SurveyRow,
    $$SurveyRowsTableFilterComposer,
    $$SurveyRowsTableOrderingComposer,
    $$SurveyRowsTableAnnotationComposer,
    $$SurveyRowsTableCreateCompanionBuilder,
    $$SurveyRowsTableUpdateCompanionBuilder,
    (SurveyRow, BaseReferences<_$AppDatabase, $SurveyRowsTable, SurveyRow>),
    SurveyRow,
    PrefetchHooks Function()>;
typedef $$TombstoneRowsTableCreateCompanionBuilder = TombstoneRowsCompanion
    Function({
  required String kind,
  required String id,
  required String deletedAt,
  Value<int> rowid,
});
typedef $$TombstoneRowsTableUpdateCompanionBuilder = TombstoneRowsCompanion
    Function({
  Value<String> kind,
  Value<String> id,
  Value<String> deletedAt,
  Value<int> rowid,
});

class $$TombstoneRowsTableFilterComposer
    extends Composer<_$AppDatabase, $TombstoneRowsTable> {
  $$TombstoneRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));
}

class $$TombstoneRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $TombstoneRowsTable> {
  $$TombstoneRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));
}

class $$TombstoneRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TombstoneRowsTable> {
  $$TombstoneRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$TombstoneRowsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $TombstoneRowsTable,
    TombstoneRow,
    $$TombstoneRowsTableFilterComposer,
    $$TombstoneRowsTableOrderingComposer,
    $$TombstoneRowsTableAnnotationComposer,
    $$TombstoneRowsTableCreateCompanionBuilder,
    $$TombstoneRowsTableUpdateCompanionBuilder,
    (
      TombstoneRow,
      BaseReferences<_$AppDatabase, $TombstoneRowsTable, TombstoneRow>
    ),
    TombstoneRow,
    PrefetchHooks Function()> {
  $$TombstoneRowsTableTableManager(_$AppDatabase db, $TombstoneRowsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TombstoneRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TombstoneRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TombstoneRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> kind = const Value.absent(),
            Value<String> id = const Value.absent(),
            Value<String> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TombstoneRowsCompanion(
            kind: kind,
            id: id,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String kind,
            required String id,
            required String deletedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              TombstoneRowsCompanion.insert(
            kind: kind,
            id: id,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$TombstoneRowsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $TombstoneRowsTable,
    TombstoneRow,
    $$TombstoneRowsTableFilterComposer,
    $$TombstoneRowsTableOrderingComposer,
    $$TombstoneRowsTableAnnotationComposer,
    $$TombstoneRowsTableCreateCompanionBuilder,
    $$TombstoneRowsTableUpdateCompanionBuilder,
    (
      TombstoneRow,
      BaseReferences<_$AppDatabase, $TombstoneRowsTable, TombstoneRow>
    ),
    TombstoneRow,
    PrefetchHooks Function()>;
typedef $$KvRowsTableCreateCompanionBuilder = KvRowsCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$KvRowsTableUpdateCompanionBuilder = KvRowsCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$KvRowsTableFilterComposer
    extends Composer<_$AppDatabase, $KvRowsTable> {
  $$KvRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnFilters(column));
}

class $$KvRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $KvRowsTable> {
  $$KvRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnOrderings(column));
}

class $$KvRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $KvRowsTable> {
  $$KvRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$KvRowsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $KvRowsTable,
    KvRow,
    $$KvRowsTableFilterComposer,
    $$KvRowsTableOrderingComposer,
    $$KvRowsTableAnnotationComposer,
    $$KvRowsTableCreateCompanionBuilder,
    $$KvRowsTableUpdateCompanionBuilder,
    (KvRow, BaseReferences<_$AppDatabase, $KvRowsTable, KvRow>),
    KvRow,
    PrefetchHooks Function()> {
  $$KvRowsTableTableManager(_$AppDatabase db, $KvRowsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$KvRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$KvRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$KvRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              KvRowsCompanion(
            key: key,
            value: value,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) =>
              KvRowsCompanion.insert(
            key: key,
            value: value,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$KvRowsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $KvRowsTable,
    KvRow,
    $$KvRowsTableFilterComposer,
    $$KvRowsTableOrderingComposer,
    $$KvRowsTableAnnotationComposer,
    $$KvRowsTableCreateCompanionBuilder,
    $$KvRowsTableUpdateCompanionBuilder,
    (KvRow, BaseReferences<_$AppDatabase, $KvRowsTable, KvRow>),
    KvRow,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$TemplateRowsTableTableManager get templateRows =>
      $$TemplateRowsTableTableManager(_db, _db.templateRows);
  $$SurveyRowsTableTableManager get surveyRows =>
      $$SurveyRowsTableTableManager(_db, _db.surveyRows);
  $$TombstoneRowsTableTableManager get tombstoneRows =>
      $$TombstoneRowsTableTableManager(_db, _db.tombstoneRows);
  $$KvRowsTableTableManager get kvRows =>
      $$KvRowsTableTableManager(_db, _db.kvRows);
}
