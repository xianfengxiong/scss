/// Move the grid line between track [boundary]-1 and [boundary] by [deltaMm].
/// Positive delta grows the left/upper track and shrinks the right/lower one.
/// The total is preserved; neither adjacent track goes below [minMm].
List<double> resizeBoundary(
  List<double> sizes,
  int boundary,
  double deltaMm, {
  double minMm = 5,
}) {
  assert(boundary >= 1 && boundary < sizes.length);
  final out = List<double>.from(sizes);
  final maxGrow = out[boundary] - minMm; // how much we can take from the right
  final maxShrink = out[boundary - 1] - minMm; // how much we can take from left
  final d = deltaMm.clamp(-maxShrink, maxGrow);
  out[boundary - 1] += d;
  out[boundary] -= d;
  return out;
}

/// Append a new track of [newSizeMm]. [offsetMm] is the frame's x (for columns)
/// or y (for rows); [pageLimitMm] is the page width or height. Returns null if
/// the new track would push the frame past the page edge (A4 cap — no overflow).
List<double>? addTrack(
  List<double> sizes,
  double newSizeMm,
  double offsetMm,
  double pageLimitMm,
) {
  final sum = sizes.fold(0.0, (a, b) => a + b);
  if (offsetMm + sum + newSizeMm > pageLimitMm + 1e-9) return null;
  return [...sizes, newSizeMm];
}

/// Remove the track at [index].
List<double> removeTrack(List<double> sizes, int index) =>
    [...sizes]..removeAt(index);
