/// One filled-in instance of a template: answers keyed by each control's
/// `dataKey`. Structure lives in the template; a survey only holds values.
class Survey {
  final String id;
  final String templateId;
  final String name;

  /// Answers, keyed by control dataKey (e.g. a field's `props['key']`).
  /// The same map is handed to `renderTemplate` so the PDF prints what was
  /// filled (WYSIWYG).
  final Map<String, dynamic> data;

  const Survey({
    required this.id,
    required this.templateId,
    required this.name,
    this.data = const {},
  });

  Survey copyWith({
    String? id,
    String? templateId,
    String? name,
    Map<String, dynamic>? data,
  }) =>
      Survey(
        id: id ?? this.id,
        templateId: templateId ?? this.templateId,
        name: name ?? this.name,
        data: data ?? this.data,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'templateId': templateId,
        'name': name,
        'data': data,
      };

  factory Survey.fromJson(Map<String, dynamic> j) => Survey(
        id: j['id'] as String,
        templateId: j['templateId'] as String,
        name: j['name'] as String,
        data: Map<String, dynamic>.from(j['data'] as Map? ?? const {}),
      );
}
