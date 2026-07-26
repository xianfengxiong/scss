import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/data/survey_store.dart';
import 'package:scss_grid/data/sync_meta_store.dart';
import 'package:scss_grid/data/template_store.dart';
import 'package:scss_grid/sync/media_file_store.dart';
import 'package:scss_grid/sync/sync_host_screen.dart';

void main() {
  testWidgets('shows a six-digit pairing code and running state',
      (tester) async {
    await tester.runAsync(() async {
      final meta = InMemorySyncMetaStore();
      await tester.pumpWidget(MaterialApp(
        home: SyncHostScreen(
          templates: InMemoryTemplateStore(meta: meta),
          surveys: InMemorySurveyStore(meta: meta),
          meta: meta,
          files: InMemoryMediaFileStore(),
          port: 0, // OS-assigned; never collides in tests
        ),
      ));
      // Real IO (bind + interface list) happens outside the fake clock; give
      // it a few real milliseconds, then rebuild.
      for (var i = 0; i < 40; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 25));
        await tester.pump();
        if (find.byKey(const ValueKey('sync-host-token')).evaluate().isNotEmpty) {
          break;
        }
      }

      final tokenText = tester
          .widget<SelectableText>(find.byKey(const ValueKey('sync-host-token')))
          .data;
      expect(tokenText, matches(RegExp(r'^\d{6}$')));
      expect(await meta.kvGet('sync.token'), tokenText);
      expect(find.textContaining('服务运行中'), findsOneWidget);

      // Dispose stops the server without complaint.
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    });
  });
}
