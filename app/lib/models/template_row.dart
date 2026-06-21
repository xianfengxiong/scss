import 'dart:convert';

import 'field_def.dart';

/// Row kinds in a WYSIWYG table template (approximating an Excel survey form).
enum TemplateRowType { title, section, field, multiField, deviceTable, image }

TemplateRowType templateRowTypeFromName(String? n) =>
    TemplateRowType.values.firstWhere((e) => e.name == n,
        orElse: () => TemplateRowType.field);

String templateRowTypeLabel(TemplateRowType t) {
  switch (t) {
    case TemplateRowType.title:
      return 'Title';
    case TemplateRowType.section:
      return 'Section heading';
    case TemplateRowType.field:
      return 'Label + value';
    case TemplateRowType.multiField:
      return 'Multi-field row';
    case TemplateRowType.deviceTable:
      return 'Device table';
    case TemplateRowType.image:
      return 'Image area';
  }
}

/// A labelled, fillable cell (used by `field` and `multiField` rows).
class TemplateField {
  final String label;
  final String key;
  final FieldType type;
  final String? unit;
  final List<String> options;

  const TemplateField({
    required this.label,
    required this.key,
    this.type = FieldType.text,
    this.unit,
    this.options = const [],
  });

  TemplateField copyWith({
    String? label,
    String? key,
    FieldType? type,
    String? unit,
    List<String>? options,
  }) =>
      TemplateField(
        label: label ?? this.label,
        key: key ?? this.key,
        type: type ?? this.type,
        unit: unit ?? this.unit,
        options: options ?? this.options,
      );

  Map<String, dynamic> toJson() => {
        'label': label,
        'key': key,
        'type': type.name,
        if (unit != null) 'unit': unit,
        if (options.isNotEmpty) 'options': options,
      };

  factory TemplateField.fromJson(Map<String, dynamic> j) => TemplateField(
        label: j['label'] as String? ?? '',
        key: j['key'] as String? ?? '',
        type: fieldTypeFromName(j['type'] as String?),
        unit: j['unit'] as String?,
        options: (j['options'] as List?)?.map((e) => e.toString()).toList() ??
            const [],
      );
}

/// One row of a table template. The same rows drive the editor, the fill
/// screen and the PDF, so all three look identical (WYSIWYG).
class TemplateRow {
  final TemplateRowType type;
  final String text; // title / section heading / image caption
  final List<TemplateField> fields; // field: 1, multiField: n
  final String listKey; // deviceTable: survey.data key for the rows
  final List<String> columns; // deviceTable: column headers
  final String imageKind; // image: 'diagram' | 'photos'

  const TemplateRow({
    required this.type,
    this.text = '',
    this.fields = const [],
    this.listKey = '',
    this.columns = const [],
    this.imageKind = '',
  });

  factory TemplateRow.title(String text) =>
      TemplateRow(type: TemplateRowType.title, text: text);
  factory TemplateRow.section(String text) =>
      TemplateRow(type: TemplateRowType.section, text: text);
  factory TemplateRow.field(TemplateField f) =>
      TemplateRow(type: TemplateRowType.field, fields: [f]);
  factory TemplateRow.multiField(List<TemplateField> fs) =>
      TemplateRow(type: TemplateRowType.multiField, fields: fs);
  factory TemplateRow.deviceTable({
    required String listKey,
    required List<String> columns,
    String text = '',
  }) =>
      TemplateRow(
          type: TemplateRowType.deviceTable,
          listKey: listKey,
          columns: columns,
          text: text);
  factory TemplateRow.image({required String imageKind, String text = ''}) =>
      TemplateRow(type: TemplateRowType.image, imageKind: imageKind, text: text);

  TemplateRow copyWith({
    TemplateRowType? type,
    String? text,
    List<TemplateField>? fields,
    String? listKey,
    List<String>? columns,
    String? imageKind,
  }) =>
      TemplateRow(
        type: type ?? this.type,
        text: text ?? this.text,
        fields: fields ?? this.fields,
        listKey: listKey ?? this.listKey,
        columns: columns ?? this.columns,
        imageKind: imageKind ?? this.imageKind,
      );

  Map<String, dynamic> toJson() => {
        'type': type.name,
        if (text.isNotEmpty) 'text': text,
        if (fields.isNotEmpty) 'fields': fields.map((f) => f.toJson()).toList(),
        if (listKey.isNotEmpty) 'listKey': listKey,
        if (columns.isNotEmpty) 'columns': columns,
        if (imageKind.isNotEmpty) 'imageKind': imageKind,
      };

  factory TemplateRow.fromJson(Map<String, dynamic> j) => TemplateRow(
        type: templateRowTypeFromName(j['type'] as String?),
        text: j['text'] as String? ?? '',
        fields: (j['fields'] as List?)
                ?.map((e) => TemplateField.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        listKey: j['listKey'] as String? ?? '',
        columns:
            (j['columns'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        imageKind: j['imageKind'] as String? ?? '',
      );

  /// JSON helpers for the Drift TypeConverter on the `rows` column.
  static String encodeList(List<TemplateRow> rows) =>
      jsonEncode(rows.map((r) => r.toJson()).toList());

  static List<TemplateRow> decodeList(String s) => s.isEmpty
      ? const []
      : (jsonDecode(s) as List)
          .map((e) => TemplateRow.fromJson(e as Map<String, dynamic>))
          .toList();
}
