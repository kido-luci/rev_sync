// A self-contained, runnable example of rev_sync wired against in-memory
// implementations of its five contracts. Run with: `dart run example`.
// ignore_for_file: avoid_print

import 'package:rev_sync/rev_sync.dart';

/// A trivial synced row. A real app's row is usually its local-DB entity.
class Note implements Syncable {
  Note({
    required this.uuid,
    required this.text,
    this.rev = 0,
    this.syncState = SyncState.pendingCreate,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  @override
  final String uuid;
  String text;
  @override
  int rev;
  @override
  SyncState syncState;
  @override
  DateTime updatedAt;
}

/// An in-memory [SyncLocalStore] standing in for the local database.
class InMemoryStore implements SyncLocalStore<Note> {
  final _rows = <String, Note>{};

  void seed(Note note) => _rows[note.uuid] = note;

  @override
  Future<List<Note>> listPending() async =>
      _rows.values.where((r) => r.syncState.isPending).toList();

  @override
  Future<Note?> getByUuid(String uuid) async => _rows[uuid];

  @override
  Future<void> put(Note row) async => _rows[row.uuid] = row;

  @override
  Future<void> hardDelete(Note row) async => _rows.remove(row.uuid);
}

/// An in-memory [SyncCursorStore] for the per-resource delta cursor.
class InMemoryCursors implements SyncCursorStore {
  final _cursors = <String, int>{};

  @override
  Future<int> read(String resource) async => _cursors[resource] ?? 0;

  @override
  Future<void> write(String resource, int rev) async =>
      _cursors[resource] = rev;
}

/// A fake server: accepts every write and hands back an incrementing revision.
/// A real adapter maps DTOs and translates HTTP errors into [PushResult]s and
/// [SyncTransientException] / [SyncTerminalException].
class InMemoryRemote implements SyncRemoteAdapter<Note> {
  int _rev = 0;

  @override
  String get resource => 'notes';

  @override
  Future<void> beforePush(Note row) async {}

  @override
  Future<PushResult<Note>> create(Note row) async {
    final assigned = ++_rev;
    return PushApplied(
      RemoteRecord<Note>(
        uuid: row.uuid,
        rev: assigned,
        updatedAt: row.updatedAt,
        deleted: false,
        build: () => Note(
          uuid: row.uuid,
          text: row.text,
          rev: assigned,
          syncState: SyncState.synced,
          updatedAt: row.updatedAt,
        ),
        apply: (note) => note.text = row.text,
      ),
    );
  }

  @override
  Future<PushResult<Note>> update(Note row) async => create(row);

  @override
  Future<PushResult<Note>> delete(Note row) async {
    final assigned = ++_rev;
    return PushApplied(
      RemoteRecord<Note>(
        uuid: row.uuid,
        rev: assigned,
        updatedAt: row.updatedAt,
        deleted: true,
        build: () => row,
        apply: (_) {},
      ),
    );
  }

  @override
  Future<List<RemoteRecord<Note>>> listSince(int cursor) async => [];
}

/// A [ConnectivitySource] that is always online. A real app supplies a
/// `connectivity_plus`-backed implementation.
class AlwaysOnline implements ConnectivitySource {
  @override
  Future<bool> isOnline() async => true;

  @override
  Stream<bool> get onOnlineChanged => const Stream.empty();
}

Future<void> main() async {
  final store = InMemoryStore()..seed(Note(uuid: 'n1', text: 'Buy milk'));
  final sync = OfflineCrudSync<Note>(
    store,
    InMemoryRemote(),
    InMemoryCursors(),
  );

  // Option A — run the push/pull body once, directly.
  final outcome = await sync.run();
  final note = await store.getByUuid('n1');
  print('Outcome: $outcome'); // SyncOutcome.ok
  print('Note: rev=${note!.rev} state=${note.syncState}'); // rev=1 synced

  // Option B — let a scheduler drive it on connectivity, with backoff retry.
  final scheduler = SyncScheduler(sync.run, AlwaysOnline());
  final sub = scheduler.statusStream.listen((s) => print('Status: $s'));
  await scheduler.start();
  await scheduler.sync();
  await sub.cancel();
  await scheduler.dispose();
}
