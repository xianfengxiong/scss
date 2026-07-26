import 'package:flutter/material.dart';

import '../controls/registry.dart';
import '../data/survey_store.dart';
import '../data/sync_meta_store.dart';
import '../data/template_store.dart';
import '../fill/survey_list_screen.dart';
import '../fill/survey_name_dialog.dart';
import '../fill/template_surveys_screen.dart';
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

  const TemplateListScreen({
    super.key,
    required this.store,
    required this.surveyStore,
    required this.registry,
    this.meta,
    this.files,
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
        title: 'Rename template', initial: t.name);
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
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${t.name}"?'),
        content: const Text('Surveys filled from it are kept.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (yes == true) await _delete(t);
  }

  bool get _hasSync => widget.meta != null && widget.files != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SCSS Templates'),
        actions: [
          if (_hasSync)
            IconButton(
              key: const ValueKey('open-sync'),
              icon: const Icon(Icons.sync),
              tooltip: '同步',
              onPressed: _openSync,
            ),
          IconButton(
            icon: const Icon(Icons.assignment_outlined),
            tooltip: 'Surveys',
            onPressed: _openSurveys,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _templates.isEmpty
              ? const Center(child: Text('No templates yet. Tap + to create one.'))
              : ListView(
                  children: [
                    for (final t in _templates)
                      ListTile(
                        key: ValueKey(t.id),
                        leading: templateListIcon(context),
                        title: Text(t.name),
                        subtitle: Text(
                            '${t.pages.length} page(s) · ${t.allCells.length} cells · '
                            '${_surveyCounts[t.id] ?? 0} 份调查表'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              key: ValueKey('rename-${t.id}'),
                              icon: const Icon(Icons.edit_outlined),
                              tooltip: 'Rename',
                              onPressed: () => _rename(t),
                            ),
                            IconButton(
                              key: ValueKey('design-${t.id}'),
                              icon: const Icon(Icons.design_services_outlined),
                              tooltip: 'Edit design',
                              onPressed: () => _open(t),
                            ),
                            IconButton(
                              key: ValueKey('delete-${t.id}'),
                              icon: const Icon(Icons.delete_outline),
                              tooltip: 'Delete',
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
        tooltip: 'New template',
        child: const Icon(Icons.add),
      ),
    );
  }
}
