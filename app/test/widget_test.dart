import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:scss/app.dart';
import 'package:scss/data/database.dart';
import 'package:scss/models/field_def.dart';
import 'package:scss/models/template_row.dart';
import 'package:scss/services/pdf_service.dart';
import 'package:scss/templates/default_template.dart';

void main() {
  test('valueText reads a field value from survey data', () {
    const f = TemplateField(
        label: 'New poles', key: 'new_poles', type: FieldType.number);
    expect(PdfService.valueText(f, {'new_poles': '3'}), '3');
    expect(PdfService.valueText(f, const {}), '');
  });

  test('default template rows reproduce the Excel form', () {
    final rows = defaultTemplateRows();
    expect(rows.first.type, TemplateRowType.title);
    expect(rows.any((r) => r.type == TemplateRowType.deviceTable), isTrue);
    expect(rows.any((r) => r.type == TemplateRowType.image), isTrue);

    final keys = rows.expand((r) => r.fields).map((f) => f.key).toList();
    expect(keys, contains('poe_switches'));
    expect(keys.toSet().length, keys.length); // unique keys
  });

  test('rows JSON round-trip', () {
    final rows = defaultTemplateRows();
    final decoded = TemplateRow.decodeList(TemplateRow.encodeList(rows));
    expect(decoded.length, rows.length);
    expect(decoded.first.text, rows.first.text);
  });

  test('db seed + project/site/survey CRUD with cascade delete', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.ensureSeeded();

    final templates = await db.getTemplates();
    expect(templates.length, 1);
    expect(templates.first.rows.isNotEmpty, isTrue);

    final pid = await db.createProject('P', templates.first.id);
    final sid = await db.createSite(pid, 'Site 1');
    await db.saveSurveyData(sid, templates.first.id, {'new_poles': '2'});

    final survey = await db.getSurveyForSite(sid);
    expect(survey!.data['new_poles'], '2');
    expect((await db.getSites(pid)).length, 1);

    await db.deleteProject(pid);
    expect(await db.getSites(pid), isEmpty);
    expect(await db.getSurveyForSite(sid), isNull);

    await db.close();
  });

  test('pdf filenames are sanitised', () {
    expect(PdfService.fileName('Gji 2026', 'Site 647'),
        matches(r'^Gji_2026_Site_647_\d{8}\.pdf$'));
    expect(PdfService.projectFileName('Gji 2026'),
        matches(r'^Gji_2026_All_\d{8}\.pdf$'));
  });

  testWidgets('app boots to the Projects home screen', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.ensureSeeded();
    await tester.pumpWidget(
      Provider<AppDatabase>.value(value: db, child: const SurveyApp()),
    );
    await tester.pump();
    expect(find.text('Projects'), findsOneWidget);
    expect(find.text('New Project'), findsOneWidget);

    // Unmount so drift's stream subscription closes inside the test, then drain
    // the resulting (zero-duration) timer before the test ends.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
    await db.close();
  });
}
