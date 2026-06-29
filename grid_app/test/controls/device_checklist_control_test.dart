import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/controls/default_controls.dart';
import 'package:scss_grid/controls/device_checklist_control.dart';
import 'package:scss_grid/controls/number_control.dart';
import 'package:scss_grid/model/cell.dart';

void main() {
  test('ControlSpec hooks default to no-op on existing controls', () {
    final n = NumberControl();
    const cell = Cell(id: 'n', col: 0, row: 0, type: 'number');
    expect(n.requiredRowSpan(cell), isNull);
    expect(n.reconcile(cell), same(cell));
    expect(n.defaultColSpan(), isNull);
  });

  test('type / label / defaultProps / dataKey', () {
    final c = DeviceChecklistControl();
    expect(c.type, 'deviceChecklist');
    expect(c.label, 'Device Checklist');
    final p = c.defaultProps();
    expect(p['key'], 'deviceChecklist');
    expect(p['title'], 'Type of device to install');
    expect(p['showHeader'], true);
    expect(p['numberLabel'], 'Number');
    expect(p['remarkLabel'], 'Remark');
    expect(p['numberCols'], 1);
    expect(p['remarkCols'], 2);
    expect((p['rows'] as List).length, 4);
    final cell = Cell(id: 'd', col: 0, row: 0, type: 'deviceChecklist', props: p);
    expect(c.dataKey(cell), 'deviceChecklist');
    expect(DeviceChecklistControl.showHeaderOf(cell), true);
    expect(DeviceChecklistControl.numberColsOf(cell), 1);
    expect(DeviceChecklistControl.remarkColsOf(cell), 2);
    // colSpan 6: name = 6 - 1 - 2 = 3
    expect(DeviceChecklistControl.nameColsFor(cell, 6), 3);
  });

  test('registered in default registry', () {
    final r = buildDefaultRegistry();
    expect(r.specFor('deviceChecklist'), isA<DeviceChecklistControl>());
  });
}
