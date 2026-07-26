import 'cell.dart';
import 'grid_frame.dart';

class PageSize {
  final double widthMm;
  final double heightMm;
  const PageSize({required this.widthMm, required this.heightMm});
  const PageSize.a4()
      : widthMm = 210,
        heightMm = 297;

  Map<String, dynamic> toJson() => {'widthMm': widthMm, 'heightMm': heightMm};
  factory PageSize.fromJson(Map<String, dynamic> j) => PageSize(
        widthMm: (j['widthMm'] as num).toDouble(),
        heightMm: (j['heightMm'] as num).toDouble(),
      );
}

class Template {
  final String id;
  final String name;
  final PageSize page;
  final GridFrame grid;
  final List<Cell> cells;

  /// Last time this template was saved. Null on rows saved before sync
  /// existed; merge logic treats null as epoch (loses against any real edit).
  final DateTime? updatedAt;

  const Template({
    required this.id,
    required this.name,
    required this.page,
    required this.grid,
    required this.cells,
    this.updatedAt,
  });

  Template copyWith({
    String? id,
    String? name,
    PageSize? page,
    GridFrame? grid,
    List<Cell>? cells,
    DateTime? updatedAt,
  }) =>
      Template(
        id: id ?? this.id,
        name: name ?? this.name,
        page: page ?? this.page,
        grid: grid ?? this.grid,
        cells: cells ?? this.cells,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'page': page.toJson(),
        'grid': grid.toJson(),
        'cells': cells.map((c) => c.toJson()).toList(),
        // UTC ("Z" suffix) so the paired device parses the same instant; a
        // bare local string would shift by the devices' zone difference and
        // invert LWW ordering.
        if (updatedAt != null)
          'updatedAt': updatedAt!.toUtc().toIso8601String(),
      };

  factory Template.fromJson(Map<String, dynamic> j) => Template(
        id: j['id'] as String,
        name: j['name'] as String,
        page: PageSize.fromJson(j['page'] as Map<String, dynamic>),
        grid: GridFrame.fromJson(j['grid'] as Map<String, dynamic>),
        cells: (j['cells'] as List)
            .map((e) => Cell.fromJson(e as Map<String, dynamic>))
            .toList(),
        updatedAt: j['updatedAt'] == null
            ? null
            : DateTime.parse(j['updatedAt'] as String),
      );
}
