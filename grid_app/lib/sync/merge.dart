/// Last-write-wins merge decision for one object id during a sync pass.
///
/// Sync is client-driven: "local" is the device running the engine, "remote"
/// its paired endpoint. Each side's latest event is either the object's
/// updatedAt (alive) or its tombstone's deletedAt (dead); the newer event
/// wins across sides. Clocks are assumed roughly in step (phone + desktop on
/// the same LAN); in practice each object is edited on one side only —
/// templates on desktop, surveys on phone — so real conflicts are rare.
enum MergeAction {
  /// Both sides agree (same event, both absent, or both deleted).
  none,

  /// Remote object is newer → copy remote to local.
  pullObject,

  /// Local object is newer → copy local to remote.
  pushObject,

  /// Remote tombstone is newer → delete locally, adopt the tombstone.
  deleteLocal,

  /// Local tombstone is newer → send it so the remote deletes.
  deleteRemote,
}

/// Timestamp callers substitute for an object that exists but was saved
/// before sync stamped updatedAt: it sorts before any real edit or deletion,
/// while still counting as present (null means absent).
final syncEpoch = DateTime.fromMillisecondsSinceEpoch(0);

MergeAction decideMerge({
  DateTime? localUpdated,
  DateTime? remoteUpdated,
  DateTime? localDeleted,
  DateTime? remoteDeleted,
}) {
  // Stores keep object and tombstone mutually exclusive per side; if both
  // ever appear (mid-sync race), the newer event represents the side.
  final localAlive = localUpdated != null &&
      (localDeleted == null || !localDeleted.isAfter(localUpdated));
  final remoteAlive = remoteUpdated != null &&
      (remoteDeleted == null || !remoteDeleted.isAfter(remoteUpdated));
  final localAt = localAlive ? localUpdated : localDeleted;
  final remoteAt = remoteAlive ? remoteUpdated : remoteDeleted;

  if (localAt == null && remoteAt == null) return MergeAction.none;

  // Present on one side only.
  if (remoteAt == null) {
    return localAlive ? MergeAction.pushObject : MergeAction.none;
  }
  if (localAt == null) {
    return remoteAlive ? MergeAction.pullObject : MergeAction.none;
  }

  if (localAlive && remoteAlive) {
    if (remoteAt.isAfter(localAt)) return MergeAction.pullObject;
    if (localAt.isAfter(remoteAt)) return MergeAction.pushObject;
    return MergeAction.none; // same timestamp → treat as identical
  }
  if (!localAlive && !remoteAlive) return MergeAction.none; // both deleted

  // Alive on one side, deleted on the other: newer event wins; a tie keeps
  // the object (deletion is the destructive choice).
  if (localAlive) {
    return remoteAt.isAfter(localAt) ? MergeAction.deleteLocal : MergeAction.pushObject;
  }
  return localAt.isAfter(remoteAt) ? MergeAction.deleteRemote : MergeAction.pullObject;
}
