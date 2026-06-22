import 'package:flutter/material.dart';

import '../controls/registry.dart';
import '../data/survey_store.dart';
import '../data/template_store.dart';
import '../model/survey.dart';
import 'fill_screen.dart';

/// Lists saved surveys: resume one (loads its template, opens FillScreen) or
/// swipe to delete. Surveys are created from the template list's Fill action.
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
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final list = await widget.surveyStore.all();
    if (!mounted) return;
    setState(() {
      _surveys = list;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Surveys')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _surveys.isEmpty
              ? const Center(
                  child: Text('No surveys yet. Fill a template to start one.'))
              : ListView(
                  children: [
                    for (final s in _surveys)
                      Dismissible(
                        key: ValueKey(s.id),
                        direction: DismissDirection.endToStart,
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
                          subtitle: Text('${s.data.length} fields filled'),
                          onTap: () => _resume(s),
                        ),
                      ),
                  ],
                ),
    );
  }
}
