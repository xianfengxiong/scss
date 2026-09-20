import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';

/// Wraps the home screen and, once after the first frame, tells the user
/// that the portable data folder beside the exe was not writable and where
/// the data actually went (Windows; see resolveAppDataLocation). Shown every
/// launch while the condition holds — the location matters for backups.
class DataDirNotice extends StatefulWidget {
  final String portableDir;
  final String actualDir;
  final Widget child;

  const DataDirNotice({
    super.key,
    required this.portableDir,
    required this.actualDir,
    required this.child,
  });

  @override
  State<DataDirNotice> createState() => _DataDirNoticeState();
}

class _DataDirNoticeState extends State<DataDirNotice> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _show();
    });
  }

  Future<void> _show() {
    final l10n = AppLocalizations.of(context)!;
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.dataDirNoticeTitle),
        content: SingleChildScrollView(
          child: Text(
              l10n.dataDirNoticeBody(widget.portableDir, widget.actualDir)),
        ),
        actions: [
          TextButton(
            key: const ValueKey('data-dir-copy'),
            onPressed: () =>
                Clipboard.setData(ClipboardData(text: widget.actualDir)),
            child: Text(l10n.copyPath),
          ),
          FilledButton(
              onPressed: () => Navigator.pop(ctx), child: Text(l10n.ok)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
