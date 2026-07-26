import 'package:flutter/material.dart';

import 'controls/default_controls.dart';
import 'controls/registry.dart';
import 'data/app_database.dart';
import 'data/survey_store.dart';
import 'data/sync_meta_store.dart';
import 'data/template_store.dart';
import 'builder/template_list_screen.dart';
import 'l10n/app_localizations.dart';
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
  final meta = DriftSyncMetaStore(db);
  final savedLocale = await meta.kvGet('app.locale');
  runApp(ScssGridApp(
    store: DriftTemplateStore(db),
    surveyStore: DriftSurveyStore(db),
    meta: meta,
    files: DiskMediaFileStore(),
    registry: buildDefaultRegistry(
      location: GeolocatorLocationService(),
      image: ImagePickerImageService(),
    ),
    initialLocaleCode:
        (savedLocale == null || savedLocale.isEmpty) ? null : savedLocale,
  ));
}

class ScssGridApp extends StatefulWidget {
  final TemplateStore store;
  final SurveyStore surveyStore;
  final SyncMetaStore meta;
  final MediaFileStore files;
  final ControlRegistry registry;

  /// 'en' / 'zh', or null to follow the system locale.
  final String? initialLocaleCode;

  const ScssGridApp({
    super.key,
    required this.store,
    required this.surveyStore,
    required this.meta,
    required this.files,
    required this.registry,
    this.initialLocaleCode,
  });

  @override
  State<ScssGridApp> createState() => _ScssGridAppState();
}

class _ScssGridAppState extends State<ScssGridApp> {
  late Locale? _locale = widget.initialLocaleCode == null
      ? null
      : Locale(widget.initialLocaleCode!);

  void _setLocale(String? code) {
    setState(() => _locale = code == null ? null : Locale(code));
    widget.meta.kvSet('app.locale', code ?? '');
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'SCSS Survey',
        theme: ThemeData(useMaterial3: true),
        locale: _locale, // null → system
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // Both ends share one hierarchy: templates → that template's
        // surveys → fill. Only the sync entry differs (desktop hosts, the
        // phone connects) — TemplateListScreen picks by platform.
        home: TemplateListScreen(
          store: widget.store,
          surveyStore: widget.surveyStore,
          registry: widget.registry,
          meta: widget.meta,
          files: widget.files,
          onSetLocale: _setLocale,
        ),
      );
}
