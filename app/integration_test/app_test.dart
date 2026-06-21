import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'package:scss/app.dart';
import 'package:scss/data/database.dart';
import 'package:scss/services/pdf_service.dart';

/// End-to-end test on a device/emulator for the WYSIWYG table templates:
/// the template editor, the site fill screen and the PDF all use the same
/// table, so the same rows (title / section / device table) appear in the
/// editor and the fill screen, and the PDF renders successfully.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('table flow: library -> project -> site table -> pdf',
      (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.ensureSeeded();
    await tester.pumpWidget(
      Provider<AppDatabase>.value(value: db, child: const SurveyApp()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Projects'), findsOneWidget);

    // --- Template library: editor renders the default template as a table ---
    await tester.tap(find.byIcon(Icons.dashboard_customize_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Smart City Site Survey'), findsOneWidget);
    await tester.tap(find.text('Smart City Site Survey'));
    await tester.pumpAndSettle();
    expect(find.text('Edit Template'), findsOneWidget);
    expect(find.text('Site Survey Form'), findsWidgets); // title row
    expect(find.text('Devices to Install'), findsWidgets); // section row
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Projects'), findsOneWidget);

    // --- Project + site ---
    await tester.tap(find.text('New Project'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'QA Project');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('QA Project'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('New Site'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Site 647');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Site 647'));
    await tester.pumpAndSettle();

    // --- Site fill screen shows the same table ---
    expect(find.text('Site Survey Form'), findsWidgets);
    expect(find.text('Devices to Install'), findsWidgets);
    expect(find.widgetWithText(FloatingActionButton, 'Export PDF'),
        findsOneWidget);

    // --- Persistence + on-device PDF generation ---
    final projects = await db.watchProjects().first;
    expect(projects.length, 1);
    final sites = await db.getSites(projects.first.id);
    expect(sites.length, 1);
    final template = await db.getTemplate(projects.first.templateId);
    final survey = await db.getSurveyForSite(sites.first.id);
    final pdf = await PdfService().buildSitePdf(
      project: projects.first,
      site: sites.first,
      template: template!,
      survey: survey,
    );
    expect(pdf.lengthInBytes, greaterThan(1000));

    // Leave the in-memory DB open: the widget tree is torn down after the test
    // and dispose() performs a final save.
  });
}
