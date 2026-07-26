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

/// One designed page: its own grid frame and controls. Every page in a
/// template shares the template's [PageSize]; pagination is explicit — the
/// user adds pages, nothing flows or splits automatically.
class TemplatePage {
  final GridFrame grid;
  final List<Cell> cells;

  const TemplatePage({required this.grid, required this.cells});

  TemplatePage copyWith({GridFrame? grid, List<Cell>? cells}) =>
      TemplatePage(grid: grid ?? this.grid, cells: cells ?? this.cells);

  Map<String, dynamic> toJson() => {
        'grid': grid.toJson(),
        'cells': cells.map((c) => c.toJson()).toList(),
      };

  factory TemplatePage.fromJson(Map<String, dynamic> j) => TemplatePage(
        grid: GridFrame.fromJson(j['grid'] as Map<String, dynamic>),
        cells: (j['cells'] as List)
            .map((e) => Cell.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class Template {
  final String id;
  final String name;
  final PageSize page;

  /// The designed pages, in print order. Always at least one.
  final List<TemplatePage> pages;

  /// Last time this template was saved. Null on rows saved before sync
  /// existed; merge logic treats null as epoch (loses against any real edit).
  final DateTime? updatedAt;

  const Template({
    required this.id,
    required this.name,
    required this.page,
    required this.pages,
    this.updatedAt,
  });

  /// Every cell across all pages — for cross-page invariants (unique data
  /// keys) and whole-survey work (PDF value resolution, field counts).
  List<Cell> get allCells => [for (final p in pages) ...p.cells];

  /// The template with page [index] replaced.
  Template withPage(int index, TemplatePage p) {
    final next = [...pages];
    next[index] = p;
    return copyWith(pages: next);
  }

  Template copyWith({
    String? id,
    String? name,
    PageSize? page,
    List<TemplatePage>? pages,
    DateTime? updatedAt,
  }) =>
      Template(
        id: id ?? this.id,
        name: name ?? this.name,
        page: page ?? this.page,
        pages: pages ?? this.pages,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'page': page.toJson(),
        'pages': pages.map((p) => p.toJson()).toList(),
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
        // Templates saved before multi-page existed hold a single top-level
        // grid + cells; read them as one page.
        pages: j['pages'] != null
            ? [
                for (final p in j['pages'] as List)
                  TemplatePage.fromJson(p as Map<String, dynamic>)
              ]
            : [
                TemplatePage(
                  grid: GridFrame.fromJson(j['grid'] as Map<String, dynamic>),
                  cells: (j['cells'] as List)
                      .map((e) => Cell.fromJson(e as Map<String, dynamic>))
                      .toList(),
                )
              ],
        updatedAt: j['updatedAt'] == null
            ? null
            : DateTime.parse(j['updatedAt'] as String),
      );
}
