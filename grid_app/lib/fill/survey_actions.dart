import 'package:flutter/material.dart';

import '../controls/registry.dart';
import '../data/survey_store.dart';
import '../model/ids.dart';
import '../model/survey.dart';
import '../model/template.dart';
import 'fill_screen.dart';
import 'survey_name_dialog.dart';
import 'time_label.dart';

/// Rename with the shared dialog. Re-reads the latest row first: the caller's
/// list snapshot can lag a just-disposed FillScreen's autosave flush, and
/// renaming the stale copy would clobber that edit.
Future<void> renameSurvey(
    BuildContext context, SurveyStore surveyStore, Survey s) async {
  final name = await promptForSurveyName(context,
      title: 'Rename survey', initial: s.name);
  if (name == null || !context.mounted) return;
  final latest = await surveyStore.get(s.id) ?? s;
  await surveyStore
      .upsert(latest.copyWith(name: name, updatedAt: DateTime.now()));
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
