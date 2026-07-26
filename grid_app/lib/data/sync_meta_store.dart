import '../model/tombstone.dart';

/// Sync bookkeeping next to the two object stores: deletion tombstones (so a
/// delete propagates instead of the row resurrecting) and a small key/value
/// bag (device id, pairing info, sync token). Same test pattern as the object
/// stores: screens/engine depend on this, Drift and in-memory both implement.
abstract class SyncMetaStore {
  Future<void> addTombstone(Tombstone t);
  Future<void> removeTombstone(String kind, String id);
  Future<List<Tombstone>> tombstones();

  Future<String?> kvGet(String key);
  Future<void> kvSet(String key, String value);
}

class InMemorySyncMetaStore implements SyncMetaStore {
  final Map<String, Tombstone> _tombstones = {};
  final Map<String, String> _kv = {};

  static String _key(String kind, String id) => '$kind/$id';

  @override
  Future<void> addTombstone(Tombstone t) async {
    _tombstones[_key(t.kind, t.id)] = t;
  }

  @override
  Future<void> removeTombstone(String kind, String id) async {
    _tombstones.remove(_key(kind, id));
  }

  @override
  Future<List<Tombstone>> tombstones() async =>
      _tombstones.values.toList(growable: false);

  @override
  Future<String?> kvGet(String key) async => _kv[key];

  @override
  Future<void> kvSet(String key, String value) async {
    _kv[key] = value;
  }
}
