import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'data/database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = AppDatabase();
  await db.ensureSeeded();
  runApp(
    Provider<AppDatabase>(
      create: (_) => db,
      dispose: (_, d) => d.close(),
      child: const SurveyApp(),
    ),
  );
}
