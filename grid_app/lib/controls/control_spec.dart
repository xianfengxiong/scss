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

  /// The data-map key this control reads/writes in fill mode, or null if it
  /// holds no value (e.g. a title). Default: the control's `props['key']`.
  String? dataKey(Cell cell) => cell.props['key'] as String?;

  /// Transform this control's fill value into the value its `paintPdf` expects,
  /// async, before PDF rendering. Default: identity (text/number/coordinate
  /// print their string as-is). `image` overrides this to read its file into
  /// bytes, since `paintPdf` is synchronous and cannot do file IO.
  Future<Object?> resolvePdfValue(Cell cell, Object? value) async => value;

  /// Real input shown in fill mode. Default: the read-only `previewWidget`, so
  /// value-less controls (title/section/staticText) just show themselves.
  /// Input controls override this.
  Widget fillWidget(
          Cell cell, Object? value, void Function(Object? value) onChanged) =>
      previewWidget(cell);

  /// Fill-time validation rule (e.g. multiImage min/max). null = valid.
  String? validate(Cell cell, Object? value) => null;
}
