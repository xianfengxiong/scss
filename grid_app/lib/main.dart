import 'package:flutter/material.dart';

import 'controls/default_controls.dart';
import 'controls/registry.dart';
import 'data/app_database.dart';
import 'data/template_store.dart';
import 'builder/template_list_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final store = DriftTemplateStore(AppDatabase.open());
  runApp(ScssGridApp(store: store, registry: buildDefaultRegistry()));
}

class ScssGridApp extends StatelessWidget {
  final TemplateStore store;
  final ControlRegistry registry;

  const ScssGridApp({super.key, required this.store, required this.registry});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'SCSS Grid Builder',
        theme: ThemeData(useMaterial3: true),
        home: TemplateListScreen(store: store, registry: registry),
      );
}
