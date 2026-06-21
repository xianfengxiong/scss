import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/database.dart';
import '../services/pdf_service.dart';
import 'site_detail_screen.dart';

class SiteListScreen extends StatelessWidget {
  final Project project;
  const SiteListScreen({super.key, required this.project});

  @override
  Widget build(BuildContext context) {
    final db = context.read<AppDatabase>();
    return Scaffold(
      appBar: AppBar(
        title: Text(project.name),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Export all sites',
            onSelected: (m) => _exportAll(context, db, m),
            itemBuilder: (_) => const [
              PopupMenuItem(
                  value: 'merged',
                  child: Text('Export all — one merged PDF')),
              PopupMenuItem(
                  value: 'perSite',
                  child: Text('Export all — one PDF per site')),
            ],
          ),
        ],
      ),
      body: StreamBuilder<List<Site>>(
        stream: db.watchSites(project.id),
        builder: (context, snapshot) {
          final sites = snapshot.data ?? const [];
          if (sites.isEmpty) {
            return const Center(child: Text('No sites yet. Tap + to add one.'));
          }
          return ListView.separated(
            itemCount: sites.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final s = sites[i];
              return ListTile(
                leading: const Icon(Icons.place_outlined),
                title: Text(s.name),
                subtitle: Text(s.city.isEmpty ? '—' : s.city),
                trailing: _statusChip(s.status),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        SiteDetailScreen(project: project, siteId: s.id),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createSite(context, db),
        icon: const Icon(Icons.add),
        label: const Text('New Site'),
      ),
    );
  }

  Widget _statusChip(String s) {
    final color = switch (s) {
      SiteStatus.completed => Colors.blue,
      SiteStatus.exported => Colors.green,
      _ => Colors.grey,
    };
    return Chip(
      label: Text(s, style: TextStyle(color: color, fontSize: 11)),
      backgroundColor: color.withValues(alpha: 0.12),
      side: BorderSide(color: color.withValues(alpha: 0.3)),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Future<void> _createSite(BuildContext context, AppDatabase db) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Site'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Site name'),
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
    if (ok == true && ctrl.text.trim().isNotEmpty) {
      await db.createSite(project.id, ctrl.text.trim());
    }
  }

  Future<void> _exportAll(
      BuildContext context, AppDatabase db, String mode) async {
    final messenger = ScaffoldMessenger.of(context);
    final template = await db.getTemplate(project.templateId);
    if (template == null) {
      messenger.showSnackBar(
          const SnackBar(content: Text('This project has no template.')));
      return;
    }
    final sites = await db.getSites(project.id);
    if (sites.isEmpty) {
      messenger
          .showSnackBar(const SnackBar(content: Text('No sites to export.')));
      return;
    }

    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
    }

    final pdf = PdfService();
    final entries = <SiteEntry>[];
    for (final s in sites) {
      entries.add((site: s, survey: await db.getSurveyForSite(s.id)));
    }

    try {
      if (mode == 'merged') {
        final bytes = await pdf.buildProjectMergedPdf(
            project: project, template: template, entries: entries);
        await _markExported(db, sites);
        if (context.mounted) Navigator.pop(context); // close progress
        await pdf.sharePdf(bytes, PdfService.projectFileName(project.name));
      } else {
        final files = <({String fileName, Uint8List bytes})>[];
        for (final e in entries) {
          final bytes = await pdf.buildSitePdf(
              project: project,
              site: e.site,
              template: template,
              survey: e.survey);
          files.add((
            fileName: PdfService.fileName(project.name, e.site.name),
            bytes: bytes
          ));
        }
        await _markExported(db, sites);
        if (context.mounted) Navigator.pop(context);
        await pdf.shareMultiplePdfs(files);
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  Future<void> _markExported(AppDatabase db, List<Site> sites) async {
    for (final s in sites) {
      if (s.status != SiteStatus.exported) {
        await db.upsertSite(s.copyWith(status: SiteStatus.exported));
      }
    }
  }
}
