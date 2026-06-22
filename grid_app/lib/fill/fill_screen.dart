import 'package:flutter/material.dart';

import '../builder/canvas_metrics.dart';
import '../builder/pdf_preview_screen.dart';
import '../controls/registry.dart';
import '../data/survey_store.dart';
import '../model/survey.dart';
import '../model/template.dart';
import 'fill_canvas.dart';

/// Fill mode: render [template]'s grid with real inputs, edit values, save the
/// [Survey], and export the filled A4 PDF. Structure is fixed — values only.
class FillScreen extends StatefulWidget {
  final Template template;
  final Survey survey;
  final SurveyStore store;
  final ControlRegistry registry;

  const FillScreen({
    super.key,
    required this.template,
    required this.survey,
    required this.store,
    required this.registry,
  });

  @override
  State<FillScreen> createState() => _FillScreenState();
}

class _FillScreenState extends State<FillScreen> {
  // Working copy of the answers; committed to the store on Save.
  late final Map<String, dynamic> _data = {...widget.survey.data};

  Survey get _current => widget.survey.copyWith(data: _data);

  Future<void> _save() async {
    await widget.store.upsert(_current);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Survey saved.')));
    }
  }

  void _export() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PdfPreviewScreen(
        template: widget.template,
        registry: widget.registry,
        data: _data,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.survey.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Export',
            onPressed: _export,
          ),
          IconButton(
            icon: const Icon(Icons.save_outlined),
            tooltip: 'Save',
            onPressed: _save,
          ),
        ],
      ),
      // No scroll view: the canvas fits the available box (FillCanvas scales to
      // width); a vertical scroll could steal taps. Matches BuilderScreen.
      body: Padding(
        padding: const EdgeInsets.all(kCanvasPad),
        child: Center(
          child: FillCanvas(
            template: widget.template,
            registry: widget.registry,
            data: _data,
            onChanged: (key, value) => setState(() => _data[key] = value),
          ),
        ),
      ),
    );
  }
}
