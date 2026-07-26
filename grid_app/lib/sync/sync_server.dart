import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

import '../model/tombstone.dart';
import 'media_file_store.dart';
import 'protocol.dart';
import 'sync_endpoint.dart';

/// Shelf skin over [SyncEndpoint]: the desktop runs this; the phone's
/// [HttpSyncTransport] calls it. Every route (including /ping, which doubles
/// as the pairing-code check) requires the shared token.
///
/// Routes:
///   GET  /ping                 → {app, protocolVersion, deviceName}
///   GET  /manifest             → SyncManifest
///   GET  /templates/`id`       → template JSON | 404
///   PUT  /templates/`id`       → 204 | 409 (ours is newer)
///   GET  /surveys/`id`         → survey JSON | 404
///   PUT  /surveys/`id`         → 204 | 409
///   POST /tombstones           → 204 (applies peer deletions)
///   GET  /files/`name`         → bytes | 404
///   PUT  /files/`name`         → 204
class SyncServer {
  final SyncEndpoint endpoint;
  final String token;

  HttpServer? _server;

  SyncServer({required this.endpoint, required this.token});

  bool get running => _server != null;
  int? get port => _server?.port;

  /// Bind on all interfaces so the phone can reach us over the LAN.
  Future<int> start({int port = syncDefaultPort}) async {
    final server =
        await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
    _server = server;
    return server.port;
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  Handler get handler => _auth(_route);

  Handler _auth(Handler inner) => (request) {
        if (request.headers['x-sync-token'] != token) {
          return Response(401, body: 'bad token');
        }
        return inner(request);
      };

  Future<Response> _route(Request request) async {
    final parts = request.url.pathSegments;
    try {
      if (request.method == 'GET' && _is(parts, ['ping'])) {
        return _json({
          'app': 'scss_grid',
          'protocolVersion': syncProtocolVersion,
          'deviceName': endpoint.deviceName,
        });
      }
      if (request.method == 'GET' && _is(parts, ['manifest'])) {
        return _json((await endpoint.manifest()).toJson());
      }
      if (parts.length == 2 && parts[0] == 'templates') {
        final id = parts[1];
        if (request.method == 'GET') {
          final json = await endpoint.getTemplate(id);
          return json == null ? Response.notFound('') : _json(json);
        }
        if (request.method == 'PUT') {
          final ok = await endpoint.putTemplate(await _body(request));
          return Response(ok ? 204 : 409);
        }
      }
      if (parts.length == 2 && parts[0] == 'surveys') {
        final id = parts[1];
        if (request.method == 'GET') {
          final json = await endpoint.getSurvey(id);
          return json == null ? Response.notFound('') : _json(json);
        }
        if (request.method == 'PUT') {
          final ok = await endpoint.putSurvey(await _body(request));
          return Response(ok ? 204 : 409);
        }
      }
      if (request.method == 'POST' && _is(parts, ['tombstones'])) {
        final list = jsonDecode(await request.readAsString()) as List;
        await endpoint.applyTombstones([
          for (final e in list) Tombstone.fromJson(e as Map<String, dynamic>)
        ]);
        return Response(204);
      }
      if (parts.length == 2 && parts[0] == 'files') {
        final name = parts[1];
        if (!isSafeFileName(name)) return Response(400, body: 'bad name');
        if (request.method == 'GET') {
          final bytes = await endpoint.getFile(name);
          return bytes == null
              ? Response.notFound('')
              : Response.ok(bytes,
                  headers: {'content-type': 'application/octet-stream'});
        }
        if (request.method == 'PUT') {
          final bytes = await _bytes(request);
          await endpoint.putFile(name, bytes);
          return Response(204);
        }
      }
      return Response.notFound('');
    } catch (e) {
      return Response.internalServerError(body: 'sync error: $e');
    }
  }

  static bool _is(List<String> parts, List<String> want) =>
      parts.length == want.length &&
      [for (var i = 0; i < parts.length; i++) parts[i] == want[i]]
          .every((x) => x);

  static Response _json(Map<String, dynamic> body) => Response.ok(
      jsonEncode(body),
      headers: {'content-type': 'application/json'});

  static Future<Map<String, dynamic>> _body(Request request) async =>
      jsonDecode(await request.readAsString()) as Map<String, dynamic>;

  static Future<Uint8List> _bytes(Request request) async {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in request.read()) {
      builder.add(chunk);
    }
    return builder.takeBytes();
  }
}
