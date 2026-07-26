import '../model/template.dart';
import 'geometry.dart';

/// One straight edge of a control's cell rectangle, in millimetres. A renderer
/// draws it as a fixed-thickness line CENTERED on [atMm]; adjacent controls
/// share a boundary coordinate, so their coincident edges collapse to a single
/// visible width.
class GridEdge {
  /// true = vertical line at a constant x ([atMm]); false = horizontal at y.
  final bool vertical;
  final double atMm;
  final double fromMm;
  final double toMm;

  const GridEdge({
    required this.vertical,
    required this.atMm,
    required this.fromMm,
    required this.toMm,
  });
}

/// The 4 outline edges (left, right, top, bottom) of every control's mm-rect
/// on one page. Shared by the builder canvas, the fill canvas and the PDF so
/// the table borders are identical (WYSIWYG).
List<GridEdge> controlOutlineEdges(TemplatePage page) {
  final edges = <GridEdge>[];
  for (final cell in page.cells) {
    final r = cellRectMm(page.grid, cell);
    edges.add(GridEdge(
        vertical: true, atMm: r.leftMm, fromMm: r.topMm, toMm: r.bottomMm));
    edges.add(GridEdge(
        vertical: true, atMm: r.rightMm, fromMm: r.topMm, toMm: r.bottomMm));
    edges.add(GridEdge(
        vertical: false, atMm: r.topMm, fromMm: r.leftMm, toMm: r.rightMm));
    edges.add(GridEdge(
        vertical: false, atMm: r.bottomMm, fromMm: r.leftMm, toMm: r.rightMm));
  }
  return edges;
}
