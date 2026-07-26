/// Deletion marker kept after a template/survey row is removed, so sync can
/// propagate the delete instead of resurrecting the row from the other device.
/// Merge rule: a tombstone wins over an object update iff it is newer.
class Tombstone {
  static const kindTemplate = 'template';
  static const kindSurvey = 'survey';

  final String kind;
  final String id;
  final DateTime deletedAt;

  const Tombstone({
    required this.kind,
    required this.id,
    required this.deletedAt,
  });

  Map<String, dynamic> toJson() => {
        'kind': kind,
        'id': id,
        // UTC ("Z" suffix) so the paired device parses the same instant; a
        // bare local string would shift by the devices' zone difference and
        // could delete edits that are actually newer.
        'deletedAt': deletedAt.toUtc().toIso8601String(),
      };

  factory Tombstone.fromJson(Map<String, dynamic> j) => Tombstone(
        kind: j['kind'] as String,
        id: j['id'] as String,
        deletedAt: DateTime.parse(j['deletedAt'] as String),
      );
}
