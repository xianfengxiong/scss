import 'package:flutter/material.dart';

import 'template_table.dart' show kTableBorder;

/// A bordered, addable device sub-table used by `deviceTable` rows when
/// filling. Values are stored as a list of {column: value} maps.
class DeviceTableField extends StatefulWidget {
  final List<String> columns;
  final List<Map<String, dynamic>> initial;
  final ValueChanged<List<Map<String, dynamic>>> onChanged;

  const DeviceTableField({
    super.key,
    required this.columns,
    required this.initial,
    required this.onChanged,
  });

  @override
  State<DeviceTableField> createState() => _DeviceTableFieldState();
}

class _DeviceTableFieldState extends State<DeviceTableField> {
  late List<Map<String, TextEditingController>> _rows;

  List<String> get _cols =>
      widget.columns.isEmpty ? const ['Type', 'Number'] : widget.columns;

  @override
  void initState() {
    super.initState();
    _rows = widget.initial
        .map((m) => {
              for (final c in _cols)
                c: TextEditingController(text: m[c]?.toString() ?? '')
            })
        .toList();
    if (_rows.isEmpty) _rows = [_blank()];
  }

  Map<String, TextEditingController> _blank() =>
      {for (final c in _cols) c: TextEditingController()};

  @override
  void dispose() {
    for (final r in _rows) {
      for (final c in r.values) {
        c.dispose();
      }
    }
    super.dispose();
  }

  void _emit() {
    final out = <Map<String, dynamic>>[];
    for (final r in _rows) {
      final m = {for (final c in _cols) c: r[c]!.text};
      if (m.values.any((v) => v.toString().trim().isNotEmpty)) out.add(m);
    }
    widget.onChanged(out);
  }

  void _add() => setState(() => _rows = [..._rows, _blank()]);

  void _removeAt(int i) {
    setState(() {
      for (final c in _rows[i].values) {
        c.dispose();
      }
      _rows = [..._rows]..removeAt(i);
      if (_rows.isEmpty) _rows = [_blank()];
    });
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    Widget headerCell(String t) => Expanded(
          child: Container(
            decoration: BoxDecoration(border: Border.all(color: kTableBorder)),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Text(t,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        );
    return Column(
      children: [
        Row(children: [
          for (final c in _cols) headerCell(c),
          const SizedBox(width: 36),
        ]),
        for (int i = 0; i < _rows.length; i++)
          Row(
            children: [
              for (final c in _cols)
                Expanded(
                  child: Container(
                    decoration:
                        BoxDecoration(border: Border.all(color: kTableBorder)),
                    child: TextField(
                      controller: _rows[i][c],
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                      ),
                      onChanged: (_) => _emit(),
                    ),
                  ),
                ),
              SizedBox(
                width: 36,
                child: IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => _removeAt(i),
                ),
              ),
            ],
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _add,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add row'),
          ),
        ),
      ],
    );
  }
}
