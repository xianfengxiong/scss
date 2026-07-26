import 'dart:typed_data';

import '../data/survey_store.dart';
import '../data/sync_meta_store.dart';
import '../data/template_store.dart';
import '../model/survey.dart';
import '../model/template.dart';
import '../model/tombstone.dart';
import 'media_file_store.dart';
import 'merge.dart';
import 'protocol.dart';

/// Server-side sync semantics, HTTP-free: what the paired device may read
/// and how its writes merge into this device's stores. [SyncServer] wraps
/// this in shelf; engine tests drive it directly via [InProcessTransport],
/// so the logic under test is exactly what production serves.
///
/// Writes are guarded by the same LWW rule the client plans with
/// ([decideMerge]) — a stale PUT is refused rather than clobbering a newer
/// row, which makes concurrent or repeated sync passes safe.
class SyncEndpoint {
  final TemplateStore templates;
  final SurveyStore surveys;
  final SyncMetaStore meta;
  final MediaFileStore files;
  final String deviceName;

  SyncEndpoint({
    required this.templates,
    required this.surveys,
    required this.meta,
    required this.files,
    required this.deviceName,
  });

  Future<SyncManifest> manifest() => buildLocalManifest(
        templates: templates,
        surveys: surveys,
        meta: meta,
        files: files,
        deviceName: deviceName,
      );

  Future<Map<String, dynamic>?> getTemplate(String id) async =>
      (await templates.get(id))?.toJson();

  Future<Map<String, dynamic>?> getSurvey(String id) async =>
      (await surveys.get(id))?.toJson();

  /// Merge an incoming template; false = refused because ours is newer.
  Future<bool> putTemplate(Map<String, dynamic> json) async {
    final t = Template.fromJson(json);
    if (!await _acceptsWrite(Tombstone.kindTemplate, t.id, t.updatedAt)) {
      return false;
    }
    await templates.upsert(t);
    return true;
  }

  /// Merge an incoming survey; false = refused because ours is newer.
  Future<bool> putSurvey(Map<String, dynamic> json) async {
    final s = Survey.fromJson(json);
    if (!await _acceptsWrite(Tombstone.kindSurvey, s.id, s.updatedAt)) {
      return false;
    }
    await surveys.upsert(s);
    return true;
  }

  /// Apply the peer's tombstones: delete anything they deleted, unless our
  /// copy was edited after the deletion (then we keep it and the next pull
  /// pushes it back to them).
  Future<void> applyTombstones(List<Tombstone> incoming) async {
    for (final t in incoming) {
      final action = decideMerge(
        localUpdated: await _presentAt(t.kind, t.id),
        localDeleted: await _tombstoneAt(t.kind, t.id),
        remoteDeleted: t.deletedAt,
      );
      if (action != MergeAction.deleteLocal) continue;
      switch (t.kind) {
        case Tombstone.kindTemplate:
          await templates.delete(t.id);
        case Tombstone.kindSurvey:
          await surveys.delete(t.id);
      }
      // delete() stamped "now"; adopt the peer's original deletion time so
      // the tombstone doesn't out-age edits made between then and now.
      await meta.addTombstone(t);
    }
  }

  Future<Uint8List?> getFile(String name) => files.read(name);

  Future<void> putFile(String name, Uint8List bytes) =>
      files.write(name, bytes);

  Future<DateTime?> _tombstoneAt(String kind, String id) async {
    for (final t in await meta.tombstones()) {
      if (t.kind == kind && t.id == id) return t.deletedAt;
    }
    return null;
  }

  /// This device's object timestamp for (kind, id): null when absent, epoch
  /// when present but saved before sync stamped updatedAt.
  Future<DateTime?> _presentAt(String kind, String id) async {
    switch (kind) {
      case Tombstone.kindTemplate:
        final t = await templates.get(id);
        return t == null ? null : (t.updatedAt ?? syncEpoch);
      case Tombstone.kindSurvey:
        final s = await surveys.get(id);
        return s == null ? null : (s.updatedAt ?? syncEpoch);
    }
    return null;
  }

  /// A write is accepted when the incoming timestamp is not older than every
  /// local event for that id (missing timestamps sort as epoch).
  Future<bool> _acceptsWrite(
      String kind, String id, DateTime? incomingUpdated) async {
    final action = decideMerge(
      localUpdated: await _presentAt(kind, id),
      localDeleted: await _tombstoneAt(kind, id),
      remoteUpdated: incomingUpdated ?? syncEpoch,
    );
    // From this side's perspective the incoming write is "remote": accept
    // exactly when the merge rule says the remote object should win here.
    return action == MergeAction.pullObject;
  }
}
