import 'package:flutter/material.dart';

import 'controls/default_controls.dart';
import 'controls/registry.dart';
import 'data/app_database.dart';
import 'data/survey_store.dart';
import 'data/template_store.dart';
import 'builder/template_list_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final db = AppDatabase.open();
  runApp(ScssGridApp(
    store: DriftTemplateStore(db),
    surveyStore: DriftSurveyStore(db),
    registry: buildDefaultRegistry(),
  ));
}

class ScssGridApp extends StatelessWidget {
  final TemplateStore store;
  final SurveyStore surveyStore;
  final ControlRegistry registry;

  const ScssGridApp(
      {super.key,
      required this.store,
      required this.surveyStore,
      required this.registry});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'SCSS Grid Builder',
        theme: ThemeData(useMaterial3: true),
        home: TemplateListScreen(
            store: store, surveyStore: surveyStore, registry: registry),
      );
}
