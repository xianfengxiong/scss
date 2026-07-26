import 'package:flutter/material.dart';

import 'controls/default_controls.dart';
import 'controls/registry.dart';
import 'data/app_database.dart';
import 'data/survey_store.dart';
import 'data/sync_meta_store.dart';
import 'data/template_store.dart';
import 'builder/template_list_screen.dart';
import 'services/image_service.dart';
import 'services/location_service.dart';
import 'services/media_paths.dart';
import 'sync/media_file_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Survey images resolve against this directory; must be ready before any
  // control widget builds.
  await MediaPaths.init();
  final db = AppDatabase.open();
  runApp(ScssGridApp(
    store: DriftTemplateStore(db),
    surveyStore: DriftSurveyStore(db),
    meta: DriftSyncMetaStore(db),
    files: DiskMediaFileStore(),
    registry: buildDefaultRegistry(
      location: GeolocatorLocationService(),
      image: ImagePickerImageService(),
    ),
  ));
}

class ScssGridApp extends StatelessWidget {
  final TemplateStore store;
  final SurveyStore surveyStore;
  final SyncMetaStore meta;
  final MediaFileStore files;
  final ControlRegistry registry;

  const ScssGridApp({
    super.key,
    required this.store,
    required this.surveyStore,
    required this.meta,
    required this.files,
    required this.registry,
  });

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'SCSS Survey',
        theme: ThemeData(useMaterial3: true),
        // Both ends share one hierarchy: templates → that template's
        // surveys → fill. Only the sync entry differs (desktop hosts, the
        // phone connects) — TemplateListScreen picks by platform.
        home: TemplateListScreen(
          store: store,
          surveyStore: surveyStore,
          registry: registry,
          meta: meta,
          files: files,
        ),
      );
}
