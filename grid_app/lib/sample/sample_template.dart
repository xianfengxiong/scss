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
        Cell(id: 'name', col: 0, row: 1, colSpan: 12, type: 'field',
            props: {'label': 'Site Name', 'key': 'site_name', 'labelCols': 3}),
        Cell(id: 'city', col: 0, row: 2, colSpan: 12, type: 'field',
            props: {'label': 'Site City', 'key': 'site_city', 'labelCols': 3}),
      ],
    );
