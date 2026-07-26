import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/model/template.dart';
import 'package:scss_grid/model/grid_frame.dart';
import 'package:scss_grid/model/cell.dart';
import 'package:scss_grid/controls/default_controls.dart';
import 'package:scss_grid/pdf/template_pdf.dart';

void main() {
  test('renders a single-page non-empty PDF', () async {
    final t = Template(
      id: 't',
      name: 'Survey',
      page: const PageSize.a4(),
      pages: [
        TemplatePage(
          grid: GridFrame.uniform(
              xMm: 10, yMm: 10, cols: 12, rows: 4, colWidthMm: 15, rowHeightMm: 8),
          cells: const [
            Cell(id: 'c1', col: 0, row: 0, colSpan: 12, type: 'title',
                props: {'text': 'Site Survey'}),
            Cell(id: 'c2_l', col: 0, row: 1, colSpan: 2, type: 'label',
                props: {'text': 'Site Name', 'align': 'left', 'bold': false}),
            Cell(id: 'c2_v', col: 0, row: 2, colSpan: 6, type: 'text',
                props: {'key': 'site_name', 'hint': ''}),
          ],
        ),
      ],
    );
    final doc = renderTemplate(t, const {'site_name': 'Castle'}, buildDefaultRegistry());
    final bytes = await doc.save();
    expect(bytes, isNotEmpty);
  });

  test('mmToPt converts A4 width to ~595 pt', () {
    expect((210 * mmToPt).round(), 595);
  });
}
