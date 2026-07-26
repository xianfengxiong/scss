import '../data/survey_store.dart';
import '../data/sync_meta_store.dart';
import '../data/template_store.dart';
import '../model/tombstone.dart';
import 'media_file_store.dart';

/// Bumped when the wire format changes; both apps must speak the same
/// version (they are built from the same source, so a mismatch just means
/// "update the other device").
///
/// v2: templates carry `pages` (multi-page); a v1 app can't read them.
const syncProtocolVersion = 2;

/// Fixed LAN port the desktop's sync server listens on.
const syncDefaultPort = 17423;

/// One row in a manifest: enough to run [decideMerge] without the body.
class ManifestEntry {
  final String id;
  final DateTime? updatedAt;

  const ManifestEntry({required this.id, required this.updatedAt});

  Map<String, dynamic> toJson() => {
        'id': id,
        // UTC, matching the object serializers — see Template.toJson.
        if (updatedAt != null)
          'updatedAt': updatedAt!.toUtc().toIso8601String(),
      };

  factory ManifestEntry.fromJson(Map<String, dynamic> j) => ManifestEntry(
        id: j['id'] as String,
        updatedAt: j['updatedAt'] == null
            ? null
            : DateTime.parse(j['updatedAt'] as String),
      );
}

/// Everything one side needs to plan a sync pass against the other:
/// object ids + timestamps, tombstones, and which image files exist.
class SyncManifest {
  final int protocolVersion;
  final String deviceName;
  final List<ManifestEntry> templates;
  final List<ManifestEntry> surveys;
  final List<Tombstone> tombstones;
  final Set<String> files;

  const SyncManifest({
    required this.protocolVersion,
    required this.deviceName,
    required this.templates,
    required this.surveys,
    required this.tombstones,
    required this.files,
  });

  Map<String, dynamic> toJson() => {
        'protocolVersion': protocolVersion,
        'deviceName': deviceName,
        'templates': templates.map((e) => e.toJson()).toList(),
        'surveys': surveys.map((e) => e.toJson()).toList(),
        'tombstones': tombstones.map((t) => t.toJson()).toList(),
        'files': files.toList(),
      };

  factory SyncManifest.fromJson(Map<String, dynamic> j) => SyncManifest(
        protocolVersion: j['protocolVersion'] as int,
        deviceName: j['deviceName'] as String? ?? '',
        templates: [
          for (final e in j['templates'] as List)
            ManifestEntry.fromJson(e as Map<String, dynamic>)
        ],
        surveys: [
          for (final e in j['surveys'] as List)
            ManifestEntry.fromJson(e as Map<String, dynamic>)
        ],
        tombstones: [
          for (final e in j['tombstones'] as List)
            Tombstone.fromJson(e as Map<String, dynamic>)
        ],
        files: {...(j['files'] as List? ?? const []).cast<String>()},
      );
}

/// The manifest describing this device's current state.
Future<SyncManifest> buildLocalManifest({
  required TemplateStore templates,
  required SurveyStore surveys,
  required SyncMetaStore meta,
  required MediaFileStore files,
  required String deviceName,
}) async {
  final ts = await templates.all();
  final ss = await surveys.all();
  return SyncManifest(
    protocolVersion: syncProtocolVersion,
    deviceName: deviceName,
    templates: [
      for (final t in ts) ManifestEntry(id: t.id, updatedAt: t.updatedAt)
    ],
    surveys: [
      for (final s in ss) ManifestEntry(id: s.id, updatedAt: s.updatedAt)
    ],
    tombstones: await meta.tombstones(),
    files: await files.list(),
  );
}
