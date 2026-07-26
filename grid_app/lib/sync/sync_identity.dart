import 'dart:math';

import '../data/sync_meta_store.dart';

const _tokenKey = 'sync.token';
const _lastHostKey = 'sync.lastHost';
const _lastTokenKey = 'sync.lastToken';

/// This device's pairing code, created on first use and stable afterwards so
/// the phone only ever types it once. Six digits: easy to read off the
/// desktop screen, and the LAN + per-request token check is the actual gate.
Future<String> ensureSyncToken(SyncMetaStore meta) async {
  final existing = await meta.kvGet(_tokenKey);
  if (existing != null && existing.isNotEmpty) return existing;
  final rng = Random.secure();
  final token =
      List.generate(6, (_) => rng.nextInt(10).toString()).join();
  await meta.kvSet(_tokenKey, token);
  return token;
}

/// Pairing info the phone remembers after a successful sync, so later syncs
/// are one tap.
class SavedPairing {
  final String host;
  final String token;
  const SavedPairing({required this.host, required this.token});
}

Future<SavedPairing?> loadPairing(SyncMetaStore meta) async {
  final host = await meta.kvGet(_lastHostKey);
  final token = await meta.kvGet(_lastTokenKey);
  if (host == null || host.isEmpty || token == null || token.isEmpty) {
    return null;
  }
  return SavedPairing(host: host, token: token);
}

Future<void> savePairing(SyncMetaStore meta, SavedPairing p) async {
  await meta.kvSet(_lastHostKey, p.host);
  await meta.kvSet(_lastTokenKey, p.token);
}
