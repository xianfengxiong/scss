import 'package:flutter/material.dart';

import '../models/template_row.dart';

const Color kTableBorder = Color(0xFFBDBDBD); // grey.shade400
const Widget _vLine = SizedBox(width: 1, child: ColoredBox(color: kTableBorder));

/// Renders [TemplateRow]s as a bordered table. The *layout* is shared by the
/// template editor (editing = true; value cells show type placeholders) and the
/// fill screen (editing = false; value cells are real inputs). The parent
/// supplies the value/device/image widgets via builders, so both views — and
/// the PDF, which mirrors this layout — stay identical (WYSIWYG).
class TemplateTable extends StatelessWidget {
  final List<TemplateRow> rows;
  final bool editing;
  final Widget Function(TemplateField field) fieldCell;
  final Widget Function(TemplateRow row) deviceCell;
  final Widget Function(TemplateRow row) imageCell;
  final void Function(int index)? onRowTap;

  const TemplateTable({
    super.key,
    required this.rows,
    required this.fieldCell,
    required this.deviceCell,
    required this.imageCell,
    this.editing = false,
    this.onRowTap,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(border: Border.all(color: kTableBorder)),
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++)
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  bottom: i == rows.length - 1
                      ? BorderSide.none
                      : const BorderSide(color: kTableBorder),
                ),
              ),
              child: _row(rows[i], i),
            ),
        ],
      ),
    );
  }

  Widget _row(TemplateRow row, int index) {
    Widget content;
    switch (row.type) {
      case TemplateRowType.title:
        content = Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          child: Text(row.text,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        );
        break;
      case TemplateRowType.section:
        content = Container(
          width: double.infinity,
          color: const Color(0xFFEEEEEE),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Text(row.text,
              style: const TextStyle(fontWeight: FontWeight.bold)),
        );
        break;
      case TemplateRowType.field:
        content =
            _labelValue(row.fields.isEmpty ? null : row.fields.first);
        break;
      case TemplateRowType.multiField:
        content = IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int j = 0; j < row.fields.length; j++) ...[
                if (j > 0) _vLine,
                Expanded(child: _labelValue(row.fields[j])),
              ],
            ],
          ),
        );
        break;
      case TemplateRowType.deviceTable:
        content = Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (row.text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(row.text,
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                ),
              deviceCell(row),
            ],
          ),
        );
        break;
      case TemplateRowType.image:
        content = Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(row.text.isEmpty ? row.imageKind : row.text,
                  style: const TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              imageCell(row),
            ],
          ),
        );
        break;
    }

    if (editing && onRowTap != null) {
      return InkWell(onTap: () => onRowTap!(index), child: content);
    }
    return content;
  }

  Widget _labelValue(TemplateField? f) {
    if (f == null) return const SizedBox(height: 40);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 5,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              alignment: Alignment.centerLeft,
              child: Text(f.label + (f.unit != null ? ' (${f.unit})' : '')),
            ),
          ),
          _vLine,
          Expanded(
            flex: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              alignment: Alignment.centerLeft,
              child: fieldCell(f),
            ),
          ),
        ],
      ),
    );
  }
}
