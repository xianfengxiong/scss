import 'dart:io';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../data/database.dart';
import '../models/template_row.dart';

/// A site paired with its (optional) primary survey, for export.
typedef SiteEntry = ({Site site, Survey? survey});

class PdfService {
  // ---- Public API ----

  Future<Uint8List> buildSitePdf({
    required Project project,
    required Site site,
    required SurveyTemplate template,
    required Survey? survey,
  }) async {
    final doc = pw.Document();
    final widgets = await _siteWidgets(project, site, template, survey);
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(18),
      build: (ctx) => widgets,
    ));
    return doc.save();
  }

  /// Mode ① — one merged PDF, one site per (new) page.
  Future<Uint8List> buildProjectMergedPdf({
    required Project project,
    required SurveyTemplate template,
    required List<SiteEntry> entries,
  }) async {
    final doc = pw.Document();
    for (final e in entries) {
      final widgets = await _siteWidgets(project, e.site, template, e.survey);
      doc.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(18),
        build: (ctx) => widgets,
      ));
    }
    return doc.save();
  }

  Future<void> sharePdf(Uint8List bytes, String fileName) =>
      Printing.sharePdf(bytes: bytes, filename: fileName);

  /// Saves the PDF into the app's `exports/` directory and returns the path.
  Future<String> savePdf(Uint8List bytes, String fileName) async {
    final dir = await getApplicationDocumentsDirectory();
    final exports = Directory(p.join(dir.path, 'exports'));
    if (!await exports.exists()) await exports.create(recursive: true);
    final file = File(p.join(exports.path, fileName));
    await file.writeAsBytes(bytes);
    return file.path;
  }

  /// Mode ② — one single PDF per site, shared together as multiple files.
  Future<void> shareMultiplePdfs(
      List<({String fileName, Uint8List bytes})> files) async {
    final dir = await getTemporaryDirectory();
    final xfiles = <XFile>[];
    for (final f in files) {
      final path = p.join(dir.path, f.fileName);
      await File(path).writeAsBytes(f.bytes);
      xfiles.add(XFile(path));
    }
    await SharePlus.instance.share(ShareParams(files: xfiles));
  }

  // ---- filenames ----
  static String fileName(String project, String site) {
    final date = DateFormat('yyyyMMdd').format(DateTime.now());
    return '${_clean(project, 'Project')}_${_clean(site, 'Site')}_$date.pdf';
  }

  static String projectFileName(String project) {
    final date = DateFormat('yyyyMMdd').format(DateTime.now());
    return '${_clean(project, 'Project')}_All_$date.pdf';
  }

  static String _clean(String s, String fallback) {
    final cleaned = s
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return cleaned.isEmpty ? fallback : cleaned;
  }

  /// The value shown in a field's value cell (pure, unit-tested).
  static String valueText(TemplateField f, Map<String, dynamic> data) {
    final v = data[f.key];
    return v == null ? '' : v.toString().trim();
  }

  // ---- table rendering (mirrors the on-screen TemplateTable) ----
  static const _border = PdfColors.grey500;

  Future<List<pw.Widget>> _siteWidgets(Project project, Site site,
      SurveyTemplate template, Survey? survey) async {
    final data = survey?.data ?? const <String, dynamic>{};

    pw.MemoryImage? diagram;
    final photos = <pw.MemoryImage>[];
    for (final row in template.rows) {
      if (row.type == TemplateRowType.image) {
        if (row.imageKind == 'diagram') {
          diagram = await _loadImage(site.diagramImagePath);
        } else {
          for (final path in site.imagePaths.take(6)) {
            final img = await _loadImage(path);
            if (img != null) photos.add(img);
          }
        }
      }
    }

    return [
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 6),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Project: ${project.name}',
                style: const pw.TextStyle(fontSize: 10)),
            pw.Text('Date: ${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 10)),
          ],
        ),
      ),
      for (final row in template.rows) _pdfRow(row, data, diagram, photos),
    ];
  }

  pw.Widget _cellBox(pw.Widget child, {PdfColor? bg, pw.Alignment? align}) =>
      pw.Container(
        width: double.infinity,
        decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _border, width: 0.5), color: bg),
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        alignment: align,
        child: child,
      );

  pw.Widget _pdfRow(TemplateRow row, Map<String, dynamic> data,
      pw.MemoryImage? diagram, List<pw.MemoryImage> photos) {
    switch (row.type) {
      case TemplateRowType.title:
        return _cellBox(
          pw.Text(row.text,
              style:
                  pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
          align: pw.Alignment.center,
        );
      case TemplateRowType.section:
        return _cellBox(
          pw.Text(row.text,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          bg: PdfColors.grey300,
        );
      case TemplateRowType.field:
        return _pdfLabelValue(
            row.fields.isEmpty ? null : row.fields.first, data);
      case TemplateRowType.multiField:
        return pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            for (final f in row.fields)
              pw.Expanded(child: _pdfLabelValue(f, data)),
          ],
        );
      case TemplateRowType.deviceTable:
        return _pdfDeviceTable(row, data);
      case TemplateRowType.image:
        return _pdfImage(row, diagram, photos);
    }
  }

  pw.Widget _pdfLabelValue(TemplateField? f, Map<String, dynamic> data) {
    if (f == null) return _cellBox(pw.Text(''));
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Expanded(
          flex: 5,
          child: _cellBox(pw.Text(
              f.label + (f.unit != null ? ' (${f.unit})' : ''),
              style: const pw.TextStyle(fontSize: 10))),
        ),
        pw.Expanded(
          flex: 4,
          child: _cellBox(pw.Text(valueText(f, data),
              style: const pw.TextStyle(fontSize: 10))),
        ),
      ],
    );
  }

  pw.Widget _pdfDeviceTable(TemplateRow row, Map<String, dynamic> data) {
    final cols = row.columns.isEmpty ? const ['Type', 'Number'] : row.columns;
    final raw = data[row.listKey];
    final rows = (raw is List)
        ? raw.map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : <Map<String, dynamic>>[];
    return pw.Container(
      decoration:
          pw.BoxDecoration(border: pw.Border.all(color: _border, width: 0.5)),
      padding: const pw.EdgeInsets.all(5),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (row.text.isNotEmpty)
            pw.Text(row.text,
                style:
                    pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          pw.Table(
            border: pw.TableBorder.all(color: _border, width: 0.5),
            children: [
              pw.TableRow(children: [
                for (final c in cols)
                  pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text(c,
                          style: pw.TextStyle(
                              fontSize: 9, fontWeight: pw.FontWeight.bold))),
              ]),
              if (rows.isEmpty)
                pw.TableRow(children: [
                  for (final _ in cols)
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text('',
                            style: const pw.TextStyle(fontSize: 9))),
                ]),
              for (final r in rows)
                pw.TableRow(children: [
                  for (final c in cols)
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(r[c]?.toString() ?? '',
                            style: const pw.TextStyle(fontSize: 9))),
                ]),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfImage(TemplateRow row, pw.MemoryImage? diagram,
      List<pw.MemoryImage> photos) {
    pw.Widget body;
    if (row.imageKind == 'diagram') {
      body = diagram != null
          ? pw.Container(
              height: 160,
              alignment: pw.Alignment.center,
              child: pw.Image(diagram, fit: pw.BoxFit.contain))
          : pw.Text('No diagram',
              style:
                  const pw.TextStyle(fontSize: 9, color: PdfColors.grey600));
    } else {
      body = photos.isEmpty
          ? pw.Text('No photos',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600))
          : pw.Wrap(
              spacing: 5,
              runSpacing: 5,
              children: photos
                  .map((img) => pw.Container(
                      width: 150,
                      height: 110,
                      decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: _border, width: 0.5)),
                      child: pw.Image(img, fit: pw.BoxFit.cover)))
                  .toList(),
            );
    }
    return pw.Container(
      width: double.infinity,
      decoration:
          pw.BoxDecoration(border: pw.Border.all(color: _border, width: 0.5)),
      padding: const pw.EdgeInsets.all(5),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(row.text.isEmpty ? row.imageKind : row.text,
              style:
                  pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          body,
        ],
      ),
    );
  }

  Future<pw.MemoryImage?> _loadImage(String? path) async {
    if (path == null || path.isEmpty) return null;
    final f = File(path);
    if (!await f.exists()) return null;
    return pw.MemoryImage(await f.readAsBytes());
  }
}
