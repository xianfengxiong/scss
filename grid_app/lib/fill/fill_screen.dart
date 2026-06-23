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

  // Zoom/pan transform for the fill canvas; double-tap toggles 1×/1.5×.
  final TransformationController _tc = TransformationController();
  TapDownDetails? _doubleTapDetails;
  static const double _doubleTapScale = 1.5;

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    if (_tc.value.getMaxScaleOnAxis() > 1.01) {
      _tc.value = Matrix4.identity(); // 已放大 → 还原到适配宽度
      return;
    }
    final pos = _doubleTapDetails?.localPosition;
    if (pos == null) return;
    // 以双击点为中心放大到 1.5×。
    _tc.value = Matrix4.identity()
      ..translate(-pos.dx * (_doubleTapScale - 1), -pos.dy * (_doubleTapScale - 1))
      ..scale(_doubleTapScale);
  }

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
      // 键盘弹出时不顶起页面（否则正在编辑的输入框会跳出视野）；放大+平移自行定位。
      resizeToAvoidBottomInset: false,
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
      // Pinch-zoom + pan so fields are usable on a small phone screen: the
      // canvas still fits to width at 1×, and the user can zoom in (up to 5×)
      // to type, then pan around. No vertical ScrollView (it would steal taps);
      // InteractiveViewer's own pan handles moving around when zoomed.
      body: Padding(
        padding: const EdgeInsets.all(kCanvasPad),
        child: GestureDetector(
          onDoubleTapDown: (d) => _doubleTapDetails = d,
          onDoubleTap: _handleDoubleTap,
          child: InteractiveViewer(
            transformationController: _tc,
            minScale: 1.0,
            maxScale: 3.0,
            child: Center(
              child: FillCanvas(
                template: widget.template,
                registry: widget.registry,
                data: _data,
                onChanged: (key, value) => setState(() => _data[key] = value),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
