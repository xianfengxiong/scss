import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

/// In-app PDF preview for an exported report. The file has already been saved
/// to storage; this screen just renders it (no share sheet).
class PdfPreviewScreen extends StatelessWidget {
  final Uint8List bytes;
  final String fileName;
  final String savedPath;

  const PdfPreviewScreen({
    super.key,
    required this.bytes,
    required this.fileName,
    required this.savedPath,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(fileName)),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.green.shade50,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Saved to: $savedPath',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: PdfPreview(
              build: (format) => bytes,
              allowSharing: false,
              allowPrinting: false,
              canChangePageFormat: false,
              canChangeOrientation: false,
              canDebug: false,
              pdfFileName: fileName,
            ),
          ),
        ],
      ),
    );
  }
}
