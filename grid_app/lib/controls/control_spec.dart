import 'package:flutter/widgets.dart';
import 'package:pdf/widgets.dart' as pw;

import '../model/cell.dart';

/// One control type, self-contained: palette metadata, default props, PDF
/// drawing, and (in Phase 1B) its builder/fill widgets. Adding a control =
/// add one subclass + register it. No switch statements elsewhere.
abstract class ControlSpec {
  String get type;
  String get label;
  IconData get icon;

  /// Initial props when the control is dropped onto the grid.
  Map<String, dynamic> defaultProps();

  /// Draw the cell's content for PDF. Sized/positioned by the renderer.
  pw.Widget paintPdf(Cell cell, Map<String, dynamic> data);

  // ---- UI members: default no-ops; Phase 1B overrides these. ----

  /// Placeholder shown on the builder canvas (design mode).
  Widget previewWidget(Cell cell) => const SizedBox.shrink();

  /// Property editor shown in the builder's inspector.
  Widget propEditor(
          Cell cell, void Function(Map<String, dynamic> props) onChanged) =>
      const SizedBox.shrink();

  /// Real input shown in fill mode.
  Widget fillWidget(
          Cell cell, Object? value, void Function(Object? value) onChanged) =>
      const SizedBox.shrink();

  /// Fill-time validation rule (e.g. multiImage min/max). null = valid.
  String? validate(Cell cell, Object? value) => null;
}
