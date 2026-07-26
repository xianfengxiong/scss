import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:scss_grid/sync/http_transport.dart';
import 'package:scss_grid/sync/sync_engine.dart';

/// An unreachable peer must fail with a readable SyncException within the
/// transport's own timeout — not hang "同步中…" until the OS TCP timeout
/// (review finding, 2026-07-26).
void main() {
  test('ping against a silent peer times out with a readable error', () {
    fakeAsync((async) {
      // A handler that never answers — models a black-holed address.
      final client =
          MockClient((request) => Completer<http.Response>().future);
      final transport = HttpSyncTransport(
        base: Uri.parse('http://192.0.2.1:17423'),
        token: '123456',
        client: client,
      );

      Object? caught;
      transport.ping().then<void>((_) {}).catchError((Object e) {
        caught = e;
      });

      async.elapse(const Duration(seconds: 4));
      expect(caught, isNull, reason: 'not yet — ping allows 5s');
      async.elapse(const Duration(seconds: 2));
      expect(caught, isA<SyncException>());
      expect(caught.toString(), contains('超时'));
    });
  });

  test('data fetches also time out (20s budget)', () {
    fakeAsync((async) {
      final client =
          MockClient((request) => Completer<http.Response>().future);
      final transport = HttpSyncTransport(
        base: Uri.parse('http://192.0.2.1:17423'),
        token: '123456',
        client: client,
      );

      Object? caught;
      transport.fetchManifest().then<void>((_) {}).catchError((Object e) {
        caught = e;
      });

      async.elapse(const Duration(seconds: 21));
      expect(caught, isA<SyncException>());
    });
  });
}
