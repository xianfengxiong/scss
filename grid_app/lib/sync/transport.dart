import 'dart:typed_data';

import '../model/tombstone.dart';
import 'protocol.dart';
import 'sync_endpoint.dart';

/// How the sync engine reaches the paired device. HTTP in production
/// ([HttpSyncTransport]); direct calls in tests ([InProcessTransport]) so
/// engine scenarios exercise the real endpoint semantics without sockets.
abstract class SyncTransport {
  Future<SyncManifest> fetchManifest();
  Future<Map<String, dynamic>?> fetchTemplate(String id);
  Future<Map<String, dynamic>?> fetchSurvey(String id);

  /// Push one object; false = the peer refused (its copy is newer).
  Future<bool> pushTemplate(Map<String, dynamic> json);
  Future<bool> pushSurvey(Map<String, dynamic> json);

  Future<void> pushTombstones(List<Tombstone> tombstones);
  Future<Uint8List?> fetchFile(String name);
  Future<void> pushFile(String name, Uint8List bytes);
}

/// A transport that *is* the other device: wraps its [SyncEndpoint] with no
/// wire in between.
class InProcessTransport implements SyncTransport {
  final SyncEndpoint endpoint;
  InProcessTransport(this.endpoint);

  @override
  Future<SyncManifest> fetchManifest() => endpoint.manifest();

  @override
  Future<Map<String, dynamic>?> fetchTemplate(String id) =>
      endpoint.getTemplate(id);

  @override
  Future<Map<String, dynamic>?> fetchSurvey(String id) =>
      endpoint.getSurvey(id);

  @override
  Future<bool> pushTemplate(Map<String, dynamic> json) =>
      endpoint.putTemplate(json);

  @override
  Future<bool> pushSurvey(Map<String, dynamic> json) =>
      endpoint.putSurvey(json);

  @override
  Future<void> pushTombstones(List<Tombstone> tombstones) =>
      endpoint.applyTombstones(tombstones);

  @override
  Future<Uint8List?> fetchFile(String name) => endpoint.getFile(name);

  @override
  Future<void> pushFile(String name, Uint8List bytes) =>
      endpoint.putFile(name, bytes);
}
