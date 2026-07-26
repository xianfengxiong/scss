import 'package:flutter/material.dart';

import '../data/survey_store.dart';
import '../data/sync_meta_store.dart';
import '../data/template_store.dart';
import '../l10n/app_localizations.dart';
import 'http_transport.dart';
import 'media_file_store.dart';
import 'protocol.dart';
import 'sync_engine.dart';
import 'sync_identity.dart';

/// Runs one sync pass against `host:port` with `token`, reporting progress.
/// Injected so widget tests swap in a fake instead of real sockets.
typedef SyncRunner = Future<SyncReport> Function(
  String host,
  int port,
  String token,
  void Function(String message) onProgress,
);

/// Phone side of LAN sync: enter the desktop's address + pairing code (both
/// remembered after the first success), then one tap syncs both ways.
class SyncClientScreen extends StatefulWidget {
  final TemplateStore templates;
  final SurveyStore surveys;
  final SyncMetaStore meta;
  final MediaFileStore files;

  /// Widget-test seam; null = real HTTP against the desktop server.
  final SyncRunner? runnerOverride;

  const SyncClientScreen({
    super.key,
    required this.templates,
    required this.surveys,
    required this.meta,
    required this.files,
    this.runnerOverride,
  });

  @override
  State<SyncClientScreen> createState() => _SyncClientScreenState();
}

class _SyncClientScreenState extends State<SyncClientScreen> {
  final _hostController = TextEditingController();
  final _tokenController = TextEditingController();
  bool _busy = false;
  String? _status;
  String? _result;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    loadPairing(widget.meta).then((p) {
      if (p == null || !mounted) return;
      setState(() {
        _hostController.text = p.host;
        _tokenController.text = p.token;
      });
    });
  }

  @override
  void dispose() {
    _hostController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  Future<SyncReport> _realRun(String host, int port, String token,
      void Function(String) onProgress) async {
    final l10n = AppLocalizations.of(context)!;
    final transport = HttpSyncTransport(
      base: Uri.parse('http://$host:$port'),
      token: token,
      l10n: l10n,
    );
    try {
      onProgress(l10n.connectingTo('$host:$port'));
      await transport.ping();
      final engine = SyncEngine(
        templates: widget.templates,
        surveys: widget.surveys,
        meta: widget.meta,
        files: widget.files,
        l10n: l10n,
      );
      return await engine.run(transport, onProgress: onProgress);
    } finally {
      transport.close();
    }
  }

  Future<void> _sync() async {
    final l10n = AppLocalizations.of(context)!;
    final rawHost = _hostController.text.trim();
    final token = _tokenController.text.trim();
    if (rawHost.isEmpty || token.isEmpty) {
      setState(() {
        _failed = true;
        _result = l10n.fillAddressAndCode;
      });
      return;
    }
    // Accept "192.168.1.5" or "192.168.1.5:17423".
    final colon = rawHost.lastIndexOf(':');
    final host = colon < 0 ? rawHost : rawHost.substring(0, colon);
    final port = colon < 0
        ? syncDefaultPort
        : int.tryParse(rawHost.substring(colon + 1)) ?? syncDefaultPort;

    setState(() {
      _busy = true;
      _failed = false;
      _result = null;
      _status = l10n.syncing;
    });
    try {
      final run = widget.runnerOverride ?? _realRun;
      final report = await run(host, port, token, (m) {
        if (mounted) setState(() => _status = m);
      });
      await savePairing(
          widget.meta, SavedPairing(host: rawHost, token: token));
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = null;
        _result = syncReportSummary(report, l10n);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = null;
        _failed = true;
        _result = l10n.syncFailedMsg(e.toString());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.sync)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.syncClientIntro),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('sync-host-field'),
              controller: _hostController,
              enabled: !_busy,
              decoration: InputDecoration(
                labelText: l10n.computerAddress,
                hintText: l10n.addressHint,
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('sync-token-field'),
              controller: _tokenController,
              enabled: !_busy,
              decoration: InputDecoration(
                labelText: l10n.pairingCode,
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const ValueKey('sync-start'),
              onPressed: _busy ? null : _sync,
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.sync),
              label: Text(_busy ? l10n.syncing : l10n.startSync),
            ),
            const SizedBox(height: 16),
            if (_status != null)
              Text(_status!, key: const ValueKey('sync-status')),
            if (_result != null)
              Card(
                color: _failed
                    ? Theme.of(context).colorScheme.errorContainer
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_result!, key: const ValueKey('sync-result')),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Human summary of a completed pass, e.g. "拉取模版 1 · 推送调查表 2 · 传输图片 3".
String syncReportSummary(SyncReport r, AppLocalizations l10n) {
  if (r.isEmpty) return l10n.upToDate;
  final parts = <String>[
    if (r.pulledTemplates > 0) l10n.pulledTemplatesN(r.pulledTemplates),
    if (r.pushedTemplates > 0) l10n.pushedTemplatesN(r.pushedTemplates),
    if (r.pulledSurveys > 0) l10n.pulledSurveysN(r.pulledSurveys),
    if (r.pushedSurveys > 0) l10n.pushedSurveysN(r.pushedSurveys),
    if (r.filesPulled + r.filesPushed > 0)
      l10n.filesTransferredN(r.filesPulled + r.filesPushed),
    if (r.deletedLocal + r.deletedRemote > 0)
      l10n.deletionsSyncedN(r.deletedLocal + r.deletedRemote),
  ];
  return l10n.syncDone(parts.join(' · '));
}
