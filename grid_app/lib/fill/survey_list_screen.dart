import 'package:flutter/material.dart';

import '../controls/registry.dart';
import '../data/survey_store.dart';
import '../data/template_store.dart';
import '../model/survey.dart';
import '../model/template.dart';
import '../services/platform_info.dart';
import '../widgets/list_icons.dart';
import 'fill_screen.dart';
import 'survey_actions.dart';
import 'time_label.dart';

/// All surveys across every template — the flat, most-recent-first view
/// reached from the template list's AppBar. Day-to-day navigation goes
/// template → its surveys (TemplateSurveysScreen); this list answers "what
/// did I work on last", so each row names its template.
class SurveyListScreen extends StatefulWidget {
  final SurveyStore surveyStore;
  final TemplateStore templateStore;
  final ControlRegistry registry;

  const SurveyListScreen({
    super.key,
    required this.surveyStore,
    required this.templateStore,
    required this.registry,
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

  Future<void> _rename(Survey s) async {
    await renameSurvey(context, widget.surveyStore, s);
    if (!mounted) return;
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('All Surveys')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _surveys.isEmpty
              ? const Center(
                  child: Text('No surveys yet. Open a template to start one.'))
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
                        confirmDismiss: (_) async {
                          await _delete(s);
                          // _delete already removed + reloaded on confirm.
                          return false;
                        },
                        child: ListTile(
                          leading: surveyListIcon(context),
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
                                  onPressed: () => _delete(s),
                                ),
                            ],
                          ),
                          onTap: () => _resume(s),
                        ),
                      ),
                  ],
                ),
    );
  }
}
