// Shared canvas geometry so the renderer and the gesture layer never drift.

/// Padding around the A4 page inside the builder body.
const double kCanvasPad = 12;

/// Pixels-per-mm to render an A4 page of [pageWidthMm] in [widthPx] of space.
double pageScale(double widthPx, double pageWidthMm) => widthPx / pageWidthMm;
