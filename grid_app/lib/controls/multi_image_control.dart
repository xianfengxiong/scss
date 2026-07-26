import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/widgets.dart' as pw;

import '../l10n/app_localizations.dart';
import '../model/cell.dart';
import '../services/image_service.dart';
import '../services/media_paths.dart';
import 'control_spec.dart';

/// Grid rows needed to show [count] images in [cols] columns.
/// 0 → 0; otherwise ceil(count / cols). Row height = cellHeight / this, so
/// 3 imgs in 3 cols → 1 row (fills full height); 4 imgs → 2 rows (each half).
int rowsForCount(int count, int cols) =>
    count <= 0 ? 0 : (count + cols - 1) ~/ cols;

/// A multi-photo value control. Value is a List of file paths. Fill mode shows
/// a fixed-column thumbnail grid with per-photo clear and an add button (hidden
/// at capacity). PDF embeds photos in a fixed-column grid whose rows split the
/// cell height evenly.
class MultiImageControl extends ControlSpec {
  /// Injected by the registry so fill mode can capture photos. Null → add is a
  /// no-op (tests / non-device).
  final ImageService? image;

  MultiImageControl({this.image});

  @override
  String get type => 'multiImage';
  @override
  String get label => 'Multi Image';
  @override
  IconData get icon => Icons.photo_library_outlined;
  @override
  Map<String, dynamic> defaultProps() =>
      {'key': 'images', 'rows': 2, 'cols': 3, 'min': 3};

  int _rows(Cell c) => (c.props['rows'] as num?)?.toInt() ?? 2;
  int _cols(Cell c) => (c.props['cols'] as num?)?.toInt() ?? 3;
  int _min(Cell c) => (c.props['min'] as num?)?.toInt() ?? 0;
  int _cap(Cell c) => _rows(c) * _cols(c);

  /// Normalize a fill value into a list of path strings.
  static List<String> _paths(Object? v) =>
      v is List ? v.whereType<String>().toList() : const <String>[];

  @override
  String? validate(Cell cell, Object? value) {
    final count = _paths(value).length;
    final min = _min(cell);
    final cap = _cap(cell);
    if (count < min) return 'At least $min, now $count';
    if (count > cap) return 'At most $cap, now $count';
    return null;
  }

  @override
  Future<Object?> resolvePdfValue(Cell cell, Object? value) async {
    final out = <Uint8List>[];
    for (final path in _paths(value)) {
      if (path.isEmpty) continue;
      final f = File(MediaPaths.resolve(path));
      if (!await f.exists()) continue;
      out.add(await f.readAsBytes());
    }
    return out.isEmpty ? null : out;
  }

  @override
  pw.Widget paintPdf(Cell cell, Map<String, dynamic> data) {
    final v = data[cell.props['key']];
    final bytes =
        v is List ? v.whereType<Uint8List>().toList() : const <Uint8List>[];
    if (bytes.isEmpty) return pw.SizedBox();
    final cols = _cols(cell);
    final rowCount = rowsForCount(bytes.length, cols);
    return pw.Column(
      // pdf 包默认不拉伸横轴 → 不加这行 Row 会缩成图片自然总宽、靠左留白。
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        for (var r = 0; r < rowCount; r++)
          pw.Expanded(
            child: pw.Row(
              children: [
                for (var col = 0; col < cols; col++)
                  pw.Expanded(child: _pdfCell(bytes, r * cols + col)),
              ],
            ),
          ),
      ],
    );
  }

  pw.Widget _pdfCell(List<Uint8List> bytes, int i) {
    if (i >= bytes.length) return pw.SizedBox(); // 末行不满 → 留白
    try {
      // 内边距 → 相邻图之间有 gutter（两侧各 3pt 合成 6pt 间隙），更美观。
      return pw.Padding(
        padding: const pw.EdgeInsets.all(3),
        child: pw.Image(pw.MemoryImage(bytes[i]), fit: pw.BoxFit.contain),
      );
    } catch (e) {
      debugPrint('[MultiImageControl] paintPdf: corrupt image bytes — $e');
      return pw.SizedBox();
    }
  }

  @override
  Widget previewWidget(Cell cell) => Container(
        alignment: Alignment.center,
        child: const Text('[multi-image]',
            style: TextStyle(fontSize: 9, color: Color(0xFF9A9A9A))),
      );

  @override
  Widget fillWidget(
          Cell cell, Object? value, void Function(Object? value) onChanged) =>
      _MultiImageField(
        image: image,
        paths: _paths(value),
        cols: _cols(cell),
        cap: _cap(cell),
        min: _min(cell),
        onChanged: onChanged,
      );

  @override
  Widget propEditor(
      Cell cell, void Function(Map<String, dynamic> props) onChanged) {
    Widget intField(String label, String key, int fallback) => TextFormField(
          initialValue:
              ((cell.props[key] as num?)?.toInt() ?? fallback).toString(),
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: label),
          onChanged: (v) =>
              onChanged({...cell.props, key: int.tryParse(v) ?? fallback}),
        );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          initialValue: (cell.props['key'] as String?) ?? '',
          decoration: const InputDecoration(labelText: 'Key'),
          onChanged: (v) => onChanged({...cell.props, 'key': v}),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: intField('Rows', 'rows', 2)),
            const SizedBox(width: 8),
            Expanded(child: intField('Cols', 'cols', 3)),
            const SizedBox(width: 8),
            Expanded(child: intField('Min', 'min', 3)),
          ],
        ),
      ],
    );
  }
}

/// Fixed-column thumbnail grid for fill mode. Rows split the available height
/// evenly; each photo has a clear button; a trailing add button shows while
/// below capacity. An inline red error (from `validate`) sits under the grid.
class _MultiImageField extends StatelessWidget {
  final ImageService? image;
  final List<String> paths;
  final int cols;
  final int cap;
  final int min;
  final void Function(Object? value) onChanged;

  const _MultiImageField({
    required this.image,
    required this.paths,
    required this.cols,
    required this.cap,
    required this.min,
    required this.onChanged,
  });

  Future<void> _add(BuildContext context) async {
    final svc = image;
    if (svc == null) return;
    final l10n = AppLocalizations.of(context)!;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(children: [
          ListTile(
              leading: const Icon(Icons.photo_camera),
              title: Text(l10n.camera),
              onTap: () => Navigator.pop(context, ImageSource.camera)),
          ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(l10n.gallery),
              onTap: () => Navigator.pop(context, ImageSource.gallery)),
        ]),
      ),
    );
    if (source == null) return;
    final path = await svc.capture(source);
    if (path != null) onChanged([...paths, path]);
  }

  void _remove(int i) {
    final next = [...paths]..removeAt(i);
    onChanged(next.isEmpty ? null : next);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final String? error = paths.length < min
        ? l10n.atLeastNPhotos(min, paths.length)
        : paths.length > cap
            ? l10n.atMostNPhotos(cap, paths.length)
            : null;
    final canAdd = paths.length < cap;
    final slots = paths.length + (canAdd ? 1 : 0);
    final rowCount = slots == 0 ? 0 : (slots + cols - 1) ~/ cols;
    return Column(
      children: [
        Expanded(
          child: rowCount == 0
              ? const SizedBox.shrink()
              : Column(
                  children: [
                    for (var r = 0; r < rowCount; r++)
                      Expanded(
                        child: Row(
                          children: [
                            for (var c = 0; c < cols; c++)
                              Expanded(child: _slot(context, r * cols + c)),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(error,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 8, color: Colors.red)),
          ),
      ],
    );
  }

  Widget _slot(BuildContext context, int i) {
    if (i < paths.length) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Padding(
            padding: const EdgeInsets.all(1),
            child: Image.file(File(MediaPaths.resolve(paths[i])),
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
                    const Center(child: Icon(Icons.broken_image, size: 14))),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              key: ValueKey('multi-image-clear-$i'),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
              iconSize: 14,
              tooltip: AppLocalizations.of(context)!.clear,
              icon: const Icon(Icons.close),
              onPressed: () => _remove(i),
            ),
          ),
        ],
      );
    }
    if (i == paths.length && paths.length < cap) {
      return Center(
        child: IconButton(
          key: const ValueKey('multi-image-add'),
          iconSize: 18,
          tooltip: AppLocalizations.of(context)!.addPhoto,
          icon: const Icon(Icons.add_a_photo_outlined),
          onPressed: () => _add(context),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
