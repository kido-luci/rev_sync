# rev_sync

A reusable, **pure-Dart** offline-first sync engine. No Flutter, no Dio, no
database dependency — transport and storage stay behind small contracts you
implement, so the reconciliation logic is fully unit-testable in isolation.

It syncs a local store with any backend over a **server revision (`rev`)**
cursor: writes queue locally and push when online; reads pull deltas since the
last applied revision. Conflicts and lost updates are detected, not silently
dropped.

## Install

```yaml
dependencies:
  rev_sync: ^1.0.0
```

## The pieces

- **`SyncScheduler`** — the cross-cutting machinery every synced resource
  shares: connectivity-driven triggers (via `ConnectivitySource`), an
  offline→online re-sync, single-flight (concurrent `sync()` calls share one
  run), a start/stop generation guard, exponential-backoff retry, and a
  `SyncStatus` stream. It runs any `Future<SyncOutcome> Function()` body.
- **`OfflineCrudSync<T>`** — the generic CRUD body: an outbox push-queue
  followed by a delta pull, keyed on the `rev` as both the delta cursor and the
  optimistic-concurrency token. Push classifies outcomes (applied / superseded /
  conflict / gone) and retryable-vs-terminal failures, and guards against lost
  updates. Pull is delta-based and applies tombstones explicitly — deletes are
  never inferred from absence.

## What you implement

| Contract | Responsibility |
| --- | --- |
| `Syncable` | The row: `uuid`, `updatedAt`, `rev`, `syncState`. |
| `SyncLocalStore<T>` | The local database (list pending, get/put/hardDelete). |
| `SyncRemoteAdapter<T>` | DTO mapping + HTTP-error translation per resource. |
| `SyncCursorStore` | The persisted per-resource delta cursor. |
| `ConnectivitySource` | A minimal online/offline signal. |

## Usage

```dart
import 'package:rev_sync/rev_sync.dart';

// Compose the CRUD body, then drive it with a scheduler.
final sync = OfflineCrudSync<Note>(localStore, remoteAdapter, cursorStore);
final scheduler = SyncScheduler(sync.run, connectivity);

scheduler.statusStream.listen((status) => /* update a UI indicator */);
await scheduler.start(); // initial sync + react to connectivity
```

See [`example/rev_sync_example.dart`](example/rev_sync_example.dart) for a
complete, runnable wiring against in-memory implementations of all five
contracts.

## How conflicts are handled

- **Push** echoes each row's base `rev`. The adapter turns the server response
  into a `PushResult`: `PushApplied` (accepted), `PushSuperseded` (a retried
  create the server already has), `PushConflict` (the server moved past the base
  rev), or `PushGone` (the row no longer exists). Transient failures keep the row
  pending for retry; terminal failures mark it `failed`.
- **Pull** reconciles by `uuid`. A synced row takes the server's values when the
  server `rev` is higher (last-write-wins). An unsynced local edit wins until
  pushed — unless the server has moved past the rev it was based on, which is
  surfaced as `conflicted` for the app to resolve.

## Tests

```bash
dart test
```

Covers the scheduler (single-flight, offline→online, backoff, the generation
guard) and `OfflineCrudSync` (push outcomes, the lost-update guard,
delta/tombstone/conflict reconciliation) with in-memory fakes — no network or
database required.
