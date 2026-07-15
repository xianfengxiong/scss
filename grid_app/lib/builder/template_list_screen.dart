import 'package:flutter/material.dart';

import '../controls/registry.dart';
import '../data/survey_store.dart';
import '../data/template_store.dart';
import '../fill/fill_screen.dart';
import '../fill/survey_list_screen.dart';
import '../fill/survey_name_dialog.dart';
import '../fill/time_label.dart';
import '../model/survey.dart';
import '../model/template.dart';
import '../sample/sample_template.dart';
import 'builder_screen.dart';

/// Home screen: lists saved templates; create a new one (seeded from the sample
/// layout), open one to view/preview, or delete one.
class TemplateListScreen extends StatefulWidget {
  final TemplateStore store;
  final SurveyStore surveyStore;
  final ControlRegistry registry;

  const TemplateListScreen(
      {super.key,
      required this.store,
      required this.surveyStore,
      required this.registry});

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
      id: 'tpl_${DateTime.now().millisecondsSinceEpoch}',
      name: 'New Template',
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

  /// Fill = resume-or-create: no surveys yet → straight to the name dialog;
  /// otherwise a sheet lists this template's surveys (newest first) plus a
  /// "New survey" item.
  Future<void> _fill(Template t) async {
    final existing = await widget.surveyStore.byTemplate(t.id);
    if (!mounted) return;
    if (existing.isEmpty) {
      await _newSurvey(t);
      return;
    }

    Survey? resume;
    var createNew = false;
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              key: const ValueKey('fill-new'),
              leading: const Icon(Icons.add),
              title: const Text('New survey'),
              onTap: () {
                createNew = true;
                Navigator.of(sheetCtx).pop();
              },
            ),
            const Divider(height: 1),
            for (final s in existing)
              ListTile(
                key: ValueKey('fill-resume-${s.id}'),
                title: Text(s.name),
                subtitle: Text(
                    '${updatedLabel(s.updatedAt, DateTime.now())} · ${s.data.length} fields'),
                onTap: () {
                  resume = s;
                  Navigator.of(sheetCtx).pop();
                },
              ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (createNew) {
      await _newSurvey(t);
    } else if (resume != null) {
      await _openFill(t, resume!);
    }
  }

  /// Name dialog → persist immediately (a named empty survey is a legitimate
  /// in-progress state; the dialog is the guard against accidental orphans).
  Future<void> _newSurvey(Template t) async {
    final name = await promptForSurveyName(context,
        title: 'New survey', initial: '${t.name} ${dateStamp(DateTime.now())}');
    if (name == null || !mounted) return;
    final survey = Survey(
      id: 'srv_${DateTime.now().millisecondsSinceEpoch}',
      templateId: t.id,
      name: name,
      updatedAt: DateTime.now(),
    );
    await widget.surveyStore.upsert(survey);
    if (!mounted) return;
    await _openFill(t, survey);
  }

  Future<void> _openFill(Template t, Survey survey) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => FillScreen(
        template: t,
        survey: survey,
        store: widget.surveyStore,
        registry: widget.registry,
      ),
    ));
  }

  Future<void> _openSurveys() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SurveyListScreen(
        surveyStore: widget.surveyStore,
        templateStore: widget.store,
        registry: widget.registry,
      ),
    ));
  }

  Future<void> _delete(Template t) async {
    await widget.store.delete(t.id);
    if (!mounted) return;
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SCSS Templates'),
        actions: [
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
                        direction: DismissDirection.endToStart,
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
                          trailing: IconButton(
                            key: ValueKey('fill-${t.id}'),
                            icon: const Icon(Icons.edit_note),
                            tooltip: 'Fill',
                            onPressed: () => _fill(t),
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
