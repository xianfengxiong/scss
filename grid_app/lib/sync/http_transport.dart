import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../l10n/app_localizations.dart';
import '../l10n/app_localizations_en.dart';
import '../model/tombstone.dart';
import 'protocol.dart';
import 'sync_engine.dart';
import 'transport.dart';

/// [SyncTransport] over HTTP: what the phone uses to reach the desktop's
/// [SyncServer]. `base` is e.g. `http://192.168.1.5:17423`.
///
/// Every request has a timeout: an unreachable peer (desktop changed IP,
/// firewall black-holes packets, Wi-Fi dropped mid-transfer) must surface as
/// a readable error, not leave the sync screen stuck on "同步中…" until the
/// OS-level TCP timeout minutes later.
class HttpSyncTransport implements SyncTransport {
  static const _pingTimeout = Duration(seconds: 5);
  static const _jsonTimeout = Duration(seconds: 20);
  static const _fileTimeout = Duration(seconds: 60);

  final Uri base;
  final String token;
  final http.Client _client;

  /// User-facing error strings; English when not injected (tests).
  final AppLocalizations l10n;

  HttpSyncTransport({required this.base, required this.token,
      http.Client? client, AppLocalizations? l10n})
      : _client = client ?? http.Client(),
        l10n = l10n ?? AppLocalizationsEn();

  Map<String, String> get _headers => {'x-sync-token': token};

  Future<http.Response> _timed(
          Future<http.Response> request, Duration limit, String what) =>
      request.timeout(limit,
          onTimeout: () => throw SyncException(l10n.requestTimeout(what)));

  /// Token/reachability check for the pairing screen: server metadata, or
  /// throws with a readable message.
  Future<Map<String, dynamic>> ping() async {
    final res = await _timed(
        _client.get(base.resolve('ping'), headers: _headers),
        _pingTimeout,
        l10n.reqConnect);
    _check(res, 'ping');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  @override
  Future<SyncManifest> fetchManifest() async {
    final res = await _timed(
        _client.get(base.resolve('manifest'), headers: _headers),
        _jsonTimeout,
        l10n.reqManifest);
    _check(res, 'manifest');
    return SyncManifest.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>);
  }

  @override
  Future<Map<String, dynamic>?> fetchTemplate(String id) =>
      _fetchJson('templates/$id');

  @override
  Future<Map<String, dynamic>?> fetchSurvey(String id) =>
      _fetchJson('surveys/$id');

  @override
  Future<bool> pushTemplate(Map<String, dynamic> json) =>
      _pushJson('templates/${json['id']}', json);

  @override
  Future<bool> pushSurvey(Map<String, dynamic> json) =>
      _pushJson('surveys/${json['id']}', json);

  @override
  Future<void> pushTombstones(List<Tombstone> tombstones) async {
    final res = await _timed(
        _client.post(base.resolve('tombstones'),
            headers: {..._headers, 'content-type': 'application/json'},
            body: jsonEncode([for (final t in tombstones) t.toJson()])),
        _jsonTimeout,
        l10n.reqTombstones);
    _check(res, 'tombstones');
  }

  @override
  Future<Uint8List?> fetchFile(String name) async {
    final res = await _timed(
        _client.get(base.resolve('files/$name'), headers: _headers),
        _fileTimeout,
        l10n.reqDownloadImage);
    if (res.statusCode == 404) return null;
    _check(res, 'file $name');
    return res.bodyBytes;
  }

  @override
  Future<void> pushFile(String name, Uint8List bytes) async {
    final res = await _timed(
        _client.put(base.resolve('files/$name'),
            headers: {..._headers, 'content-type': 'application/octet-stream'},
            body: bytes),
        _fileTimeout,
        l10n.reqUploadImage);
    _check(res, 'file $name');
  }

  void close() => _client.close();

  Future<Map<String, dynamic>?> _fetchJson(String path) async {
    final res = await _timed(
        _client.get(base.resolve(path), headers: _headers),
        _jsonTimeout,
        l10n.reqPull);
    if (res.statusCode == 404) return null;
    _check(res, path);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<bool> _pushJson(String path, Map<String, dynamic> json) async {
    final res = await _timed(
        _client.put(base.resolve(path),
            headers: {..._headers, 'content-type': 'application/json'},
            body: jsonEncode(json)),
        _jsonTimeout,
        l10n.reqPush);
    if (res.statusCode == 409) return false; // peer's copy is newer — fine
    _check(res, path);
    return true;
  }

  void _check(http.Response res, String what) {
    if (res.statusCode == 401) {
      throw SyncException(l10n.wrongPairingCode);
    }
    if (res.statusCode >= 300) {
      throw SyncException(l10n.requestFailed(what, res.statusCode));
    }
  }
}
