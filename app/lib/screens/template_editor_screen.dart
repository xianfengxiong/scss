import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/database.dart';
import '../models/field_def.dart';
import '../models/template_row.dart';
import '../widgets/template_table.dart';

/// WYSIWYG template editor: shows the template as the same bordered table the
/// fill screen and PDF use. Tap a row to manage it; add rows at the bottom.
class TemplateEditorScreen extends StatefulWidget {
  final String templateId;
  const TemplateEditorScreen({super.key, required this.templateId});

  @override
  State<TemplateEditorScreen> createState() => _TemplateEditorScreenState();
}

class _TemplateEditorScreenState extends State<TemplateEditorScreen> {
  final _nameCtrl = TextEditingController();
  SurveyTemplate? _template;
  List<TemplateRow> _rows = [];
  bool _loading = true;

  AppDatabase get _db => context.read<AppDatabase>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final t = await _db.getTemplate(widget.templateId);
    if (t != null) {
      _template = t;
      _nameCtrl.text = t.name;
      _rows = List.of(t.rows);
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final base = _template;
    if (base == null) return;
    await _db.upsertTemplate(
        base.copyWith(name: _nameCtrl.text.trim(), rows: _rows));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Template saved.')));
    Navigator.pop(context);
  }

  String _genKey(String label) {
    var base = label
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    if (base.isEmpty) base = 'field';
    final keys = <String>{
      for (final r in _rows) ...[
        for (final f in r.fields) f.key,
        if (r.listKey.isNotEmpty) r.listKey,
      ]
    };
    var key = base;
    var n = 1;
    while (keys.contains(key)) {
      key = '${base}_$n';
      n++;
    }
    return key;
  }

  // ---- row management ----

  void _setRow(int i, TemplateRow row) => setState(() => _rows[i] = row);
  void _removeRow(int i) => setState(() => _rows = [..._rows]..removeAt(i));
  void _move(int i, int delta) {
    final j = i + delta;
    if (j < 0 || j >= _rows.length) return;
    setState(() {
      final list = [..._rows];
      final r = list.removeAt(i);
      list.insert(j, r);
      _rows = list;
    });
  }

  Future<void> _manageRow(int index) async {
    final row = _rows[index];
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              dense: true,
              title: Text('${templateRowTypeLabel(row.type)} row',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(ctx);
                _editRow(index);
              },
            ),
            ListTile(
              leading: const Icon(Icons.arrow_upward),
              title: const Text('Move up'),
              onTap: () {
                Navigator.pop(ctx);
                _move(index, -1);
              },
            ),
            ListTile(
              leading: const Icon(Icons.arrow_downward),
              title: const Text('Move down'),
              onTap: () {
                Navigator.pop(ctx);
                _move(index, 1);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete'),
              onTap: () {
                Navigator.pop(ctx);
                _removeRow(index);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editRow(int index) async {
    final row = _rows[index];
    switch (row.type) {
      case TemplateRowType.title:
      case TemplateRowType.section:
        final text = await _textDialog(
            row.type == TemplateRowType.title ? 'Title' : 'Section', row.text);
        if (text != null) _setRow(index, row.copyWith(text: text));
        break;
      case TemplateRowType.field:
        final f = await _fieldDialog(
            existing: row.fields.isEmpty ? null : row.fields.first);
        if (f != null) _setRow(index, row.copyWith(fields: [f]));
        break;
      case TemplateRowType.multiField:
        // editing handled per-cell elsewhere; MVP keeps as-is
        break;
      case TemplateRowType.deviceTable:
        final res = await _deviceDialog(row);
        if (res != null) _setRow(index, res);
        break;
      case TemplateRowType.image:
        final res = await _imageDialog(row);
        if (res != null) _setRow(index, res);
        break;
    }
  }

  Future<void> _addRow() async {
    final type = await showModalBottomSheet<TemplateRowType>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final t in [
              TemplateRowType.field,
              TemplateRowType.section,
              TemplateRowType.title,
              TemplateRowType.deviceTable,
              TemplateRowType.image,
            ])
              ListTile(
                title: Text(templateRowTypeLabel(t)),
                onTap: () => Navigator.pop(ctx, t),
              ),
          ],
        ),
      ),
    );
    if (type == null) return;

    TemplateRow? row;
    switch (type) {
      case TemplateRowType.title:
        final text = await _textDialog('Title', 'Title');
        if (text != null) row = TemplateRow.title(text);
        break;
      case TemplateRowType.section:
        final text = await _textDialog('Section', 'Section');
        if (text != null) row = TemplateRow.section(text);
        break;
      case TemplateRowType.field:
        final f = await _fieldDialog();
        if (f != null) row = TemplateRow.field(f);
        break;
      case TemplateRowType.deviceTable:
        row = await _deviceDialog(TemplateRow.deviceTable(
            listKey: _genKey('devices'),
            columns: const ['Type', 'Number', 'Remark']));
        break;
      case TemplateRowType.image:
        row = await _imageDialog(
            TemplateRow.image(imageKind: 'photos', text: 'Photos'));
        break;
      case TemplateRowType.multiField:
        break;
    }
    if (row != null) setState(() => _rows = [..._rows, row!]);
  }

  // ---- dialogs ----

  Future<String?> _textDialog(String title, String initial) {
    final ctrl = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('OK')),
        ],
      ),
    );
  }

  Future<TemplateField?> _fieldDialog({TemplateField? existing}) {
    final labelCtrl = TextEditingController(text: existing?.label ?? '');
    final unitCtrl = TextEditingController(text: existing?.unit ?? '');
    final optionsCtrl =
        TextEditingController(text: existing?.options.join(', ') ?? '');
    var type = existing?.type ?? FieldType.text;

    return showDialog<TemplateField>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(existing == null ? 'Add field' : 'Edit field'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: labelCtrl,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'Label')),
                const SizedBox(height: 8),
                DropdownButtonFormField<FieldType>(
                  value: type,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: const [
                    FieldType.text,
                    FieldType.number,
                    FieldType.coordinate,
                    FieldType.select,
                  ]
                      .map((t) => DropdownMenuItem(
                          value: t, child: Text(fieldTypeLabel(t))))
                      .toList(),
                  onChanged: (v) => setLocal(() => type = v!),
                ),
                if (type == FieldType.number || type == FieldType.text)
                  TextField(
                      controller: unitCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Unit (optional)')),
                if (type == FieldType.select)
                  TextField(
                      controller: optionsCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Options (comma separated)')),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final label = labelCtrl.text.trim();
                if (label.isEmpty) return;
                Navigator.pop(
                  ctx,
                  TemplateField(
                    label: label,
                    key: existing?.key ?? _genKey(label),
                    type: type,
                    unit: unitCtrl.text.trim().isEmpty
                        ? null
                        : unitCtrl.text.trim(),
                    options: optionsCtrl.text
                        .split(',')
                        .map((e) => e.trim())
                        .where((e) => e.isNotEmpty)
                        .toList(),
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<TemplateRow?> _deviceDialog(TemplateRow row) {
    final captionCtrl = TextEditingController(text: row.text);
    final colsCtrl = TextEditingController(text: row.columns.join(', '));
    return showDialog<TemplateRow>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Device table'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: captionCtrl,
                decoration:
                    const InputDecoration(labelText: 'Caption (optional)')),
            TextField(
                controller: colsCtrl,
                decoration: const InputDecoration(
                    labelText: 'Columns (comma separated)')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final cols = colsCtrl.text
                  .split(',')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList();
              Navigator.pop(
                ctx,
                row.copyWith(
                  text: captionCtrl.text.trim(),
                  columns: cols.isEmpty ? const ['Type', 'Number'] : cols,
                  listKey: row.listKey.isEmpty ? _genKey('devices') : row.listKey,
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<TemplateRow?> _imageDialog(TemplateRow row) {
    final captionCtrl = TextEditingController(text: row.text);
    var kind = row.imageKind.isEmpty ? 'photos' : row.imageKind;
    return showDialog<TemplateRow>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Image area'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: kind,
                decoration: const InputDecoration(labelText: 'Kind'),
                items: const [
                  DropdownMenuItem(
                      value: 'diagram',
                      child: Text('Satellite diagram (pins)')),
                  DropdownMenuItem(
                      value: 'photos', child: Text('Photo grid')),
                ],
                onChanged: (v) => setLocal(() => kind = v!),
              ),
              TextField(
                  controller: captionCtrl,
                  decoration: const InputDecoration(labelText: 'Caption')),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(
                  ctx, row.copyWith(imageKind: kind, text: captionCtrl.text.trim())),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  // ---- placeholder cells (edit mode) ----

  Widget _editFieldCell(TemplateField f) {
    final hint = f.type == FieldType.select && f.options.isNotEmpty
        ? f.options.join(' / ')
        : fieldTypeLabel(f.type);
    return Text(hint,
        style: TextStyle(
            color: Colors.grey.shade600,
            fontStyle: FontStyle.italic,
            fontSize: 13));
  }

  Widget _editDeviceCell(TemplateRow row) {
    Widget cell(String t, bool header) => Expanded(
          child: Container(
            decoration: BoxDecoration(border: Border.all(color: kTableBorder)),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Text(t,
                style: header
                    ? const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)
                    : TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          ),
        );
    return Column(
      children: [
        Row(children: [for (final c in row.columns) cell(c, true)]),
        Row(children: [for (final _ in row.columns) cell('[  ]', false)]),
      ],
    );
  }

  Widget _editImageCell(TemplateRow row) => Container(
        height: 56,
        width: double.infinity,
        decoration: BoxDecoration(
            border: Border.all(color: kTableBorder),
            color: const Color(0xFFF5F5F5)),
        alignment: Alignment.center,
        child: Text(
          row.imageKind == 'diagram'
              ? 'satellite map + pins'
              : 'photo grid',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_template == null) {
      return const Scaffold(body: Center(child: Text('Template not found.')));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Template'),
        actions: [
          IconButton(
              icon: const Icon(Icons.save_outlined),
              tooltip: 'Save',
              onPressed: _save),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
                labelText: 'Template name', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 6),
          Text('Tap any row to edit / move / delete · WYSIWYG = PDF',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(height: 8),
          TemplateTable(
            rows: _rows,
            editing: true,
            onRowTap: _manageRow,
            fieldCell: _editFieldCell,
            deviceCell: _editDeviceCell,
            imageCell: _editImageCell,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _addRow,
            icon: const Icon(Icons.add),
            label: const Text('Add row'),
          ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }
}
