class GridFrame {
  final double xMm;
  final double yMm;
  final int cols;
  final int rows;
  final List<double> colWidthsMm;
  final List<double> rowHeightsMm;

  GridFrame({
    required this.xMm,
    required this.yMm,
    required this.cols,
    required this.rows,
    required List<double> colWidthsMm,
    required List<double> rowHeightsMm,
  })  : colWidthsMm = List<double>.unmodifiable(colWidthsMm),
        rowHeightsMm = List<double>.unmodifiable(rowHeightsMm),
        assert(colWidthsMm.length == cols),
        assert(rowHeightsMm.length == rows);

  factory GridFrame.uniform({
    required double xMm,
    required double yMm,
    required int cols,
    required int rows,
    required double colWidthMm,
    required double rowHeightMm,
  }) =>
      GridFrame(
        xMm: xMm,
        yMm: yMm,
        cols: cols,
        rows: rows,
        colWidthsMm: List<double>.filled(cols, colWidthMm),
        rowHeightsMm: List<double>.filled(rows, rowHeightMm),
      );

  double get frameWidthMm => colWidthsMm.fold(0.0, (a, b) => a + b);
  double get frameHeightMm => rowHeightsMm.fold(0.0, (a, b) => a + b);

  GridFrame copyWith({
    double? xMm,
    double? yMm,
    List<double>? colWidthsMm,
    List<double>? rowHeightsMm,
  }) {
    final newCols = colWidthsMm ?? this.colWidthsMm;
    final newRows = rowHeightsMm ?? this.rowHeightsMm;
    return GridFrame(
      xMm: xMm ?? this.xMm,
      yMm: yMm ?? this.yMm,
      cols: newCols.length,
      rows: newRows.length,
      colWidthsMm: newCols,
      rowHeightsMm: newRows,
    );
  }

  Map<String, dynamic> toJson() => {
        'xMm': xMm,
        'yMm': yMm,
        'cols': cols,
        'rows': rows,
        'colWidthsMm': colWidthsMm,
        'rowHeightsMm': rowHeightsMm,
      };

  factory GridFrame.fromJson(Map<String, dynamic> j) => GridFrame(
        xMm: (j['xMm'] as num).toDouble(),
        yMm: (j['yMm'] as num).toDouble(),
        cols: j['cols'] as int,
        rows: j['rows'] as int,
        colWidthsMm: (j['colWidthsMm'] as List)
            .map((e) => (e as num).toDouble())
            .toList(),
        rowHeightsMm: (j['rowHeightsMm'] as List)
            .map((e) => (e as num).toDouble())
            .toList(),
      );
}
