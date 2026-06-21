import '../model/grid_frame.dart';
import 'tracks.dart';

/// Move the vertical grid line at column [boundary] (between col boundary-1 and
/// boundary) by [deltaMm]. Frame width is preserved; tracks stay >= minMm.
GridFrame resizeColBoundary(GridFrame g, int boundary, double deltaMm,
        {double minMm = 5}) =>
    g.copyWith(
        colWidthsMm:
            resizeBoundary(g.colWidthsMm, boundary, deltaMm, minMm: minMm));

/// Move the horizontal grid line at row [boundary] by [deltaMm]. Frame height
/// is preserved; tracks stay >= minMm.
GridFrame resizeRowBoundary(GridFrame g, int boundary, double deltaMm,
        {double minMm = 5}) =>
    g.copyWith(
        rowHeightsMm:
            resizeBoundary(g.rowHeightsMm, boundary, deltaMm, minMm: minMm));
