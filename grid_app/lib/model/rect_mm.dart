class RectMm {
  final double leftMm;
  final double topMm;
  final double widthMm;
  final double heightMm;

  const RectMm({
    required this.leftMm,
    required this.topMm,
    required this.widthMm,
    required this.heightMm,
  });

  double get rightMm => leftMm + widthMm;
  double get bottomMm => topMm + heightMm;

  @override
  bool operator ==(Object other) =>
      other is RectMm &&
      other.leftMm == leftMm &&
      other.topMm == topMm &&
      other.widthMm == widthMm &&
      other.heightMm == heightMm;

  @override
  int get hashCode => Object.hash(leftMm, topMm, widthMm, heightMm);

  @override
  String toString() =>
      'RectMm(l:$leftMm, t:$topMm, w:$widthMm, h:$heightMm)';
}
