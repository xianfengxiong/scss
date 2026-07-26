import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../controls/registry.dart';
import '../l10n/app_localizations.dart';
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
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.preview)),
      body: PdfPreview(
        build: (format) async {
          final resolved = await resolvePdfData(template, data, registry);
          return renderTemplate(template, resolved, registry).save();
        },
        canChangePageFormat: false,
        canChangeOrientation: false,
        // PdfPreview fills the available width by default — fine on a phone,
        // but a wide desktop window blows the A4 page up past the viewport.
        // Cap it so the whole page is visible; phones (narrower than the
        // cap) are unaffected.
        maxPageWidth: 700,
      ),
    );
  }
}
