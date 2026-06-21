import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../controls/registry.dart';
import '../model/template.dart';
import '../pdf/template_pdf.dart';

/// Shows the template rendered to a single-page A4 PDF using Phase 1A's
/// [renderTemplate]. Empty data (blank template preview).
class PdfPreviewScreen extends StatelessWidget {
  final Template template;
  final ControlRegistry registry;

  const PdfPreviewScreen(
      {super.key, required this.template, required this.registry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Preview')),
      body: PdfPreview(
        build: (format) =>
            renderTemplate(template, const {}, registry).save(),
        canChangePageFormat: false,
        canChangeOrientation: false,
      ),
    );
  }
}
