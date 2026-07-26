/// Pure time-formatting helpers for survey lists.
library;

import '../l10n/app_localizations.dart';

String _pad2(int v) => v.toString().padLeft(2, '0');

/// 'yyyy-MM-dd', e.g. default survey names ("Site Survey 2026-07-15").
String dateStamp(DateTime d) => '${d.year}-${_pad2(d.month)}-${_pad2(d.day)}';

/// Compact "how long ago" label for a survey's last write, in the app
/// language. Null (legacy rows saved before updatedAt existed) renders as '—'.
String updatedLabel(DateTime? updatedAt, DateTime now, AppLocalizations l10n) {
  if (updatedAt == null) return '—';
  final d = now.difference(updatedAt);
  if (d.inMinutes < 1) return l10n.justNow;
  if (d.inHours < 1) return l10n.minutesAgo(d.inMinutes);
  if (d.inDays < 1) return l10n.hoursAgo(d.inHours);
  if (d.inDays < 7) return l10n.daysAgo(d.inDays);
  return dateStamp(updatedAt);
}
