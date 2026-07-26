import 'dart:io';

import 'package:flutter/material.dart';

import '../data/survey_store.dart';
import '../l10n/app_localizations.dart';
import '../data/sync_meta_store.dart';
import '../data/template_store.dart';
import 'media_file_store.dart';
import 'protocol.dart';
import 'sync_endpoint.dart';
import 'sync_identity.dart';
import 'sync_server.dart';

/// Desktop side of LAN sync: runs the sync server while this screen is open
/// and shows what the phone needs to connect — the machine's LAN address(es)
/// and the pairing code. Closing the screen stops the server.
class SyncHostScreen extends StatefulWidget {
  final TemplateStore templates;
  final SurveyStore surveys;
  final SyncMetaStore meta;
  final MediaFileStore files;

  /// Tests pass 0 for an OS-assigned port.
  final int port;

  const SyncHostScreen({
    super.key,
    required this.templates,
    required this.surveys,
    required this.meta,
    required this.files,
    this.port = syncDefaultPort,
  });

  @override
  State<SyncHostScreen> createState() => _SyncHostScreenState();
}

class _SyncHostScreenState extends State<SyncHostScreen> {
  SyncServer? _server;
  String? _token;
  List<String> _addresses = const [];
  int? _boundPort;
  String? _error;
  final List<String> _activity = [];

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _server?.stop();
    super.dispose();
  }

  Future<void> _start() async {
    try {
      final token = await ensureSyncToken(widget.meta);
      final interfaces = await NetworkInterface.list(
          type: InternetAddressType.IPv4, includeLoopback: false);
      final server = SyncServer(
        endpoint: SyncEndpoint(
          templates: widget.templates,
          surveys: widget.surveys,
          meta: widget.meta,
          files: widget.files,
          deviceName: Platform.localHostname,
        ),
        token: token,
        onActivity: (line) {
          if (!mounted) return;
          setState(() {
            _activity.insert(0, line);
            if (_activity.length > 200) _activity.removeLast();
          });
        },
      );
      final port = await server.start(port: widget.port);
      if (!mounted) {
        await server.stop();
        return;
      }
      setState(() {
        _server = server;
        _token = token;
        _boundPort = port;
        _addresses = [
          for (final i in interfaces)
            for (final a in i.addresses) a.address
        ];
      });
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        setState(() => _error = l10n.syncServerStartFailed(e.toString()));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.syncHostTitle)),
      body: _error != null
          ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
          : _server == null
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.syncHostIntro),
                      const SizedBox(height: 16),
                      Text(l10n.thisMachineAddress,
                          style: theme.textTheme.labelLarge),
                      for (final a in _addresses)
                        SelectableText(
                          '$a:$_boundPort',
                          key: ValueKey('sync-host-address-$a'),
                          style: theme.textTheme.headlineSmall,
                        ),
                      if (_addresses.isEmpty) Text(l10n.noLanAddress),
                      const SizedBox(height: 16),
                      Text(l10n.pairingCode, style: theme.textTheme.labelLarge),
                      SelectableText(
                        _token ?? '',
                        key: const ValueKey('sync-host-token'),
                        style: theme.textTheme.displayMedium
                            ?.copyWith(letterSpacing: 8),
                      ),
                      const SizedBox(height: 16),
                      Row(children: [
                        const Icon(Icons.circle, color: Colors.green, size: 12),
                        const SizedBox(width: 8),
                        // Expanded so the (long) English line wraps instead
                        // of overflowing a narrow window.
                        Expanded(child: Text(l10n.serverRunning(_boundPort!))),
                      ]),
                      const Divider(height: 32),
                      Text(l10n.activityLog, style: theme.textTheme.labelLarge),
                      Expanded(
                        child: _activity.isEmpty
                            ? Center(child: Text(l10n.waitingForPhone))
                            : ListView.builder(
                                itemCount: _activity.length,
                                itemBuilder: (_, i) => Text(
                                  _activity[i],
                                  style: theme.textTheme.bodySmall
                                      ?.copyWith(fontFamily: 'monospace'),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
