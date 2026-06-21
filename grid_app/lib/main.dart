import 'package:flutter/material.dart';

/// Phase 1A is the UI-free core (model, geometry, controls, PDF). The builder
/// and fill UI arrive in Phase 1B; this is a placeholder entry point.
void main() => runApp(const ScssGridApp());

class ScssGridApp extends StatelessWidget {
  const ScssGridApp({super.key});

  @override
  Widget build(BuildContext context) => const MaterialApp(
        title: 'SCSS Grid Builder',
        home: Scaffold(
          body: Center(
            child: Text('SCSS Grid Builder — core ready. UI in Phase 1B.'),
          ),
        ),
      );
}
