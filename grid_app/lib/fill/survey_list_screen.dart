import 'package:flutter/material.dart';

import '../builder/template_list_screen.dart';
import '../controls/registry.dart';
import '../data/survey_store.dart';
import '../data/sync_meta_store.dart';
import '../data/template_store.dart';
import '../model/survey.dart';
import '../model/template.dart';
import '../services/platform_info.dart';
import '../sync/media_file_store.dart';
import '../sync/sync_client_screen.dart';
import '../sync/sync_host_screen.dart';
import 'fill_screen.dart';
import 'survey_actions.dart';
import 'survey_name_dialog.dart';
import 'time_label.dart';

/// Lists saved surveys: resume one (loads its template, opens FillScreen),
/// rename, or delete (swipe on phone, button on desktop).
///
/// As the phone's home screen ([asHome]) it also carries the survey-first
/// workflow: a FAB that starts a new survey from a synced template, plus
/// AppBar entries for sync (the primary phone action) and the template
/// designer (kept, but secondary — designing happens on the desktop).
class SurveyListScreen extends StatefulWidget {
  final SurveyStore surveyStore;
  final TemplateStore templateStore;
  final ControlRegistry registry;

  /// Home-screen mode: FAB + templates entry.
  final bool asHome;

  /// Sync wiring; when either is null the sync entry is hidden.
  final SyncMetaStore? meta;
  final MediaFileStore? files;

  const SurveyListScreen({
    super.key,
    required this.surveyStore,
    required this.templateStore,
    required this.registry,
    this.asHome = false,
    this.meta,
    this.files,
  });

  @override
  State<SurveyListScreen> createState() => _SurveyListScreenState();
}

class _SurveyListScreenState extends State<SurveyListScreen> {
  List<Survey> _surveys = [];
  Map<String, String> _tplNames = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final list = await widget.surveyStore.all();
    final templates = await widget.templateStore.all();
    if (!mounted) return;
    setState(() {
      _surveys = list;
      _tplNames = {for (final Template t in templates) t.id: t.name};
      _loading = false;
    });
  }

  Future<void> _resume(Survey s) async {
    final template = await widget.templateStore.get(s.templateId);
    if (!mounted) return;
    if (template == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Template not found for this survey.')));
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => FillScreen(
        template: template,
        survey: s,
        store: widget.surveyStore,
        registry: widget.registry,
      ),
    ));
    if (!mounted) return;
    await _reload();
  }

  Future<void> _delete(Survey s) async {
    await widget.surveyStore.delete(s.id);
    if (!mounted) return;
    await _reload();
  }

  Future<void> _confirmDelete(Survey s) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${s.name}"?'),
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
    if (yes == true) await _delete(s);
  }

  Future<void> _rename(Survey s) async {
    final name = await promptForSurveyName(context,
        title: 'Rename survey', initial: s.name);
    if (name == null || !mounted) return;
    // Re-read: the list snapshot can lag a just-disposed FillScreen's
    // autosave flush; renaming the stale copy would clobber that edit.
    final latest = await widget.surveyStore.get(s.id) ?? s;
    await widget.surveyStore
        .upsert(latest.copyWith(name: name, updatedAt: DateTime.now()));
    if (!mounted) return;
    await _reload();
  }

  /// FAB flow: pick a template, then the shared name→fill flow.
  Future<void> _newSurvey() async {
    final templates = await widget.templateStore.all();
    if (!mounted) return;
    if (templates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('还没有模版——先在电脑端设计并同步过来,或到「模版」页新建。')));
      return;
    }
    Template? picked;
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('选择模版', style: TextStyle(fontWeight: FontWeight.bold))),
            const Divider(height: 1),
            for (final t in templates)
              ListTile(
                key: ValueKey('pick-template-${t.id}'),
                title: Text(t.name),
                subtitle: Text('${t.grid.cols}×${t.grid.rows} · ${t.cells.length} cells'),
                onTap: () {
                  picked = t;
                  Navigator.of(sheetCtx).pop();
                },
              ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    await createAndOpenSurvey(context,
        template: picked!,
        surveyStore: widget.surveyStore,
        registry: widget.registry);
    if (!mounted) return;
    await _reload();
  }

  Future<void> _openTemplates() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => TemplateListScreen(
        store: widget.templateStore,
        surveyStore: widget.surveyStore,
        registry: widget.registry,
        meta: widget.meta,
        files: widget.files,
      ),
    ));
    await _reload();
  }

  Future<void> _openSync() async {
    final meta = widget.meta;
    final files = widget.files;
    if (meta == null || files == null) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => isDesktopPlatform
          // Desktop reaches this list too; sync there means hosting.
          ? SyncHostScreen(
              templates: widget.templateStore,
              surveys: widget.surveyStore,
              meta: meta,
              files: files,
            )
          : SyncClientScreen(
              templates: widget.templateStore,
              surveys: widget.surveyStore,
              meta: meta,
              files: files,
            ),
    ));
    await _reload();
  }

  bool get _hasSync => widget.meta != null && widget.files != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.asHome ? 'SCSS Surveys' : 'Surveys'),
        actions: [
          if (_hasSync)
            IconButton(
              key: const ValueKey('open-sync-client'),
              icon: const Icon(Icons.sync),
              tooltip: '同步',
              onPressed: _openSync,
            ),
          if (widget.asHome)
            IconButton(
              key: const ValueKey('open-templates'),
              icon: const Icon(Icons.grid_view_outlined),
              tooltip: 'Templates',
              onPressed: _openTemplates,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _surveys.isEmpty
              ? Center(
                  child: Text(widget.asHome
                      ? '还没有调查表。点 + 从模版新建,或先「同步」拉取电脑端的模版。'
                      : 'No surveys yet. Fill a template to start one.'))
              : ListView(
                  children: [
                    for (final s in _surveys)
                      Dismissible(
                        key: ValueKey(s.id),
                        direction: isDesktopPlatform
                            ? DismissDirection.none
                            : DismissDirection.endToStart,
                        background: const SizedBox.shrink(),
                        secondaryBackground: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 16),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) => _delete(s),
                        child: ListTile(
                          title: Text(s.name),
                          subtitle: Text(
                              '${_tplNames[s.templateId] ?? s.templateId} · '
                              '${updatedLabel(s.updatedAt, DateTime.now())} · '
                              '${s.data.length} fields'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                key: ValueKey('rename-${s.id}'),
                                icon: const Icon(Icons.edit_outlined),
                                tooltip: 'Rename',
                                onPressed: () => _rename(s),
                              ),
                              if (isDesktopPlatform)
                                IconButton(
                                  key: ValueKey('delete-${s.id}'),
                                  icon: const Icon(Icons.delete_outline),
                                  tooltip: 'Delete',
                                  onPressed: () => _confirmDelete(s),
                                ),
                            ],
                          ),
                          onTap: () => _resume(s),
                        ),
                      ),
                  ],
                ),
      floatingActionButton: widget.asHome
          ? FloatingActionButton(
              key: const ValueKey('new-survey-fab'),
              onPressed: _newSurvey,
              tooltip: 'New survey',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
