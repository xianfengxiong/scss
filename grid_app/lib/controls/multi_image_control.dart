import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/widgets.dart' as pw;

import '../model/cell.dart';
import '../services/image_service.dart';
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
    if (count < min) return '至少 $min 张，当前 $count';
    if (count > cap) return '最多 $cap 张，当前 $count';
    return null;
  }

  @override
  pw.Widget paintPdf(Cell cell, Map<String, dynamic> data) => pw.SizedBox();
}
