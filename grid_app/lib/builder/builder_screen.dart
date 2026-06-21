import 'package:flutter/material.dart';

import '../controls/registry.dart';
import '../data/template_store.dart';
import '../model/template.dart';
import 'grid_canvas.dart';
import 'pdf_preview_screen.dart';

/// Read-only builder (Phase 1B-i): displays the template's A4 canvas with
/// Save and Preview actions. Editing interactions arrive in Phase 1B-ii.
class BuilderScreen extends StatelessWidget {
  final Template template;
  final ControlRegistry registry;
  final TemplateStore store;

  const BuilderScreen({
    super.key,
    required this.template,
    required this.registry,
    required this.store,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(template.name),
            Text(
              '${template.grid.cols} × ${template.grid.rows} grid',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Preview',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) =>
                  PdfPreviewScreen(template: template, registry: registry),
            )),
          ),
          IconButton(
            icon: const Icon(Icons.save_outlined),
            tooltip: 'Save',
            onPressed: () async {
              await store.upsert(template);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Template saved.')));
              }
            },
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: GridCanvas(template: template, registry: registry),
        ),
      ),
    );
  }
}
