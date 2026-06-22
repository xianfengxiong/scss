import '../model/cell.dart';
import '../model/grid_frame.dart';
import '../model/template.dart';

/// A small, valid starter template (subset of the real survey form):
/// a title band plus two label|value fields, on a 12-col grid.
Template sampleTemplate() => Template(
      id: 'sample',
      name: 'Site Survey (sample)',
      page: const PageSize.a4(),
      grid: GridFrame.uniform(
        xMm: 10,
        yMm: 10,
        cols: 12,
        rows: 16,
        colWidthMm: 15, // 12 * 15 = 180mm <= (210 - 10) usable
        rowHeightMm: 8, // 16 * 8 = 128mm <= (297 - 10) usable
      ),
      cells: const [
        Cell(id: 'title', col: 0, row: 0, colSpan: 12, type: 'title',
            props: {'text': 'Site Survey Form', 'align': 'center'}),
        Cell(id: 'name_l', col: 0, row: 1, colSpan: 3, type: 'label',
            props: {'text': 'Site Name', 'align': 'left', 'bold': false}),
        Cell(id: 'name_v', col: 3, row: 1, colSpan: 9, type: 'text',
            props: {'key': 'site_name', 'hint': ''}),
        Cell(id: 'city_l', col: 0, row: 2, colSpan: 3, type: 'label',
            props: {'text': 'Site City', 'align': 'left', 'bold': false}),
        Cell(id: 'city_v', col: 3, row: 2, colSpan: 9, type: 'text',
            props: {'key': 'site_city', 'hint': ''}),
      ],
    );
