import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../builder/canvas_metrics.dart';
import '../builder/pdf_preview_screen.dart';
import '../controls/registry.dart';
import '../data/survey_store.dart';
import '../model/survey.dart';
import '../model/template.dart';
import '../services/platform_info.dart';
import '../widgets/page_turn_switcher.dart';
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
  // Working copy of the answers; autosaved to the store (debounce + dispose flush).
  late final Map<String, dynamic> _data = {...widget.survey.data};

  // Multi-page templates: one page on screen at a time, switched by the
  // bottom navigator or an unzoomed horizontal swipe. Answers stay one map
  // for the whole template.
  int _pageIndex = 0;

  // Swipe-to-turn-page tracking, fed by InteractiveViewer's own gesture
  // stream (no competing recognizer): at 1× the canvas can't pan, so a
  // mostly-horizontal single-finger run reads as a page turn; zoomed in the
  // same gesture keeps panning the page.
  Offset _swipeAccum = Offset.zero;
  bool _swipeMultiTouch = false;

  // Which way the last page change travelled, for the slide animation.
  int _turnDir = 1;

  // Autosave: debounce writes so per-keystroke onChanged doesn't hammer the
  // store; flush pending edits on dispose so backing out never loses input.
  Timer? _saveTimer;
  bool _dirty = false;
  static const _autosaveDelay = Duration(milliseconds: 500);

  // Zoom/pan transform for the fill canvas; double-tap toggles 1×/1.5×.
  // Desktop adds Ctrl/Cmd+wheel zoom (mouse wheel alone pans) — see
  // _onPointerSignal; the phone zooms by pinching.
  final TransformationController _tc = TransformationController();
  TapDownDetails? _doubleTapDetails;
  static const double _doubleTapScale = 1.5;
  static const double _maxScale = 4.0;

  @override
  void dispose() {
    _flush();
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
      ..translateByDouble(
          -pos.dx * (_doubleTapScale - 1), -pos.dy * (_doubleTapScale - 1), 0, 1)
      ..scaleByDouble(_doubleTapScale, _doubleTapScale, _doubleTapScale, 1);
  }

  /// Desktop wheel handling. InteractiveViewer's own wheel behavior is
  /// zoom-without-modifier (and it can't be intercepted — every Listener on
  /// the hit path receives the signal), so on desktop IV's scaling is
  /// disabled and the wheel is handled here: Ctrl/Cmd+wheel zooms at the
  /// pointer, a bare mouse wheel pans. Trackpad scrolls are left to IV's
  /// native pan (skipped here to avoid double-panning).
  void _onPointerSignal(PointerSignalEvent e, Size viewport) {
    if (e is! PointerScrollEvent) return;
    final zoom = HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    if (zoom) {
      _zoomAt(e.localPosition, math.exp(-e.scrollDelta.dy / 200), viewport);
    } else if (e.kind != PointerDeviceKind.trackpad) {
      _panBy(-e.scrollDelta, viewport);
    }
  }

  void _zoomAt(Offset focal, double factor, Size viewport) {
    final current = _tc.value.getMaxScaleOnAxis();
    final target = (current * factor).clamp(1.0, _maxScale);
    if ((target - current).abs() < 1e-9) return;
    if (target <= 1.0 + 1e-9) {
      _tc.value = Matrix4.identity();
      return;
    }
    // Keep the scene point under the cursor fixed while scaling.
    final scene = _tc.toScene(focal);
    final m = Matrix4.identity()
      ..translateByDouble(focal.dx, focal.dy, 0, 1)
      ..scaleByDouble(target, target, target, 1)
      ..translateByDouble(-scene.dx, -scene.dy, 0, 1);
    _tc.value = _clampPan(m, viewport);
  }

  void _panBy(Offset delta, Size viewport) {
    if (_tc.value.getMaxScaleOnAxis() <= 1.01) return; // 1×: whole page visible
    final m = (Matrix4.identity()
          ..translateByDouble(delta.dx, delta.dy, 0, 1)) *
        _tc.value as Matrix4;
    _tc.value = _clampPan(m, viewport);
  }

  /// Keep the (viewport-sized) scene covering the viewport — programmatic
  /// transforms bypass InteractiveViewer's own boundary enforcement.
  Matrix4 _clampPan(Matrix4 m, Size viewport) {
    final scale = m.getMaxScaleOnAxis();
    final t = m.getTranslation();
    final minX = math.min(0.0, viewport.width * (1 - scale));
    final minY = math.min(0.0, viewport.height * (1 - scale));
    m.setTranslationRaw(
        t.x.clamp(minX, 0.0), t.y.clamp(minY, 0.0), 0);
    return m;
  }

  void _goToPage(int index) {
    final count = widget.template.pages.length;
    if (index < 0 || index >= count || index == _pageIndex) return;
    setState(() {
      _turnDir = index > _pageIndex ? 1 : -1;
      _pageIndex = index;
      _tc.value = Matrix4.identity(); // new page starts fully visible
    });
  }

  void _maybeSwipePage() {
    final run = _swipeAccum;
    _swipeAccum = Offset.zero;
    if (_swipeMultiTouch) return;
    if (widget.template.pages.length < 2) return;
    if (_tc.value.getMaxScaleOnAxis() > 1.01) return; // zoomed → pan, not turn
    if (run.dx.abs() < 60 || run.dx.abs() < run.dy.abs() * 1.5) return;
    _goToPage(_pageIndex + (run.dx < 0 ? 1 : -1));
  }

  void _onChanged(String key, dynamic value) {
    setState(() => _data[key] = value);
    _dirty = true;
    _saveTimer?.cancel();
    _saveTimer = Timer(_autosaveDelay, _flush);
  }

  void _flush() {
    _saveTimer?.cancel();
    _saveTimer = null;
    if (!_dirty) return;
    _dirty = false;
    widget.store
        .upsert(widget.survey
            .copyWith(data: {..._data}, updatedAt: DateTime.now()))
        .catchError((Object e) {
      // Keep the edit pending so the next change/flush retries; a lost write
      // must not be silent-dropped (autosave is the only persistence path).
      debugPrint('autosave failed: $e');
      _dirty = true;
    });
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
        ],
      ),
      // Pinch-zoom + pan so fields are usable on a small phone screen: the
      // canvas still fits to width at 1×, and the user can zoom in (up to 5×)
      // to type, then pan around. No vertical ScrollView (it would steal taps);
      // InteractiveViewer's own pan handles moving around when zoomed.
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(kCanvasPad),
              child: LayoutBuilder(
                builder: (context, constraints) => GestureDetector(
                  onDoubleTapDown: (d) => _doubleTapDetails = d,
                  onDoubleTap: _handleDoubleTap,
                  child: Listener(
                    onPointerSignal: (e) =>
                        _onPointerSignal(e, constraints.biggest),
                    child: InteractiveViewer(
                      transformationController: _tc,
                      minScale: 1.0,
                      maxScale: _maxScale,
                      // Desktop: wheel zoom/pan is handled in
                      // _onPointerSignal — IV's own scaling would also zoom
                      // on a bare wheel. Phone: pinch zoom stays IV's job.
                      scaleEnabled: !isDesktopPlatform,
                      onInteractionStart: (d) {
                        _swipeAccum = Offset.zero;
                        _swipeMultiTouch = d.pointerCount > 1;
                      },
                      onInteractionUpdate: (d) {
                        if (d.pointerCount > 1) _swipeMultiTouch = true;
                        _swipeAccum += d.focalPointDelta;
                      },
                      onInteractionEnd: (_) => _maybeSwipePage(),
                      child: Center(
                        child: PageTurnSwitcher(
                          pageIndex: _pageIndex,
                          direction: _turnDir,
                          child: FillCanvas(
                            template: widget.template,
                            pageIndex: _pageIndex,
                            registry: widget.registry,
                            data: _data,
                            onChanged: _onChanged,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (widget.template.pages.length > 1) _pageBar(),
        ],
      ),
    );
  }

  /// Bottom page switcher, only for multi-page templates (swiping unzoomed
  /// turns pages too).
  Widget _pageBar() {
    final count = widget.template.pages.length;
    return SafeArea(
      top: false,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            key: const ValueKey('fill-page-prev'),
            icon: const Icon(Icons.chevron_left),
            onPressed:
                _pageIndex > 0 ? () => _goToPage(_pageIndex - 1) : null,
          ),
          Text('${_pageIndex + 1} / $count',
              key: const ValueKey('fill-page-indicator')),
          IconButton(
            key: const ValueKey('fill-page-next'),
            icon: const Icon(Icons.chevron_right),
            onPressed: _pageIndex < count - 1
                ? () => _goToPage(_pageIndex + 1)
                : null,
          ),
        ],
      ),
    );
  }
}
