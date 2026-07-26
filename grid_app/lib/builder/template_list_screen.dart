import 'package:flutter/material.dart';

import '../controls/registry.dart';
import '../data/survey_store.dart';
import '../data/sync_meta_store.dart';
import '../data/template_store.dart';
import '../fill/survey_actions.dart';
import '../fill/survey_list_screen.dart';
import '../fill/survey_name_dialog.dart';
import '../model/ids.dart';
import '../model/template.dart';
import '../sample/sample_template.dart';
import '../services/platform_info.dart';
import '../sync/media_file_store.dart';
import '../sync/sync_host_screen.dart';
import 'builder_screen.dart';

/// The design side's list (home screen on desktop): create a template
/// (seeded from the sample layout), open one to edit, fill it, or delete.
/// On desktop the AppBar also hosts the sync server screen, and a visible
/// delete button replaces swipe-to-dismiss.
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
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final list = await widget.store.all();
    if (!mounted) return;
    setState(() {
      _templates = list;
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

  Future<void> _fill(Template t) async {
    await startSurveyForTemplate(context,
        template: t,
        surveyStore: widget.surveyStore,
        registry: widget.registry);
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
      builder: (_) => SyncHostScreen(
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
          if (_hasSync && isDesktopPlatform)
            IconButton(
              key: const ValueKey('open-sync-host'),
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
                      Dismissible(
                        key: ValueKey(t.id),
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
                        onDismissed: (_) => _delete(t),
                        child: ListTile(
                          title: Text(t.name),
                          subtitle: Text(
                              '${t.grid.cols}×${t.grid.rows} · ${t.cells.length} cells'),
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
                                key: ValueKey('fill-${t.id}'),
                                icon: const Icon(Icons.edit_note),
                                tooltip: 'Fill',
                                onPressed: () => _fill(t),
                              ),
                              // Swipe-to-delete is undiscoverable with a
                              // mouse; desktop gets a visible button.
                              if (isDesktopPlatform)
                                IconButton(
                                  key: ValueKey('delete-${t.id}'),
                                  icon: const Icon(Icons.delete_outline),
                                  tooltip: 'Delete',
                                  onPressed: () => _confirmDelete(t),
                                ),
                            ],
                          ),
                          onTap: () => _open(t),
                        ),
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
