import 'package:flutter/material.dart';

import '../controls/registry.dart';
import '../data/survey_store.dart';
import '../model/survey.dart';
import '../model/template.dart';
import '../widgets/list_icons.dart';
import 'survey_actions.dart';
import 'time_label.dart';

/// One template's surveys — the screen a template list row opens. Tapping a
/// survey resumes filling it; the FAB starts a new one. This IS the
/// template→survey relationship made visible (replaces the old
/// resume-or-create bottom sheet).
class TemplateSurveysScreen extends StatefulWidget {
  final Template template;
  final SurveyStore surveyStore;
  final ControlRegistry registry;

  const TemplateSurveysScreen({
    super.key,
    required this.template,
    required this.surveyStore,
    required this.registry,
  });

  @override
  State<TemplateSurveysScreen> createState() => _TemplateSurveysScreenState();
}

class _TemplateSurveysScreenState extends State<TemplateSurveysScreen> {
  List<Survey> _surveys = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final list = await widget.surveyStore.byTemplate(widget.template.id);
    if (!mounted) return;
    setState(() {
      _surveys = list;
      _loading = false;
    });
  }

  Future<void> _newSurvey() async {
    await createAndOpenSurvey(context,
        template: widget.template,
        surveyStore: widget.surveyStore,
        registry: widget.registry);
    if (!mounted) return;
    await _reload();
  }

  Future<void> _open(Survey s) async {
    await openFillScreen(context,
        template: widget.template,
        survey: s,
        surveyStore: widget.surveyStore,
        registry: widget.registry);
    if (!mounted) return;
    await _reload();
  }

  Future<void> _rename(Survey s) async {
    await renameSurvey(context, widget.surveyStore, s);
    if (!mounted) return;
    await _reload();
  }

  Future<void> _delete(Survey s) async {
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
    if (yes != true || !mounted) return;
    await widget.surveyStore.delete(s.id);
    if (!mounted) return;
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.template.name),
            Text('${_surveys.length} 份调查表',
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.normal)),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _surveys.isEmpty
              ? const Center(child: Text('这个模版还没有调查表。点 + 新建一份。'))
              : ListView(
                  children: [
                    for (final s in _surveys)
                      ListTile(
                        key: ValueKey('survey-${s.id}'),
                        leading: surveyListIcon(context),
                        title: Text(s.name),
                        subtitle: Text(
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
                            IconButton(
                              key: ValueKey('delete-${s.id}'),
                              icon: const Icon(Icons.delete_outline),
                              tooltip: 'Delete',
                              onPressed: () => _delete(s),
                            ),
                          ],
                        ),
                        onTap: () => _open(s),
                      ),
                  ],
                ),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('new-survey'),
        onPressed: _newSurvey,
        icon: const Icon(Icons.add),
        label: const Text('新建调查表'),
      ),
    );
  }
}
