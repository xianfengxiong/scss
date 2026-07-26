import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:printing/printing.dart';
import 'package:scss_grid/builder/pdf_preview_screen.dart';
import 'package:scss_grid/controls/default_controls.dart';
import 'package:scss_grid/l10n/app_localizations.dart';
import 'package:scss_grid/sample/sample_template.dart';

void main() {
  testWidgets('PdfPreviewScreen builds with an app bar titled Preview',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: PdfPreviewScreen(
          template: sampleTemplate(), registry: buildDefaultRegistry()),
    ));
    // Do not pumpAndSettle: PdfPreview renders the PDF asynchronously via the
    // platform and may never settle in the test harness. One frame is enough
    // to assert the screen scaffold built.
    expect(find.text('Preview'), findsOneWidget);
  });

  testWidgets('page width is capped so desktop windows show the whole page',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: PdfPreviewScreen(
          template: sampleTemplate(), registry: buildDefaultRegistry()),
    ));
    final preview = tester.widget<PdfPreview>(find.byType(PdfPreview));
    expect(preview.maxPageWidth, 700);
  });
}
