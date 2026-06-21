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
