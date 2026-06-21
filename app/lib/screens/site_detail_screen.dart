import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart' show ImageSource;
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../data/database.dart';
import '../models/field_def.dart';
import '../models/pin.dart';
import '../models/template_row.dart';
import '../services/image_service.dart';
import '../services/location_service.dart';
import '../services/pdf_service.dart';
import '../widgets/device_table_field.dart';
import '../widgets/photo_grid.dart';
import '../widgets/template_table.dart';
import 'pdf_preview_screen.dart';
import 'site_diagram_screen.dart';

/// Fills a site by rendering the project's template as the same bordered table
/// used by the editor and the PDF: tap a value cell to type, device tables add
/// rows, coordinate cells can grab the current GPS, and image rows open the
/// satellite diagram / photo picker.
class SiteDetailScreen extends StatefulWidget {
  final Project project;
  final String siteId;
  const SiteDetailScreen(
      {super.key, required this.project, required this.siteId});

  @override
  State<SiteDetailScreen> createState() => _SiteDetailScreenState();
}

class _SiteDetailScreenState extends State<SiteDetailScreen> {
  late final AppDatabase _db;
  final _imageService = ImageService();

  Site? _site;
  SurveyTemplate? _template;
  final Map<String, dynamic> _data = {};
  final Map<String, TextEditingController> _ctrls = {};
  List<Pin> _pins = [];
  List<String> _imagePaths = [];
  String? _diagramPath;
  String _status = SiteStatus.draft;
  bool _loading = true;
  String _gpsBusyKey = '';

  @override
  void initState() {
    super.initState();
    _db = context.read<AppDatabase>();
    _load();
  }

  Future<void> _load() async {
    final site = await _db.getSite(widget.siteId);
    final template = await _db.getTemplate(widget.project.templateId);
    final survey = await _db.getSurveyForSite(widget.siteId);
    if (site != null) {
      _site = site;
      _pins = List.of(site.pins);
      _imagePaths = List.of(site.imagePaths);
      _diagramPath = site.diagramImagePath;
      _status = site.status;
    }
    _template = template;
    if (survey != null) _data.addAll(survey.data);
    if (template != null) {
      for (final row in template.rows) {
        for (final f in row.fields) {
          if (f.type == FieldType.text ||
              f.type == FieldType.number ||
              f.type == FieldType.coordinate) {
            _ctrls[f.key] =
                TextEditingController(text: _data[f.key]?.toString() ?? '');
          }
        }
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _persistFireAndForget();
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _pullControllers() =>
      _ctrls.forEach((k, c) => _data[k] = c.text.trim());

  Site _composeSite() => _site!.copyWith(
        pins: _pins,
        imagePaths: _imagePaths,
        diagramImagePath: Value(_diagramPath),
        status: _status,
      );

  void _persistFireAndForget() {
    if (_site == null || _template == null) return;
    _pullControllers();
    _db.saveSurveyData(widget.siteId, _template!.id, Map.of(_data));
    _db.upsertSite(_composeSite());
  }

  Future<void> _saveAll() async {
    if (_site == null || _template == null) return;
    _pullControllers();
    await _db.saveSurveyData(widget.siteId, _template!.id, Map.of(_data));
    _site = _composeSite();
    await _db.upsertSite(_site!);
  }

  // ---- coordinate GPS helper ----
  Future<void> _useGps(String key) async {
    setState(() => _gpsBusyKey = key);
    final res = await LocationService().getCurrentPosition();
    if (!mounted) return;
    setState(() => _gpsBusyKey = '');
    if (res.gps != null) {
      final text =
          '${res.gps!.lat.toStringAsFixed(6)}, ${res.gps!.lon.toStringAsFixed(6)}';
      _ctrls[key]?.text = text;
      _data[key] = text;
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(res.error ?? 'GPS failed')));
    }
  }

  LatLng? _gpsCenter() {
    for (final c in _ctrls.values) {
      final parts = c.text.split(',');
      if (parts.length == 2) {
        final lat = double.tryParse(parts[0].trim());
        final lon = double.tryParse(parts[1].trim());
        if (lat != null && lon != null) return LatLng(lat, lon);
      }
    }
    if (_pins.isNotEmpty) return LatLng(_pins.first.lat, _pins.first.lon);
    return null;
  }

  // ---- diagram ----
  Future<void> _openDiagram() async {
    await _saveAll();
    if (!mounted) return;
    final result =
        await Navigator.push<({List<Pin> pins, String? diagramPath})>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            SiteDiagramScreen(site: _site!, initialCenter: _gpsCenter()),
      ),
    );
    if (result != null) {
      setState(() {
        _pins = result.pins;
        _diagramPath = result.diagramPath ?? _diagramPath;
      });
      await _saveAll();
    }
  }

  // ---- photos ----
  Future<void> _addPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                onTap: () => Navigator.pop(context, ImageSource.camera)),
            ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () => Navigator.pop(context, ImageSource.gallery)),
          ],
        ),
      ),
    );
    if (source == null) return;
    final path = await _imageService.captureAndStore(widget.siteId, source);
    if (path != null && mounted) {
      setState(() => _imagePaths = [..._imagePaths, path]);
      await _saveAll();
    }
  }

  Future<void> _deletePhoto(String path) async {
    setState(() => _imagePaths = _imagePaths.where((p) => p != path).toList());
    await _imageService.deleteImage(path);
    await _saveAll();
  }

  // ---- export ----
  Future<void> _exportPdf() async {
    if (_template == null) return;
    setState(() => _status = SiteStatus.exported);
    await _saveAll();
    final survey = await _db.getSurveyForSite(widget.siteId);
    final pdf = PdfService();
    final bytes = await pdf.buildSitePdf(
        project: widget.project,
        site: _site!,
        template: _template!,
        survey: survey);
    final fileName = PdfService.fileName(widget.project.name, _site!.name);
    final path = await pdf.savePdf(bytes, fileName);
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PdfPreviewScreen(bytes: bytes, fileName: fileName, savedPath: path),
      ),
    );
  }

  // ---- fill cell builders ----
  Widget _fillFieldCell(TemplateField f) {
    switch (f.type) {
      case FieldType.select:
        final value = _data[f.key] as String?;
        return DropdownButton<String>(
          value: f.options.contains(value) ? value : null,
          isExpanded: true,
          underline: const SizedBox.shrink(),
          hint: const Text('—'),
          items: f.options
              .map((o) => DropdownMenuItem(value: o, child: Text(o)))
              .toList(),
          onChanged: (v) => setState(() => _data[f.key] = v),
        );
      case FieldType.coordinate:
        return TextField(
          controller: _ctrls[f.key],
          decoration: InputDecoration(
            isDense: true,
            border: InputBorder.none,
            hintText: 'lat, lon',
            suffixIcon: _gpsBusyKey == f.key
                ? const Padding(
                    padding: EdgeInsets.all(10),
                    child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2)))
                : IconButton(
                    icon: const Icon(Icons.my_location, size: 18),
                    onPressed: () => _useGps(f.key),
                  ),
          ),
          onChanged: (v) => _data[f.key] = v,
        );
      case FieldType.number:
        return TextField(
          controller: _ctrls[f.key],
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
              isDense: true, border: InputBorder.none),
          onChanged: (v) => _data[f.key] = v,
        );
      case FieldType.text:
      case FieldType.deviceList:
        return TextField(
          controller: _ctrls[f.key],
          decoration: const InputDecoration(
              isDense: true, border: InputBorder.none),
          onChanged: (v) => _data[f.key] = v,
        );
    }
  }

  Widget _fillDeviceCell(TemplateRow row) {
    final raw = _data[row.listKey];
    final initial = (raw is List)
        ? raw.map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : <Map<String, dynamic>>[];
    return DeviceTableField(
      columns: row.columns,
      initial: initial,
      onChanged: (rows) => _data[row.listKey] = rows,
    );
  }

  Widget _fillImageCell(TemplateRow row) {
    if (row.imageKind == 'diagram') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_diagramPath != null && File(_diagramPath!).existsSync())
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.file(File(_diagramPath!),
                  height: 150, width: double.infinity, fit: BoxFit.cover),
            )
          else
            Container(
              height: 80,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  border: Border.all(color: kTableBorder),
                  color: const Color(0xFFF5F5F5)),
              child: Text('No diagram yet · ${_pins.length} pins'),
            ),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: _openDiagram,
            icon: const Icon(Icons.edit_location_alt, size: 18),
            label: const Text('Edit on satellite map'),
          ),
        ],
      );
    }
    return PhotoGrid(
      paths: _imagePaths,
      onAdd: _addPhoto,
      onDelete: _deletePhoto,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_site == null || _template == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Site')),
        body: const Center(child: Text('Site or template not found.')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(_site!.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_outlined),
            tooltip: 'Save',
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              await _saveAll();
              messenger.showSnackBar(const SnackBar(content: Text('Saved.')));
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          TemplateTable(
            rows: _template!.rows,
            editing: false,
            fieldCell: _fillFieldCell,
            deviceCell: _fillDeviceCell,
            imageCell: _fillImageCell,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Status: '),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _status,
                items: SiteStatus.all
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) async {
                  if (v != null) {
                    setState(() => _status = v);
                    await _saveAll();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 70),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _exportPdf,
        icon: const Icon(Icons.picture_as_pdf),
        label: const Text('Export PDF'),
      ),
    );
  }
}
