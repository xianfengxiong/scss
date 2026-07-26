import 'package:flutter/material.dart';

import '../data/survey_store.dart';
import '../data/sync_meta_store.dart';
import '../data/template_store.dart';
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
    final transport = HttpSyncTransport(
      base: Uri.parse('http://$host:$port'),
      token: token,
    );
    try {
      onProgress('连接 $host:$port…');
      await transport.ping();
      final engine = SyncEngine(
        templates: widget.templates,
        surveys: widget.surveys,
        meta: widget.meta,
        files: widget.files,
      );
      return await engine.run(transport, onProgress: onProgress);
    } finally {
      transport.close();
    }
  }

  Future<void> _sync() async {
    final rawHost = _hostController.text.trim();
    final token = _tokenController.text.trim();
    if (rawHost.isEmpty || token.isEmpty) {
      setState(() {
        _failed = true;
        _result = '请填写电脑地址和配对码';
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
      _status = '开始同步…';
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
        _result = syncReportSummary(report);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = null;
        _failed = true;
        _result = '同步失败:$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('同步')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('在电脑上打开「同步」页面,然后填入其显示的地址和配对码。'
                '首次成功后会自动记住。'),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('sync-host-field'),
              controller: _hostController,
              enabled: !_busy,
              decoration: const InputDecoration(
                labelText: '电脑地址',
                hintText: '例如 192.168.1.5',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('sync-token-field'),
              controller: _tokenController,
              enabled: !_busy,
              decoration: const InputDecoration(
                labelText: '配对码',
                border: OutlineInputBorder(),
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
              label: Text(_busy ? '同步中…' : '开始同步'),
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
String syncReportSummary(SyncReport r) {
  if (r.isEmpty) return '已是最新,无需同步';
  final parts = <String>[
    if (r.pulledTemplates > 0) '拉取模版 ${r.pulledTemplates}',
    if (r.pushedTemplates > 0) '推送模版 ${r.pushedTemplates}',
    if (r.pulledSurveys > 0) '拉取调查表 ${r.pulledSurveys}',
    if (r.pushedSurveys > 0) '推送调查表 ${r.pushedSurveys}',
    if (r.filesPulled + r.filesPushed > 0)
      '传输图片 ${r.filesPulled + r.filesPushed}',
    if (r.deletedLocal + r.deletedRemote > 0)
      '同步删除 ${r.deletedLocal + r.deletedRemote}',
  ];
  return '同步完成:${parts.join(' · ')}';
}
