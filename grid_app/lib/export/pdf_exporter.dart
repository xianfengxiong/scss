import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../controls/registry.dart';
import '../data/survey_store.dart';
import '../data/template_store.dart';
import '../model/survey.dart';
import '../model/template.dart';
import '../pdf/resolve_pdf_data.dart';
import '../pdf/template_pdf.dart';

/// What one export pass did, for the result snackbar.
class ExportReport {
  int written = 0;
  int skipped = 0;
  final List<String> errors = [];
}

/// A name safe to use as a file or folder name on macOS/Windows.
String sanitizeFileName(String name) {
  final cleaned =
      name.replaceAll(RegExp(r'[/\\:*?"<>|]'), '_').trim();
  return cleaned.isEmpty ? '_' : cleaned;
}

const _manifestName = '.scss_export_manifest.json';

/// Batch PDF export: one folder per template, one PDF per survey — or one
/// per page (`name_1.pdf`, `name_2.pdf`) when the template has several.
///
/// Incremental: the root's manifest records, per survey, the
/// survey+template `updatedAt` signature and the files written; a survey
/// whose signature still matches (and whose files still exist) is skipped,
/// so re-exporting only writes what changed. Permission failures
/// (FileSystemException — e.g. the macOS sandbox refusing an unauthorized
/// directory) abort and propagate so the caller can ask the user to pick
/// the directory; per-survey rendering errors are collected instead.
class PdfExporter {
  final TemplateStore templates;
  final SurveyStore surveys;
  final ControlRegistry registry;

  PdfExporter({
    required this.templates,
    required this.surveys,
    required this.registry,
  });

  Future<ExportReport> export({
    required String rootDir,
    String? onlyTemplateId,
    void Function(int done, int total)? onProgress,
  }) async {
    final report = ExportReport();
    final manifestFile = File(p.join(rootDir, _manifestName));
    Map<String, dynamic> entries = {};
    if (manifestFile.existsSync()) {
      try {
        final manifest =
            jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;
        entries = (manifest['surveys'] as Map<String, dynamic>? ?? {});
      } catch (_) {
        // Corrupt manifest → treat everything as new.
      }
    }

    final tpls = <Template>[];
    if (onlyTemplateId != null) {
      final t = await templates.get(onlyTemplateId);
      if (t != null) tpls.add(t);
    } else {
      tpls.addAll(await templates.all());
    }

    final work = <(Template, Survey)>[];
    for (final t in tpls) {
      for (final s in await surveys.byTemplate(t.id)) {
        work.add((t, s));
      }
    }
    var done = 0;
    onProgress?.call(0, work.length);

    for (final (t, s) in work) {
      final sig = '${s.updatedAt?.toUtc().toIso8601String()}'
          '|${t.updatedAt?.toUtc().toIso8601String()}';
      final entry = entries[s.id] as Map<String, dynamic>?;
      var fresh = entry != null && entry['sig'] == sig;
      if (fresh) {
        for (final f in entry['files'] as List) {
          if (!File(p.join(rootDir, f as String)).existsSync()) {
            fresh = false;
            break;
          }
        }
      }
      if (fresh) {
        report.skipped++;
        onProgress?.call(++done, work.length);
        continue;
      }

      try {
        final files = await _writeSurvey(rootDir, t, s);
        entries[s.id] = {'sig': sig, 'files': files};
        report.written++;
      } on FileSystemException {
        rethrow; // unwritable directory — every later write would fail too
      } catch (e) {
        report.errors.add('${s.name}: $e');
      }
      onProgress?.call(++done, work.length);
    }

    await manifestFile.writeAsString(jsonEncode({'surveys': entries}));
    return report;
  }

  Future<List<String>> _writeSurvey(
      String rootDir, Template t, Survey s) async {
    final tplDir = sanitizeFileName(t.name);
    // Same-named surveys under one template get a stable id suffix, so the
    // mapping never flips between runs (an order-based "(2)" would).
    final sameName = (await surveys.byTemplate(t.id))
        .where((x) => x.name.toLowerCase() == s.name.toLowerCase())
        .length;
    var base = sanitizeFileName(s.name);
    if (sameName > 1) {
      final tail = s.id.length > 4 ? s.id.substring(s.id.length - 4) : s.id;
      base = '$base [$tail]';
    }

    await Directory(p.join(rootDir, tplDir)).create(recursive: true);
    final resolved = await resolvePdfData(t, s.data, registry);
    final files = <String>[];
    if (t.pages.length == 1) {
      files.add(await _writePage(rootDir, tplDir, base, t, 0, resolved));
    } else {
      for (var i = 0; i < t.pages.length; i++) {
        files.add(
            await _writePage(rootDir, tplDir, '${base}_${i + 1}', t, i, resolved));
      }
    }
    return files;
  }

  Future<String> _writePage(String rootDir, String tplDir, String fileBase,
      Template t, int pageIndex, Map<String, dynamic> resolved) async {
    final doc = renderTemplateSinglePage(t, pageIndex, resolved, registry);
    final rel = p.join(tplDir, '$fileBase.pdf');
    await File(p.join(rootDir, rel)).writeAsBytes(await doc.save());
    return rel;
  }
}
