import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/data/survey_store.dart';
import 'package:scss_grid/data/sync_meta_store.dart';
import 'package:scss_grid/data/template_store.dart';
import 'package:scss_grid/l10n/app_localizations.dart';
import 'package:scss_grid/sync/media_file_store.dart';
import 'package:scss_grid/sync/sync_client_screen.dart';
import 'package:scss_grid/sync/sync_engine.dart';

Widget app(InMemorySyncMetaStore meta, {SyncRunner? runner}) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SyncClientScreen(
        templates: InMemoryTemplateStore(meta: meta),
        surveys: InMemorySurveyStore(meta: meta),
        meta: meta,
        files: InMemoryMediaFileStore(),
        runnerOverride: runner,
      ),
    );

void main() {
  testWidgets('successful sync shows the summary and remembers the pairing',
      (tester) async {
    final meta = InMemorySyncMetaStore();
    String? seenHost;
    int? seenPort;
    String? seenToken;
    await tester.pumpWidget(app(meta, runner: (host, port, token, _) async {
      seenHost = host;
      seenPort = port;
      seenToken = token;
      return SyncReport()
        ..pulledTemplates = 1
        ..pushedSurveys = 2
        ..filesPushed = 3;
    }));

    await tester.enterText(
        find.byKey(const ValueKey('sync-host-field')), '192.168.1.5');
    await tester.enterText(
        find.byKey(const ValueKey('sync-token-field')), '123456');
    await tester.tap(find.byKey(const ValueKey('sync-start')));
    await tester.pumpAndSettle();

    expect(seenHost, '192.168.1.5');
    expect(seenPort, 17423);
    expect(seenToken, '123456');
    expect(find.textContaining('1 template(s) pulled'), findsOneWidget);
    expect(find.textContaining('2 survey(s) pushed'), findsOneWidget);
    expect(find.textContaining('3 image(s) transferred'), findsOneWidget);
    expect(await meta.kvGet('sync.lastHost'), '192.168.1.5');
    expect(await meta.kvGet('sync.lastToken'), '123456');
  });

  testWidgets('host with explicit port is honored', (tester) async {
    final meta = InMemorySyncMetaStore();
    int? seenPort;
    await tester.pumpWidget(app(meta, runner: (host, port, token, _) async {
      seenPort = port;
      return SyncReport();
    }));

    await tester.enterText(
        find.byKey(const ValueKey('sync-host-field')), '10.0.0.2:9000');
    await tester.enterText(
        find.byKey(const ValueKey('sync-token-field')), '000000');
    await tester.tap(find.byKey(const ValueKey('sync-start')));
    await tester.pumpAndSettle();

    expect(seenPort, 9000);
    expect(find.textContaining('Already up to date'), findsOneWidget);
  });

  testWidgets('failure shows the error and keeps nothing saved',
      (tester) async {
    final meta = InMemorySyncMetaStore();
    await tester.pumpWidget(app(meta, runner: (host, port, token, _) async {
      throw SyncException('Wrong pairing code');
    }));

    await tester.enterText(
        find.byKey(const ValueKey('sync-host-field')), '192.168.1.5');
    await tester.enterText(
        find.byKey(const ValueKey('sync-token-field')), '999999');
    await tester.tap(find.byKey(const ValueKey('sync-start')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Sync failed'), findsOneWidget);
    expect(find.textContaining('Wrong pairing code'), findsOneWidget);
    expect(await meta.kvGet('sync.lastHost'), isNull);
  });

  testWidgets('saved pairing pre-fills the fields', (tester) async {
    final meta = InMemorySyncMetaStore();
    await meta.kvSet('sync.lastHost', '192.168.9.9');
    await meta.kvSet('sync.lastToken', '424242');

    await tester.pumpWidget(app(meta));
    await tester.pumpAndSettle();

    expect(find.text('192.168.9.9'), findsOneWidget);
    expect(find.text('424242'), findsOneWidget);
  });

  testWidgets('empty fields are rejected before any network use',
      (tester) async {
    final meta = InMemorySyncMetaStore();
    var ran = false;
    await tester.pumpWidget(app(meta, runner: (h, p, t, _) async {
      ran = true;
      return SyncReport();
    }));

    await tester.tap(find.byKey(const ValueKey('sync-start')));
    await tester.pumpAndSettle();

    expect(ran, isFalse);
    expect(find.textContaining('Enter the computer address'), findsOneWidget);
  });
}
