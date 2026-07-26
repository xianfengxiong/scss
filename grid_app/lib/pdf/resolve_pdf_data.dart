import '../controls/registry.dart';
import '../model/template.dart';

/// Prepare [data] for PDF rendering: for each cell that has a data key, replace
/// its value with `spec.resolvePdfValue(...)` (async). Most controls are
/// identity; `image` turns a file path into bytes (since paintPdf is sync).
Future<Map<String, dynamic>> resolvePdfData(
  Template t,
  Map<String, dynamic> data,
  ControlRegistry registry,
) async {
  final out = Map<String, dynamic>.from(data);
  for (final cell in t.allCells) {
    final spec = registry.specFor(cell.type);
    if (spec == null) continue;
    final key = spec.dataKey(cell);
    if (key == null) continue;
    out[key] = await spec.resolvePdfValue(cell, out[key]);
  }
  return out;
}
