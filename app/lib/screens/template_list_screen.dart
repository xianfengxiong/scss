import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/database.dart';
import '../models/template_row.dart';
import 'template_editor_screen.dart';

class TemplateListScreen extends StatelessWidget {
  const TemplateListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final db = context.read<AppDatabase>();
    return Scaffold(
      appBar: AppBar(title: const Text('Template Library')),
      body: StreamBuilder<List<SurveyTemplate>>(
        stream: db.watchTemplates(),
        builder: (context, snapshot) {
          final templates = snapshot.data ?? const [];
          if (templates.isEmpty) {
            return const Center(child: Text('No templates. Tap + to create one.'));
          }
          return ListView.separated(
            itemCount: templates.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final t = templates[i];
              final fieldCount =
                  t.rows.fold<int>(0, (s, r) => s + r.fields.length);
              return ListTile(
                leading: const Icon(Icons.description_outlined),
                title: Text(t.name),
                subtitle: Text('${t.rows.length} rows · $fieldCount fields'),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'clone') {
                      db.createTemplate('${t.name} copy', t.rows);
                    } else if (v == 'delete') {
                      _confirmDelete(context, db, t);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'clone', child: Text('Duplicate')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => TemplateEditorScreen(templateId: t.id)),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createTemplate(context, db),
        icon: const Icon(Icons.add),
        label: const Text('New Template'),
      ),
    );
  }

  Future<void> _createTemplate(BuildContext context, AppDatabase db) async {
    final nameCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Template'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Template name'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Create')),
        ],
      ),
    );
    if (ok == true && nameCtrl.text.trim().isNotEmpty) {
      final id = await db.createTemplate(nameCtrl.text.trim(), [
        TemplateRow.title(nameCtrl.text.trim()),
      ]);
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TemplateEditorScreen(templateId: id)),
      );
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, AppDatabase db, SurveyTemplate t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${t.name}"?'),
        content: const Text(
            'Projects already using this template will keep their saved data '
            'but lose the field definitions.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) await db.deleteTemplate(t.id);
  }
}
