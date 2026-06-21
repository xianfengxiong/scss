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

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $TemplateRowsTable templateRows = $TemplateRowsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [templateRows];
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

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$TemplateRowsTableTableManager get templateRows =>
      $$TemplateRowsTableTableManager(_db, _db.templateRows);
}
