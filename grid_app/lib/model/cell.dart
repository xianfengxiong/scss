class Cell {
  final String id;
  final int col;
  final int row;
  final int colSpan;
  final int rowSpan;
  final String type;
  final Map<String, dynamic> props;

  const Cell({
    required this.id,
    required this.col,
    required this.row,
    this.colSpan = 1,
    this.rowSpan = 1,
    required this.type,
    this.props = const {},
  });

  Cell copyWith({
    String? id,
    int? col,
    int? row,
    int? colSpan,
    int? rowSpan,
    String? type,
    Map<String, dynamic>? props,
  }) =>
      Cell(
        id: id ?? this.id,
        col: col ?? this.col,
        row: row ?? this.row,
        colSpan: colSpan ?? this.colSpan,
        rowSpan: rowSpan ?? this.rowSpan,
        type: type ?? this.type,
        props: props ?? this.props,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'col': col,
        'row': row,
        'colSpan': colSpan,
        'rowSpan': rowSpan,
        'type': type,
        'props': props,
      };

  factory Cell.fromJson(Map<String, dynamic> j) => Cell(
        id: j['id'] as String,
        col: j['col'] as int,
        row: j['row'] as int,
        colSpan: (j['colSpan'] as int?) ?? 1,
        rowSpan: (j['rowSpan'] as int?) ?? 1,
        type: j['type'] as String,
        props: Map<String, dynamic>.from(j['props'] as Map? ?? const {}),
      );
}
