import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/sync/merge.dart';

void main() {
  final t1 = DateTime(2026, 7, 1);
  final t2 = DateTime(2026, 7, 2);

  group('decideMerge', () {
    test('both absent → none', () {
      expect(decideMerge(), MergeAction.none);
    });

    test('only local object → push', () {
      expect(decideMerge(localUpdated: t1), MergeAction.pushObject);
    });

    test('only remote object → pull', () {
      expect(decideMerge(remoteUpdated: t1), MergeAction.pullObject);
    });

    test('both alive, remote newer → pull', () {
      expect(decideMerge(localUpdated: t1, remoteUpdated: t2),
          MergeAction.pullObject);
    });

    test('both alive, local newer → push', () {
      expect(decideMerge(localUpdated: t2, remoteUpdated: t1),
          MergeAction.pushObject);
    });

    test('both alive, same timestamp → none', () {
      expect(decideMerge(localUpdated: t1, remoteUpdated: t1),
          MergeAction.none);
    });

    test('legacy objects without timestamps on both sides → none', () {
      // Missing updatedAt sorts as epoch on both sides — a tie.
      expect(
          decideMerge(
              localUpdated: DateTime.fromMillisecondsSinceEpoch(0),
              remoteUpdated: DateTime.fromMillisecondsSinceEpoch(0)),
          MergeAction.none);
    });

    test('remote tombstone newer than local object → delete local', () {
      expect(decideMerge(localUpdated: t1, remoteDeleted: t2),
          MergeAction.deleteLocal);
    });

    test('local object newer than remote tombstone → push (resurrect)', () {
      expect(decideMerge(localUpdated: t2, remoteDeleted: t1),
          MergeAction.pushObject);
    });

    test('local tombstone newer than remote object → delete remote', () {
      expect(decideMerge(localDeleted: t2, remoteUpdated: t1),
          MergeAction.deleteRemote);
    });

    test('remote object newer than local tombstone → pull (resurrect)', () {
      expect(decideMerge(localDeleted: t1, remoteUpdated: t2),
          MergeAction.pullObject);
    });

    test('object/tombstone tie keeps the object', () {
      expect(decideMerge(localUpdated: t1, remoteDeleted: t1),
          MergeAction.pushObject);
      expect(decideMerge(localDeleted: t1, remoteUpdated: t1),
          MergeAction.pullObject);
    });

    test('both deleted → none', () {
      expect(decideMerge(localDeleted: t1, remoteDeleted: t2),
          MergeAction.none);
    });

    test('tombstone on one side only, object absent both → none', () {
      expect(decideMerge(localDeleted: t1), MergeAction.none);
      expect(decideMerge(remoteDeleted: t1), MergeAction.none);
    });

    test('defensive: side with both object and newer tombstone counts as dead',
        () {
      // Should not happen (stores keep them exclusive) but must not crash:
      // local is dead at t2, remote alive at t1 → the deletion wins.
      expect(
          decideMerge(localUpdated: t1, localDeleted: t2, remoteUpdated: t1),
          MergeAction.deleteRemote);
    });
  });
}
