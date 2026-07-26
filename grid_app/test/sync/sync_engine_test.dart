import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/data/survey_store.dart';
import 'package:scss_grid/data/sync_meta_store.dart';
import 'package:scss_grid/data/template_store.dart';
import 'package:scss_grid/model/survey.dart';
import 'package:scss_grid/model/template.dart';
import 'package:scss_grid/model/tombstone.dart';
import 'package:scss_grid/sample/sample_template.dart';
import 'package:scss_grid/sync/media_file_store.dart';
import 'package:scss_grid/sync/protocol.dart';
import 'package:scss_grid/sync/sync_endpoint.dart';
import 'package:scss_grid/sync/sync_engine.dart';
import 'package:scss_grid/sync/transport.dart';

/// One simulated device: the full store stack plus its sync surfaces.
class Device {
  final InMemorySyncMetaStore meta;
  late final InMemoryTemplateStore templates;
  late final InMemorySurveyStore surveys;
  final InMemoryMediaFileStore files = InMemoryMediaFileStore();

  Device() : meta = InMemorySyncMetaStore() {
    templates = InMemoryTemplateStore(meta: meta);
    surveys = InMemorySurveyStore(meta: meta);
  }

  SyncEngine get engine => SyncEngine(
      templates: templates, surveys: surveys, meta: meta, files: files);

  SyncEndpoint get endpoint => SyncEndpoint(
        templates: templates,
        surveys: surveys,
        meta: meta,
        files: files,
        deviceName: 'test-peer',
      );
}

/// Phone-style sync: [client] drives a pass against [server]'s endpoint.
Future<SyncReport> sync(Device client, Device server) =>
    client.engine.run(InProcessTransport(server.endpoint));

Template tpl(String id, DateTime at, {String name = 'T'}) =>
    sampleTemplate().copyWith(id: id, name: name, updatedAt: at);

Survey srv(String id, DateTime at,
        {String templateId = 'tpl_1', Map<String, dynamic>? data}) =>
    Survey(
        id: id,
        templateId: templateId,
        name: 'S',
        updatedAt: at,
        data: data ?? const {});

void main() {
  final t1 = DateTime(2026, 7, 1);
  final t2 = DateTime(2026, 7, 2);
  final t3 = DateTime(2026, 7, 3);

  late Device desktop;
  late Device phone;

  setUp(() {
    desktop = Device();
    phone = Device();
  });

  test('desktop-designed template reaches the phone', () async {
    await desktop.templates.upsert(tpl('tpl_1', t1));

    final report = await sync(phone, desktop);

    expect(report.pulledTemplates, 1);
    expect((await phone.templates.get('tpl_1'))?.updatedAt, t1);
  });

  test('phone-filled survey (with images) reaches the desktop', () async {
    await desktop.templates.upsert(tpl('tpl_1', t1));
    await sync(phone, desktop);

    final photo = Uint8List.fromList(const [1, 2, 3]);
    await phone.files.write('a.jpg', photo);
    await phone.surveys
        .upsert(srv('srv_1', t2, data: {'photo': 'a.jpg', 'note': 'ok'}));

    final report = await sync(phone, desktop);

    expect(report.pushedSurveys, 1);
    expect(report.filesPushed, 1);
    expect((await desktop.surveys.get('srv_1'))?.data['photo'], 'a.jpg');
    expect(await desktop.files.read('a.jpg'), photo);
  });

  test('one pass moves both directions', () async {
    await desktop.templates.upsert(tpl('tpl_1', t1));
    await phone.surveys.upsert(srv('srv_1', t1));

    final report = await sync(phone, desktop);

    expect(report.pulledTemplates, 1);
    expect(report.pushedSurveys, 1);
    expect(await desktop.surveys.get('srv_1'), isNotNull);
    expect(await phone.templates.get('tpl_1'), isNotNull);
  });

  test('newer edit wins on both sides (LWW)', () async {
    await desktop.templates.upsert(tpl('tpl_1', t1, name: 'old'));
    await phone.templates.upsert(tpl('tpl_1', t2, name: 'new'));

    await sync(phone, desktop);

    expect((await desktop.templates.get('tpl_1'))?.name, 'new');
    expect((await phone.templates.get('tpl_1'))?.name, 'new');
  });

  test('desktop deletion propagates to the phone', () async {
    await desktop.templates.upsert(tpl('tpl_1', t1));
    await sync(phone, desktop);
    expect(await phone.templates.get('tpl_1'), isNotNull);

    await desktop.templates.delete('tpl_1');
    final report = await sync(phone, desktop);

    expect(report.deletedLocal, 1);
    expect(await phone.templates.get('tpl_1'), isNull);
  });

  test('phone deletion propagates to the desktop', () async {
    await phone.surveys.upsert(srv('srv_1', t1));
    await sync(phone, desktop);
    expect(await desktop.surveys.get('srv_1'), isNotNull);

    await phone.surveys.delete('srv_1');
    final report = await sync(phone, desktop);

    expect(report.deletedRemote, 1);
    expect(await desktop.surveys.get('srv_1'), isNull);
  });

  test('edit after deletion resurrects (edit is newer)', () async {
    await phone.surveys.upsert(srv('srv_1', t1));
    await sync(phone, desktop);

    // Desktop deletes at t2... but the phone edits later at t3.
    await desktop.surveys.delete('srv_1');
    await phone.surveys.upsert(srv('srv_1', t3, data: {'note': 'kept'}));

    // Deletion tombstones carry wall-clock "now"; stamp a controlled time so
    // the ordering under test (delete t2 < edit t3) is explicit.
    final tomb = (await desktop.meta.tombstones()).single;
    await desktop.meta
        .addTombstone(Tombstone(kind: tomb.kind, id: tomb.id, deletedAt: t2));

    await sync(phone, desktop);

    expect((await desktop.surveys.get('srv_1'))?.data['note'], 'kept');
    expect((await phone.surveys.get('srv_1'))?.data['note'], 'kept');
    expect(await desktop.meta.tombstones(), isEmpty);
  });

  test('second pass with no changes is a no-op', () async {
    await desktop.templates.upsert(tpl('tpl_1', t1));
    await phone.surveys.upsert(srv('srv_1', t1, data: {'p': 'a.jpg'}));
    await phone.files.write('a.jpg', Uint8List.fromList(const [1]));

    await sync(phone, desktop);
    final second = await sync(phone, desktop);

    expect(second.isEmpty, isTrue);
  });

  test('protocol version mismatch fails loudly', () async {
    final manifest = await desktop.endpoint.manifest();
    final stale = SyncManifest(
      protocolVersion: syncProtocolVersion + 1,
      deviceName: manifest.deviceName,
      templates: manifest.templates,
      surveys: manifest.surveys,
      tombstones: manifest.tombstones,
      files: manifest.files,
    );
    expect(
      () => phone.engine.run(_ManifestOverrideTransport(stale)),
      throwsA(isA<SyncException>()),
    );
  });

  test('files already on the peer are not re-sent', () async {
    final photo = Uint8List.fromList(const [9, 9]);
    await phone.files.write('a.jpg', photo);
    await desktop.files.write('a.jpg', photo);
    await phone.surveys.upsert(srv('srv_1', t1, data: {'p': 'a.jpg'}));

    final report = await sync(phone, desktop);

    expect(report.pushedSurveys, 1);
    expect(report.filesPushed, 0);
  });
}

/// Only fetchManifest is reachable when the version check trips.
class _ManifestOverrideTransport extends InProcessTransport {
  final SyncManifest _manifest;
  _ManifestOverrideTransport(this._manifest)
      : super(SyncEndpoint(
          templates: InMemoryTemplateStore(),
          surveys: InMemorySurveyStore(),
          meta: InMemorySyncMetaStore(),
          files: InMemoryMediaFileStore(),
          deviceName: 'stale',
        ));

  @override
  Future<SyncManifest> fetchManifest() async => _manifest;
}
