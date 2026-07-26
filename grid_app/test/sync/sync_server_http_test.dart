import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/data/survey_store.dart';
import 'package:scss_grid/data/sync_meta_store.dart';
import 'package:scss_grid/data/template_store.dart';
import 'package:scss_grid/model/survey.dart';
import 'package:scss_grid/sample/sample_template.dart';
import 'package:scss_grid/sync/http_transport.dart';
import 'package:scss_grid/sync/media_file_store.dart';
import 'package:scss_grid/sync/sync_endpoint.dart';
import 'package:scss_grid/sync/sync_engine.dart';
import 'package:scss_grid/sync/sync_server.dart';

/// Full wire round-trip on 127.0.0.1: phone-side engine + HttpSyncTransport
/// against the real shelf server, covering HTTP encode/decode end to end.
void main() {
  late InMemorySyncMetaStore serverMeta;
  late InMemoryTemplateStore serverTemplates;
  late InMemorySurveyStore serverSurveys;
  late InMemoryMediaFileStore serverFiles;
  late SyncServer server;
  late int port;

  setUp(() async {
    serverMeta = InMemorySyncMetaStore();
    serverTemplates = InMemoryTemplateStore(meta: serverMeta);
    serverSurveys = InMemorySurveyStore(meta: serverMeta);
    serverFiles = InMemoryMediaFileStore();
    server = SyncServer(
      endpoint: SyncEndpoint(
        templates: serverTemplates,
        surveys: serverSurveys,
        meta: serverMeta,
        files: serverFiles,
        deviceName: 'desktop-test',
      ),
      token: '123456',
    );
    port = await server.start(port: 0); // OS-assigned free port
  });

  tearDown(() => server.stop());

  HttpSyncTransport transport({String token = '123456'}) => HttpSyncTransport(
      base: Uri.parse('http://127.0.0.1:$port'), token: token);

  test('ping returns server identity; wrong token is rejected', () async {
    final t = transport();
    final info = await t.ping();
    expect(info['app'], 'scss_grid');
    expect(info['deviceName'], 'desktop-test');

    final bad = transport(token: 'nope');
    await expectLater(
        bad.ping(), throwsA(isA<SyncException>()));
    t.close();
    bad.close();
  });

  test('full sync pass over real HTTP moves objects and files both ways',
      () async {
    // Server (desktop) has a template; client (phone) has a survey + photo.
    final at = DateTime(2026, 7, 1);
    await serverTemplates
        .upsert(sampleTemplate().copyWith(id: 'tpl_1', updatedAt: at));

    final clientMeta = InMemorySyncMetaStore();
    final clientTemplates = InMemoryTemplateStore(meta: clientMeta);
    final clientSurveys = InMemorySurveyStore(meta: clientMeta);
    final clientFiles = InMemoryMediaFileStore();
    final photo = Uint8List.fromList(List.generate(1000, (i) => i % 256));
    await clientFiles.write('a.jpg', photo);
    await clientSurveys.upsert(Survey(
      id: 'srv_1',
      templateId: 'tpl_1',
      name: 'S',
      updatedAt: at,
      data: const {'photo': 'a.jpg'},
    ));

    final engine = SyncEngine(
      templates: clientTemplates,
      surveys: clientSurveys,
      meta: clientMeta,
      files: clientFiles,
    );
    final t = transport();
    final report = await engine.run(t);
    t.close();

    expect(report.pulledTemplates, 1);
    expect(report.pushedSurveys, 1);
    expect(report.filesPushed, 1);
    expect(await clientTemplates.get('tpl_1'), isNotNull);
    expect((await serverSurveys.get('srv_1'))?.data['photo'], 'a.jpg');
    expect(await serverFiles.read('a.jpg'), photo);
  });

  test('path traversal in file names is rejected', () async {
    final t = transport();
    await expectLater(
      t.pushFile('..%2Fevil.jpg', Uint8List.fromList(const [1])),
      throwsA(isA<SyncException>()),
    );
    t.close();
  });

  test('stale PUT is refused with 409 → pushTemplate returns false', () async {
    final newer = DateTime(2026, 7, 2);
    final older = DateTime(2026, 7, 1);
    await serverTemplates
        .upsert(sampleTemplate().copyWith(id: 'tpl_1', updatedAt: newer));

    final t = transport();
    final accepted = await t.pushTemplate(
        sampleTemplate().copyWith(id: 'tpl_1', updatedAt: older).toJson());
    expect(accepted, isFalse);
    expect((await serverTemplates.get('tpl_1'))?.updatedAt, newer);
    t.close();
  });
}
