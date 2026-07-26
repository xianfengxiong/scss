import '../data/survey_store.dart';
import '../data/sync_meta_store.dart';
import '../data/template_store.dart';
import '../model/survey.dart';
import '../model/template.dart';
import '../model/tombstone.dart';
import 'file_refs.dart';
import 'media_file_store.dart';
import 'merge.dart';
import 'protocol.dart';
import 'transport.dart';

class SyncException implements Exception {
  final String message;
  SyncException(this.message);
  @override
  String toString() => message;
}

/// What one sync pass did, for the result snackbar/summary.
class SyncReport {
  int pulledTemplates = 0;
  int pushedTemplates = 0;
  int pulledSurveys = 0;
  int pushedSurveys = 0;
  int deletedLocal = 0;
  int deletedRemote = 0;
  int filesPulled = 0;
  int filesPushed = 0;

  bool get isEmpty =>
      pulledTemplates == 0 &&
      pushedTemplates == 0 &&
      pulledSurveys == 0 &&
      pushedSurveys == 0 &&
      deletedLocal == 0 &&
      deletedRemote == 0 &&
      filesPulled == 0 &&
      filesPushed == 0;
}

/// Client-driven two-way merge: fetch the peer's manifest, decide per id
/// with [decideMerge], then pull/push objects, exchange deletions, and move
/// the image files each transferred survey references. Templates go first so
/// a pulled survey never lands before its template; files go before their
/// survey row so the UI never shows a broken image mid-sync.
class SyncEngine {
  final TemplateStore templates;
  final SurveyStore surveys;
  final SyncMetaStore meta;
  final MediaFileStore files;

  SyncEngine({
    required this.templates,
    required this.surveys,
    required this.meta,
    required this.files,
  });

  Future<SyncReport> run(SyncTransport transport,
      {void Function(String message)? onProgress}) async {
    void progress(String m) => onProgress?.call(m);

    progress('获取对方清单…');
    final remote = await transport.fetchManifest();
    if (remote.protocolVersion != syncProtocolVersion) {
      throw SyncException(
          '协议版本不匹配(本机 v$syncProtocolVersion,对方 v${remote.protocolVersion}),请把两端应用升到同一版本');
    }
    final local = await _localManifest();
    final report = SyncReport();

    progress('同步模版…');
    await _mergeKind(
      kind: Tombstone.kindTemplate,
      local: local,
      remote: remote,
      report: report,
      transport: transport,
    );

    progress('同步调查表…');
    await _mergeKind(
      kind: Tombstone.kindSurvey,
      local: local,
      remote: remote,
      report: report,
      transport: transport,
      progress: progress,
    );

    return report;
  }

  Future<SyncManifest> _localManifest() => buildLocalManifest(
        templates: templates,
        surveys: surveys,
        meta: meta,
        files: files,
        deviceName: 'local',
      );

  Future<void> _mergeKind({
    required String kind,
    required SyncManifest local,
    required SyncManifest remote,
    required SyncReport report,
    required SyncTransport transport,
    void Function(String message)? progress,
  }) async {
    final localEntries = _byId(kind == Tombstone.kindTemplate
        ? local.templates
        : local.surveys);
    final remoteEntries = _byId(kind == Tombstone.kindTemplate
        ? remote.templates
        : remote.surveys);
    final localTombs = _tombsByIdFor(kind, local.tombstones);
    final remoteTombs = _tombsByIdFor(kind, remote.tombstones);

    final ids = <String>{
      ...localEntries.keys,
      ...remoteEntries.keys,
      ...localTombs.keys,
      ...remoteTombs.keys,
    };

    // An entry that exists without updatedAt (legacy row) still counts as
    // present — as epoch, so any stamped edit or deletion beats it.
    DateTime? presentAt(ManifestEntry? e) =>
        e == null ? null : (e.updatedAt ?? syncEpoch);

    final outgoingTombstones = <Tombstone>[];
    for (final id in ids) {
      final action = decideMerge(
        localUpdated: presentAt(localEntries[id]),
        remoteUpdated: presentAt(remoteEntries[id]),
        localDeleted: localTombs[id]?.deletedAt,
        remoteDeleted: remoteTombs[id]?.deletedAt,
      );
      switch (action) {
        case MergeAction.none:
          break;
        case MergeAction.pullObject:
          progress?.call('拉取 $id…');
          if (await _pull(kind, id, remote, transport, report)) {
            kind == Tombstone.kindTemplate
                ? report.pulledTemplates++
                : report.pulledSurveys++;
          }
        case MergeAction.pushObject:
          progress?.call('推送 $id…');
          if (await _push(kind, id, remote, transport, report)) {
            kind == Tombstone.kindTemplate
                ? report.pushedTemplates++
                : report.pushedSurveys++;
          }
        case MergeAction.deleteLocal:
          final tomb = remoteTombs[id]!;
          kind == Tombstone.kindTemplate
              ? await templates.delete(id)
              : await surveys.delete(id);
          // delete() stamped "now"; adopt the peer's original deletion time.
          await meta.addTombstone(tomb);
          report.deletedLocal++;
        case MergeAction.deleteRemote:
          outgoingTombstones.add(localTombs[id]!);
          report.deletedRemote++;
      }
    }
    if (outgoingTombstones.isNotEmpty) {
      await transport.pushTombstones(outgoingTombstones);
    }
  }

  /// Fetch one object (files first for surveys); false if the peer no longer
  /// has it (deleted between manifest and fetch — next pass reconciles).
  Future<bool> _pull(String kind, String id, SyncManifest remote,
      SyncTransport transport, SyncReport report) async {
    if (kind == Tombstone.kindTemplate) {
      final json = await transport.fetchTemplate(id);
      if (json == null) return false;
      await templates.upsert(Template.fromJson(json));
      return true;
    }
    final json = await transport.fetchSurvey(id);
    if (json == null) return false;
    final survey = Survey.fromJson(json);
    final have = await files.list();
    for (final name in referencedFileNames(survey.data)) {
      if (have.contains(name) || !remote.files.contains(name)) continue;
      final bytes = await transport.fetchFile(name);
      if (bytes == null) continue; // vanished remotely; skip, don't fail sync
      await files.write(name, bytes);
      report.filesPulled++;
    }
    await surveys.upsert(survey);
    return true;
  }

  /// Push one object (files first for surveys); false if the peer refused
  /// (its copy turned out newer).
  Future<bool> _push(String kind, String id, SyncManifest remote,
      SyncTransport transport, SyncReport report) async {
    if (kind == Tombstone.kindTemplate) {
      final t = await templates.get(id);
      if (t == null) return false;
      return transport.pushTemplate(t.toJson());
    }
    final s = await surveys.get(id);
    if (s == null) return false;
    for (final name in referencedFileNames(s.data)) {
      if (remote.files.contains(name)) continue;
      final bytes = await files.read(name);
      if (bytes == null) continue; // locally missing (legacy orphan); skip
      await transport.pushFile(name, bytes);
      report.filesPushed++;
    }
    return transport.pushSurvey(s.toJson());
  }

  static Map<String, ManifestEntry> _byId(List<ManifestEntry> entries) =>
      {for (final e in entries) e.id: e};

  static Map<String, Tombstone> _tombsByIdFor(
          String kind, List<Tombstone> tombstones) =>
      {for (final t in tombstones.where((t) => t.kind == kind)) t.id: t};
}
