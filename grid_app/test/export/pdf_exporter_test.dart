import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:scss_grid/controls/default_controls.dart';
import 'package:scss_grid/data/survey_store.dart';
import 'package:scss_grid/data/template_store.dart';
import 'package:scss_grid/export/pdf_exporter.dart';
import 'package:scss_grid/model/cell.dart';
import 'package:scss_grid/model/grid_frame.dart';
import 'package:scss_grid/model/survey.dart';
import 'package:scss_grid/model/template.dart';

GridFrame _grid() => GridFrame.uniform(
    xMm: 15, yMm: 10, cols: 12, rows: 16, colWidthMm: 15, rowHeightMm: 8);

TemplatePage _page(String cellId) => TemplatePage(grid: _grid(), cells: [
      Cell(id: cellId, col: 0, row: 0, colSpan: 12, type: 'text',
          props: {'key': 'k_$cellId', 'hint': ''}),
    ]);

void main() {
  late Directory tmp;
  late InMemoryTemplateStore templates;
  late InMemorySurveyStore surveys;
  late PdfExporter exporter;

  final t1 = DateTime.utc(2026, 7, 1);
  final t2 = DateTime.utc(2026, 7, 2);

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('pdf_export');
    templates = InMemoryTemplateStore();
    surveys = InMemorySurveyStore();
    exporter = PdfExporter(
        templates: templates,
        surveys: surveys,
        registry: buildDefaultRegistry());

    // "铁塔勘测": two pages; "机房清点": one page.
    await templates.upsert(Template(
        id: 'tpl_a',
        name: '铁塔勘测',
        page: const PageSize.a4(),
        pages: [_page('a1'), _page('a2')],
        updatedAt: t1));
    await templates.upsert(Template(
        id: 'tpl_b',
        name: '机房清点',
        page: const PageSize.a4(),
        pages: [_page('b1')],
        updatedAt: t1));
    await surveys.upsert(Survey(
        id: 'srv_1', templateId: 'tpl_a', name: '北郊 A012', updatedAt: t1));
    await surveys.upsert(Survey(
        id: 'srv_2', templateId: 'tpl_b', name: '一号机房', updatedAt: t1));
  });

  tearDown(() => tmp.delete(recursive: true));

  File out(String rel) => File(p.join(tmp.path, rel));

  test('writes one folder per template; multi-page surveys get _N suffixes',
      () async {
    final report = await exporter.export(rootDir: tmp.path);

    expect(report.written, 2);
    expect(report.skipped, 0);
    expect(out('铁塔勘测/北郊 A012_1.pdf').existsSync(), isTrue);
    expect(out('铁塔勘测/北郊 A012_2.pdf').existsSync(), isTrue);
    expect(out('铁塔勘测/北郊 A012.pdf').existsSync(), isFalse);
    expect(out('机房清点/一号机房.pdf').existsSync(), isTrue);
    // PDFs are real documents.
    expect(out('机房清点/一号机房.pdf').lengthSync(), greaterThan(500));
  });

  test('second run skips everything unchanged', () async {
    await exporter.export(rootDir: tmp.path);
    final again = await exporter.export(rootDir: tmp.path);
    expect(again.written, 0);
    expect(again.skipped, 2);
  });

  test('an updated survey is re-exported; the rest stay skipped', () async {
    await exporter.export(rootDir: tmp.path);
    await surveys.upsert(Survey(
        id: 'srv_1',
        templateId: 'tpl_a',
        name: '北郊 A012',
        updatedAt: t2,
        data: const {'k_a1': 'changed'}));

    final report = await exporter.export(rootDir: tmp.path);
    expect(report.written, 1);
    expect(report.skipped, 1);
  });

  test('a template edit re-exports its surveys (render output changes)',
      () async {
    await exporter.export(rootDir: tmp.path);
    final t = (await templates.get('tpl_b'))!;
    await templates.upsert(t.copyWith(updatedAt: t2));

    final report = await exporter.export(rootDir: tmp.path);
    expect(report.written, 1, reason: 'tpl_b survey re-rendered');
    expect(report.skipped, 1);
  });

  test('a deleted output file is re-written even with a matching signature',
      () async {
    await exporter.export(rootDir: tmp.path);
    out('机房清点/一号机房.pdf').deleteSync();

    final report = await exporter.export(rootDir: tmp.path);
    expect(report.written, 1);
    expect(out('机房清点/一号机房.pdf').existsSync(), isTrue);
  });

  test('onlyTemplateId limits the run to that template', () async {
    final report =
        await exporter.export(rootDir: tmp.path, onlyTemplateId: 'tpl_b');
    expect(report.written, 1);
    expect(out('机房清点/一号机房.pdf').existsSync(), isTrue);
    expect(Directory(p.join(tmp.path, '铁塔勘测')).existsSync(), isFalse);
  });

  test('same-named surveys get stable id suffixes, illegal chars sanitized',
      () async {
    await surveys.upsert(Survey(
        id: 'srv_3', templateId: 'tpl_b', name: '一号机房', updatedAt: t1));
    await surveys.upsert(Survey(
        id: 'srv_4', templateId: 'tpl_b', name: 'A/B:C*D', updatedAt: t1));

    await exporter.export(rootDir: tmp.path, onlyTemplateId: 'tpl_b');

    expect(out('机房清点/一号机房 [rv_2].pdf').existsSync(), isTrue);
    expect(out('机房清点/一号机房 [rv_3].pdf').existsSync(), isTrue);
    expect(out('机房清点/A_B_C_D.pdf').existsSync(), isTrue);
  });

  test('manifest survives and is valid JSON', () async {
    await exporter.export(rootDir: tmp.path);
    final manifest = jsonDecode(
            out('.scss_export_manifest.json').readAsStringSync())
        as Map<String, dynamic>;
    expect((manifest['surveys'] as Map).keys, containsAll(['srv_1', 'srv_2']));
  });
}
