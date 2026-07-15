/// Pure time-formatting helpers for survey lists. No intl dependency.
library;

String _pad2(int v) => v.toString().padLeft(2, '0');

/// 'yyyy-MM-dd', e.g. default survey names ("Site Survey 2026-07-15").
String dateStamp(DateTime d) => '${d.year}-${_pad2(d.month)}-${_pad2(d.day)}';

/// Compact "how long ago" label for a survey's last write. Null (legacy rows
/// saved before updatedAt existed) renders as '—'.
String updatedLabel(DateTime? updatedAt, DateTime now) {
  if (updatedAt == null) return '—';
  final d = now.difference(updatedAt);
  if (d.inMinutes < 1) return 'just now';
  if (d.inHours < 1) return '${d.inMinutes}m ago';
  if (d.inDays < 1) return '${d.inHours}h ago';
  if (d.inDays < 7) return '${d.inDays}d ago';
  return dateStamp(updatedAt);
}
