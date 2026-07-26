import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/builder/editor_ops.dart';
import 'package:scss_grid/controls/default_controls.dart';
import 'package:scss_grid/controls/device_checklist_control.dart';
import 'package:scss_grid/model/cell.dart';
import 'package:scss_grid/model/grid_frame.dart';
import 'package:scss_grid/model/template.dart';

Template _tpl(List<Cell> cells) => Template(
      id: 't',
      name: 'n',
      page: const PageSize.a4(),
      pages: [
        TemplatePage(
          grid: GridFrame.uniform(
              xMm: 0, yMm: 0, cols: 8, rows: 20, colWidthMm: 20, rowHeightMm: 8),
          cells: cells,
        ),
      ],
    );

Cell _dc() => Cell(
      id: 'd', col: 0, row: 0, colSpan: 6, rowSpan: 5,
      type: 'deviceChecklist', props: DeviceChecklistControl().defaultProps());

void main() {
  final reg = buildDefaultRegistry();

  test('reconcileCell: after rowSpan grows, rows follow (geometry path)', () {
    final t = _tpl([_dc().copyWith(rowSpan: 7)]);
    final out = reconcileCell(t.pages[0], 'd', reg);
    final cell = out.cells.single;
    expect(DeviceChecklistControl.rowsOf(cell).length, 6); // 7 - header
  });

  test('syncRowSpan: after rows change, rowSpan follows (property path)', () {
    // start from defaults (4 rows, rowSpan 5), add a 5th row in props
    final rows = DeviceChecklistControl.rowsOf(_dc())
      ..add({'label': '', 'key': 'r5'});
    final t = _tpl([_dc().copyWith(props: {..._dc().props, 'rows': rows})]);
    final out = syncRowSpan(t.pages[0], 'd', reg);
    expect(out.cells.single.rowSpan, 6); // 5 rows + header
  });

  test('syncRowSpan: leaves controls without requiredRowSpan untouched', () {
    final t = _tpl(const [
      Cell(id: 'n', col: 0, row: 0, type: 'number', props: {'key': 'k'})
    ]);
    expect(syncRowSpan(t.pages[0], 'n', reg).cells.single.rowSpan, 1);
  });

  test('placement initial span: rowSpan=requiredRowSpan, colSpan clamped to free run', () {
    final spec = DeviceChecklistControl();
    // emulate _placeDropped's math on an empty 8-wide grid at (0,0)
    final t = _tpl(const []);
    final free = freeRunWidth(t.pages[0], 0, 0); // 8
    final wantCol = spec.defaultColSpan() ?? free; // 6
    final colSpan = wantCol < free ? wantCol : free; // 6
    final tmp = Cell(
        id: 'x', col: 0, row: 0, colSpan: colSpan, rowSpan: 1,
        type: 'deviceChecklist', props: spec.defaultProps());
    final rowSpan = spec.requiredRowSpan(tmp) ?? 1; // 5
    expect(colSpan, 6);
    expect(rowSpan, 5);
    final placed = addCell(t.pages[0], tmp.copyWith(rowSpan: rowSpan));
    expect(isValid(t.withPage(0, placed)), isTrue); // fits in a 20-row grid
  });
}
