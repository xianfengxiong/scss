import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/database.dart';
import 'site_list_screen.dart';
import 'template_list_screen.dart';

class ProjectListScreen extends StatelessWidget {
  const ProjectListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final db = context.read<AppDatabase>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Projects'),
        actions: [
          IconButton(
            icon: const Icon(Icons.dashboard_customize_outlined),
            tooltip: 'Templates',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TemplateListScreen()),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<Project>>(
        stream: db.watchProjects(),
        builder: (context, snapshot) {
          final projects = snapshot.data ?? const [];
          if (projects.isEmpty) {
            return const Center(
              child: Text('No projects yet.\nTap "New Project" to start.',
                  textAlign: TextAlign.center),
            );
          }
          return ListView.separated(
            itemCount: projects.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final pr = projects[i];
              return ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(pr.name),
                subtitle: Text(
                    'Created ${pr.createdAt.toLocal().toString().split('.').first}'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _confirmDelete(context, db, pr),
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => SiteListScreen(project: pr)),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createProject(context, db),
        icon: const Icon(Icons.add),
        label: const Text('New Project'),
      ),
    );
  }

  Future<void> _createProject(BuildContext context, AppDatabase db) async {
    final templates = await db.getTemplates();
    if (!context.mounted) return;
    if (templates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Create a template first.')));
      return;
    }
    final nameCtrl = TextEditingController();
    String templateId = templates.first.id;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('New Project'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Project name'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: templateId,
                decoration: const InputDecoration(labelText: 'Template'),
                items: templates
                    .map((t) =>
                        DropdownMenuItem(value: t.id, child: Text(t.name)))
                    .toList(),
                onChanged: (v) => setState(() => templateId = v!),
              ),
            ],
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
      ),
    );

    if (ok == true && nameCtrl.text.trim().isNotEmpty) {
      await db.createProject(nameCtrl.text.trim(), templateId);
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, AppDatabase db, Project pr) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${pr.name}"?'),
        content: const Text(
            'This permanently deletes the project and all its sites and surveys.'),
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
    if (ok == true) await db.deleteProject(pr.id);
  }
}
