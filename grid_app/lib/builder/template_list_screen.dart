import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

import '../controls/registry.dart';
import '../data/survey_store.dart';
import '../data/sync_meta_store.dart';
import '../data/template_store.dart';
import '../export/pdf_exporter.dart';
import '../fill/survey_list_screen.dart';
import '../fill/survey_name_dialog.dart';
import '../fill/template_surveys_screen.dart';
import '../l10n/app_localizations.dart';
import '../model/ids.dart';
import '../model/template.dart';
import '../sample/sample_template.dart';
import '../services/platform_info.dart';
import '../sync/media_file_store.dart';
import '../sync/sync_client_screen.dart';
import '../sync/sync_host_screen.dart';
import '../widgets/list_icons.dart';
import 'builder_screen.dart';

/// The design side's list (home screen on desktop): tapping a template opens
/// its surveys (fill side); the row's trailing buttons rename it, open the
/// designer, or delete it. On desktop the AppBar also hosts the sync server
/// screen.
class TemplateListScreen extends StatefulWidget {
  final TemplateStore store;
  final SurveyStore surveyStore;
  final ControlRegistry registry;

  /// Sync wiring; when either is null the sync entry is hidden (tests, or a
  /// context that offers sync elsewhere).
  final SyncMetaStore? meta;
  final MediaFileStore? files;

  /// Change the app language ('en' / 'zh' / null = follow system); null
  /// hides the language menu (tests).
  final void Function(String? code)? onSetLocale;

  const TemplateListScreen({
    super.key,
    required this.store,
    required this.surveyStore,
    required this.registry,
    this.meta,
    this.files,
    this.onSetLocale,
  });

  @override
  State<TemplateListScreen> createState() => _TemplateListScreenState();
}

class _TemplateListScreenState extends State<TemplateListScreen> {
  List<Template> _templates = [];
  Map<String, int> _surveyCounts = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final list = await widget.store.all();
    final surveys = await widget.surveyStore.all();
    if (!mounted) return;
    setState(() {
      _templates = list;
      _surveyCounts = {};
      for (final s in surveys) {
        _surveyCounts[s.templateId] = (_surveyCounts[s.templateId] ?? 0) + 1;
      }
      _loading = false;
    });
  }

  Future<void> _create() async {
    final t = sampleTemplate().copyWith(
      id: newTemplateId(),
      name: 'New Template',
      updatedAt: DateTime.now(),
    );
    await widget.store.upsert(t);
    if (!mounted) return;
    await _open(t);
  }

  Future<void> _open(Template t) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BuilderScreen(
          template: t, registry: widget.registry, store: widget.store),
    ));
    await _reload();
  }

  /// Row tap: into this template's surveys (the fill side).
  Future<void> _openSurveysOf(Template t) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => TemplateSurveysScreen(
        template: t,
        surveyStore: widget.surveyStore,
        registry: widget.registry,
      ),
    ));
    if (!mounted) return;
    await _reload();
  }

  Future<void> _openSurveys() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SurveyListScreen(
        surveyStore: widget.surveyStore,
        templateStore: widget.store,
        registry: widget.registry,
      ),
    ));
    await _reload();
  }

  Future<void> _openSync() async {
    final meta = widget.meta;
    final files = widget.files;
    if (meta == null || files == null) return;
    await Navigator.of(context).push(MaterialPageRoute(
      // Desktop hosts the sync server; the phone connects to it.
      builder: (_) => isDesktopPlatform
          ? SyncHostScreen(
              templates: widget.store,
              surveys: widget.surveyStore,
              meta: meta,
              files: files,
            )
          : SyncClientScreen(
              templates: widget.store,
              surveys: widget.surveyStore,
              meta: meta,
              files: files,
            ),
    ));
    await _reload();
  }

  Future<void> _rename(Template t) async {
    final name = await promptForSurveyName(context,
        title: AppLocalizations.of(context)!.renameTemplate, initial: t.name);
    if (name == null || !mounted) return;
    // Re-read: the list snapshot can lag a just-closed BuilderScreen's save;
    // renaming the stale copy would clobber that edit. Mirrors survey rename.
    final latest = await widget.store.get(t.id) ?? t;
    await widget.store
        .upsert(latest.copyWith(name: name, updatedAt: DateTime.now()));
    if (!mounted) return;
    await _reload();
  }

  Future<void> _delete(Template t) async {
    await widget.store.delete(t.id);
    if (!mounted) return;
    await _reload();
  }

  Future<void> _confirmDelete(Template t) async {
    final l10n = AppLocalizations.of(context)!;
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.confirmDeleteTitle(t.name)),
        content: Text(l10n.surveysAreKept),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.delete)),
        ],
      ),
    );
    if (yes == true) await _delete(t);
  }

  bool get _hasSync => widget.meta != null && widget.files != null;

  // ---- batch PDF export (desktop) ----

  static String _defaultExportDir() {
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '';
    return path.join(home, 'Desktop');
  }

  /// Confirm/adjust the target directory, run the incremental export with a
  /// progress dialog, retry once via the directory picker when the sandbox
  /// refuses the path, and report what was written vs skipped.
  Future<void> _exportPdfs({String? onlyTemplateId}) async {
    final l10n = AppLocalizations.of(context)!;
    var dir =
        (await widget.meta?.kvGet('export.dir')) ?? _defaultExportDir();
    if (!mounted) return;
    final confirmed = await _confirmExportDir(dir, onlyTemplateId);
    if (confirmed == null || !mounted) return;
    dir = confirmed;
    await widget.meta?.kvSet('export.dir', dir);
    if (!mounted) return;

    final exporter = PdfExporter(
      templates: widget.store,
      surveys: widget.surveyStore,
      registry: widget.registry,
    );
    final progress = ValueNotifier<(int, int)>((0, 0));
    var progressOpen = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: ValueListenableBuilder<(int, int)>(
          valueListenable: progress,
          builder: (_, v, __) => Row(children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Text(v.$2 == 0
                ? l10n.preparing
                : l10n.exportingProgress(v.$1, v.$2)),
          ]),
        ),
      ),
    ).whenComplete(() => progressOpen = false);

    void closeProgress() {
      if (progressOpen && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }

    ExportReport report;
    try {
      report = await exporter.export(
        rootDir: dir,
        onlyTemplateId: onlyTemplateId,
        onProgress: (d, t) => progress.value = (d, t),
      );
    } on FileSystemException {
      // Sandbox refused the directory — picking it in the dialog grants
      // access for this session.
      closeProgress();
      if (!mounted) return;
      final picked = await getDirectoryPath(
          initialDirectory: dir, confirmButtonText: l10n.chooseExportDirectory);
      if (picked == null || !mounted) return;
      await widget.meta?.kvSet('export.dir', picked);
      if (!mounted) return;
      progressOpen = true;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
            content: Row(children: [
          const CircularProgressIndicator(),
          const SizedBox(width: 16),
          Text(l10n.exporting),
        ])),
      ).whenComplete(() => progressOpen = false);
      try {
        report = await exporter.export(
          rootDir: picked,
          onlyTemplateId: onlyTemplateId,
          onProgress: (d, t) => progress.value = (d, t),
        );
      } on FileSystemException catch (e) {
        closeProgress();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.exportDirUnwritable('$e'))));
        }
        return;
      }
    }
    closeProgress();
    if (!mounted) return;
    final msg = l10n.exportResult(report.written, report.skipped) +
        (report.errors.isNotEmpty
            ? l10n.exportErrors(report.errors.length)
            : '');
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<String?> _confirmExportDir(String initial, String? onlyTemplateId) {
    final l10n = AppLocalizations.of(context)!;
    var dir = initial;
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(
              onlyTemplateId == null ? l10n.exportAllPdf : l10n.exportTemplatePdf),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.exportTo),
              SelectableText(dir,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
              TextButton.icon(
                key: const ValueKey('export-change-dir'),
                icon: const Icon(Icons.folder_open, size: 18),
                label: Text(l10n.changeDirectory),
                onPressed: () async {
                  final picked = await getDirectoryPath(initialDirectory: dir);
                  if (picked != null) setDialogState(() => dir = picked);
                },
              ),
              const SizedBox(height: 4),
              Text(l10n.exportHint,
                  style: Theme.of(ctx).textTheme.bodySmall),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.cancel)),
            FilledButton(
                key: const ValueKey('export-start'),
                onPressed: () => Navigator.pop(ctx, dir),
                child: Text(l10n.export)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.templatesTitle),
        actions: [
          if (isDesktopPlatform)
            IconButton(
              key: const ValueKey('export-all-pdf'),
              icon: const Icon(Icons.save_alt),
              tooltip: l10n.exportAllPdf,
              onPressed: () => _exportPdfs(),
            ),
          if (_hasSync)
            IconButton(
              key: const ValueKey('open-sync'),
              icon: const Icon(Icons.sync),
              tooltip: l10n.sync,
              onPressed: _openSync,
            ),
          IconButton(
            icon: const Icon(Icons.assignment_outlined),
            tooltip: l10n.surveysTooltip,
            onPressed: _openSurveys,
          ),
          if (widget.onSetLocale != null)
            PopupMenuButton<String>(
              key: const ValueKey('language-menu'),
              icon: const Icon(Icons.translate),
              tooltip: '语言 / Language',
              onSelected: (v) =>
                  widget.onSetLocale!(v == 'system' ? null : v),
              itemBuilder: (ctx) => const [
                PopupMenuItem(
                    value: 'system', child: Text('跟随系统 / System')),
                PopupMenuItem(value: 'zh', child: Text('中文')),
                PopupMenuItem(value: 'en', child: Text('English')),
              ],
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _templates.isEmpty
              ? Center(child: Text(l10n.noTemplatesYet))
              : ListView(
                  children: [
                    for (final t in _templates)
                      ListTile(
                        key: ValueKey(t.id),
                        leading: templateListIcon(context),
                        title: Text(t.name),
                        subtitle: Text(l10n.templateSubtitle(
                            t.pages.length, _surveyCounts[t.id] ?? 0)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              key: ValueKey('rename-${t.id}'),
                              icon: const Icon(Icons.edit_outlined),
                              tooltip: l10n.rename,
                              onPressed: () => _rename(t),
                            ),
                            IconButton(
                              key: ValueKey('design-${t.id}'),
                              icon: const Icon(Icons.design_services_outlined),
                              tooltip: l10n.editDesign,
                              onPressed: () => _open(t),
                            ),
                            if (isDesktopPlatform)
                              IconButton(
                                key: ValueKey('export-${t.id}'),
                                icon: const Icon(Icons.save_alt),
                                tooltip: l10n.exportTemplatePdf,
                                onPressed: () =>
                                    _exportPdfs(onlyTemplateId: t.id),
                              ),
                            IconButton(
                              key: ValueKey('delete-${t.id}'),
                              icon: const Icon(Icons.delete_outline),
                              tooltip: l10n.delete,
                              onPressed: () => _confirmDelete(t),
                            ),
                          ],
                        ),
                        // The row itself is the fill side: this template's
                        // surveys, with the new-survey entry inside.
                        onTap: () => _openSurveysOf(t),
                      ),
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _create,
        tooltip: l10n.newTemplate,
        child: const Icon(Icons.add),
      ),
    );
  }
}
