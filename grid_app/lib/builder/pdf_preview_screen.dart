import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../controls/registry.dart';
import '../model/template.dart';
import '../pdf/resolve_pdf_data.dart';
import '../pdf/template_pdf.dart';

/// Shows the template rendered to a single-page A4 PDF using Phase 1A's
/// [renderTemplate]. Empty data (blank template preview).
class PdfPreviewScreen extends StatelessWidget {
  final Template template;
  final ControlRegistry registry;

  /// Answers to render into the PDF. Empty = blank-template preview (builder).
  final Map<String, dynamic> data;

  const PdfPreviewScreen(
      {super.key,
      required this.template,
      required this.registry,
      this.data = const {}});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Preview')),
      body: PdfPreview(
        build: (format) async {
          final resolved = await resolvePdfData(template, data, registry);
          return renderTemplate(template, resolved, registry).save();
        },
        canChangePageFormat: false,
        canChangeOrientation: false,
      ),
    );
  }
}
