import 'dart:io';

import 'package:flutter/material.dart';

/// Thumbnail grid for a site's photos with add + delete. The parent owns the
/// picking/compression (via ImageService) and the path list.
class PhotoGrid extends StatelessWidget {
  final List<String> paths;
  final int max;
  final VoidCallback? onAdd;
  final ValueChanged<String>? onDelete;

  const PhotoGrid({
    super.key,
    required this.paths,
    this.max = 6,
    this.onAdd,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final path in paths)
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(path),
                  width: 96,
                  height: 96,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 96,
                    height: 96,
                    color: Colors.grey.shade300,
                    child: const Icon(Icons.broken_image),
                  ),
                ),
              ),
              if (onDelete != null)
                Positioned(
                  right: 0,
                  top: 0,
                  child: GestureDetector(
                    onTap: () => onDelete!(path),
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(2),
                        child: Icon(Icons.close, size: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        if (onAdd != null && paths.length < max)
          InkWell(
            onTap: onAdd,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo),
                  SizedBox(height: 4),
                  Text('Add', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
