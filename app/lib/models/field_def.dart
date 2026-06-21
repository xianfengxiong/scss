import 'dart:convert';

/// Type of a survey template field.
///
/// Extends the PRD's `text | number | select` with:
/// - [coordinate]: a "lat, lon" text value (with a "use current GPS" helper).
/// - [deviceList]: a repeatable list of {type, number, remark} rows,
///   modelling the real form's "Type of device to install" table.
enum FieldType { text, number, select, coordinate, deviceList }

FieldType fieldTypeFromName(String? name) {
  return FieldType.values.firstWhere(
    (e) => e.name == name,
    orElse: () => FieldType.text,
  );
}

String fieldTypeLabel(FieldType type) {
  switch (type) {
    case FieldType.text:
      return 'Text';
    case FieldType.number:
      return 'Number';
    case FieldType.select:
      return 'Select';
    case FieldType.coordinate:
      return 'Coordinate';
    case FieldType.deviceList:
      return 'Device list';
  }
}

/// A single field definition inside a [TemplateSection].
class FieldDef {
  final String key;
  final String label;
  final FieldType type;
  final bool required;
  final String? unit;
  final List<String> options; // used by FieldType.select

  const FieldDef({
    required this.key,
    required this.label,
    this.type = FieldType.text,
    this.required = false,
    this.unit,
    this.options = const [],
  });

  FieldDef copyWith({
    String? key,
    String? label,
    FieldType? type,
    bool? required,
    String? unit,
    List<String>? options,
  }) {
    return FieldDef(
      key: key ?? this.key,
      label: label ?? this.label,
      type: type ?? this.type,
      required: required ?? this.required,
      unit: unit ?? this.unit,
      options: options ?? this.options,
    );
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        'label': label,
        'type': type.name,
        'required': required,
        if (unit != null) 'unit': unit,
        if (options.isNotEmpty) 'options': options,
      };

  factory FieldDef.fromJson(Map<String, dynamic> j) => FieldDef(
        key: j['key'] as String,
        label: j['label'] as String,
        type: fieldTypeFromName(j['type'] as String?),
        required: j['required'] as bool? ?? false,
        unit: j['unit'] as String?,
        options: (j['options'] as List?)?.map((e) => e.toString()).toList() ??
            const [],
      );
}

/// A titled group of fields. A [SurveyTemplate] is an ordered list of these.
class TemplateSection {
  final String title;
  final List<FieldDef> fields;

  const TemplateSection({required this.title, this.fields = const []});

  TemplateSection copyWith({String? title, List<FieldDef>? fields}) =>
      TemplateSection(
        title: title ?? this.title,
        fields: fields ?? this.fields,
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'fields': fields.map((f) => f.toJson()).toList(),
      };

  factory TemplateSection.fromJson(Map<String, dynamic> j) => TemplateSection(
        title: j['title'] as String,
        fields: (j['fields'] as List? ?? [])
            .map((e) => FieldDef.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  /// JSON helpers used by the Drift TypeConverter for the `sections` column.
  static String encodeList(List<TemplateSection> sections) =>
      jsonEncode(sections.map((s) => s.toJson()).toList());

  static List<TemplateSection> decodeList(String source) =>
      (jsonDecode(source) as List)
          .map((e) => TemplateSection.fromJson(e as Map<String, dynamic>))
          .toList();
}
