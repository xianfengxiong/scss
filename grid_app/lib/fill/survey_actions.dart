import 'package:flutter/material.dart';

import '../controls/registry.dart';
import '../data/survey_store.dart';
import '../model/ids.dart';
import '../model/survey.dart';
import '../model/template.dart';
import 'fill_screen.dart';
import 'survey_name_dialog.dart';
import 'time_label.dart';

/// Fill = resume-or-create for one template: no surveys yet → straight to
/// the name dialog; otherwise a sheet lists this template's surveys (newest
/// first) plus a "New survey" item. Shared by the template list's Fill
/// action and the phone home's new-survey flow.
Future<void> startSurveyForTemplate(
  BuildContext context, {
  required Template template,
  required SurveyStore surveyStore,
  required ControlRegistry registry,
}) async {
  final existing = await surveyStore.byTemplate(template.id);
  if (!context.mounted) return;
  if (existing.isEmpty) {
    await createAndOpenSurvey(context,
        template: template, surveyStore: surveyStore, registry: registry);
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
  if (!context.mounted) return;
  if (createNew) {
    await createAndOpenSurvey(context,
        template: template, surveyStore: surveyStore, registry: registry);
  } else if (resume != null) {
    await openFillScreen(context,
        template: template,
        survey: resume!,
        surveyStore: surveyStore,
        registry: registry);
  }
}

/// Name dialog → persist immediately (a named empty survey is a legitimate
/// in-progress state; the dialog is the guard against accidental orphans).
Future<void> createAndOpenSurvey(
  BuildContext context, {
  required Template template,
  required SurveyStore surveyStore,
  required ControlRegistry registry,
}) async {
  final name = await promptForSurveyName(context,
      title: 'New survey',
      initial: '${template.name} ${dateStamp(DateTime.now())}');
  if (name == null || !context.mounted) return;
  final survey = Survey(
    id: newSurveyId(),
    templateId: template.id,
    name: name,
    updatedAt: DateTime.now(),
  );
  await surveyStore.upsert(survey);
  if (!context.mounted) return;
  await openFillScreen(context,
      template: template,
      survey: survey,
      surveyStore: surveyStore,
      registry: registry);
}

Future<void> openFillScreen(
  BuildContext context, {
  required Template template,
  required Survey survey,
  required SurveyStore surveyStore,
  required ControlRegistry registry,
}) =>
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => FillScreen(
        template: template,
        survey: survey,
        store: surveyStore,
        registry: registry,
      ),
    ));
