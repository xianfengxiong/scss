import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/widgets.dart' as pw;

import '../model/cell.dart';
import '../services/image_service.dart';
import '../services/media_paths.dart';
import 'control_spec.dart';

/// A single-photo value control. Fill mode: capture (camera/gallery) → compress
/// → store; the value is the image's file name in the shared store (legacy
/// rows hold absolute paths — [MediaPaths.resolve] handles both); shows the
/// photo with a ✕ clear button.
/// PDF: embeds the photo (bytes resolved via [resolvePdfValue] before render).
class ImageControl extends ControlSpec {
  /// Injected by the registry so fill mode can capture photos. Null → the
  /// add-photo button is shown but capture is a no-op (tests / non-device).
  final ImageService? image;

  ImageControl({this.image});

  @override
  String get type => 'image';
  @override
  String get label => 'Image';
  @override
  IconData get icon => Icons.image_outlined;
  @override
  Map<String, dynamic> defaultProps() => {'key': 'image', 'caption': ''};

  @override
  Future<Object?> resolvePdfValue(Cell cell, Object? value) async {
    if (value is! String || value.isEmpty) return null;
    final f = File(MediaPaths.resolve(value));
    if (!await f.exists()) return null;
    return f.readAsBytes();
  }

  @override
  pw.Widget paintPdf(Cell cell, Map<String, dynamic> data) {
    final v = data[cell.props['key']];
    if (v is Uint8List) {
      try {
        return pw.Image(pw.MemoryImage(v), fit: pw.BoxFit.contain);
      } catch (e) {
        debugPrint('[ImageControl] paintPdf: corrupt image bytes — $e');
        return pw.SizedBox();
      }
    }
    return pw.SizedBox();
  }

  @override
  Widget previewWidget(Cell cell) => Container(
        alignment: Alignment.center,
        child: const Text('[image]',
            style: TextStyle(fontSize: 9, color: Color(0xFF9A9A9A))),
      );

  @override
  Widget fillWidget(
          Cell cell, Object? value, void Function(Object? value) onChanged) =>
      _ImageField(image: image, value: value is String ? value : null, onChanged: onChanged);
}

class _ImageField extends StatelessWidget {
  final ImageService? image;
  final String? value;
  final void Function(Object? value) onChanged;

  const _ImageField({
    required this.image,
    required this.value,
    required this.onChanged,
  });

  Future<void> _add(BuildContext context) async {
    final svc = image;
    if (svc == null) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(children: [
          ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(context, ImageSource.camera)),
          ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery)),
        ]),
      ),
    );
    if (source == null) return;
    final path = await svc.capture(source);
    if (path != null) onChanged(path);
  }

  @override
  Widget build(BuildContext context) {
    final path = value;
    if (path != null && path.isNotEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.file(File(MediaPaths.resolve(path)), fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  const Center(child: Icon(Icons.broken_image, size: 16))),
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              key: const ValueKey('image-clear'),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              iconSize: 16,
              tooltip: 'Clear',
              icon: const Icon(Icons.close),
              onPressed: () => onChanged(null),
            ),
          ),
        ],
      );
    }
    return Center(
      child: IconButton(
        key: const ValueKey('image-add'),
        iconSize: 20,
        tooltip: 'Add photo',
        icon: const Icon(Icons.add_a_photo_outlined),
        onPressed: () => _add(context),
      ),
    );
  }
}
