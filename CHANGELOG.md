# Changelog

## 1.0.2

Documentation only; no behavioural change.

- `SyncRemoteAdapter.listSince` now documents its **completeness** contract:
  it must return every record (including tombstones) with `rev` greater than the
  cursor. Order is irrelevant — the engine advances the cursor to the highest
  `rev` returned — so omitting a lower-`rev` record drops it permanently.
- `SyncScheduler` now documents that one instance must own a resource's sync
  state: concurrent schedulers over the same store and adapter are unsupported.

## 1.0.1

Shorten `pubspec.yaml` description to meet pub.dev's 60–180 character limit.

## 1.0.0

Initial release.

A pure-Dart, offline-first sync engine — backend- and store-agnostic:

- **`SyncScheduler`** — connectivity-driven triggers, an offline→online re-sync,
  single-flight runs, a start/stop generation guard, exponential-backoff retry,
  and a `SyncStatus` stream. Runs any `Future<SyncOutcome> Function()` body.
- **`OfflineCrudSync<T>`** — a generic outbox push-queue followed by a delta
  pull, keyed on the server **revision (`rev`)** as both the delta cursor and the
  optimistic-concurrency token. Classifies push outcomes (applied / superseded /
  conflict / gone), distinguishes retryable from terminal failures, guards
  against lost updates, and applies deletes as explicit tombstones.
- **Contracts** you implement: `Syncable`, `SyncLocalStore<T>`,
  `SyncRemoteAdapter<T>`, `SyncCursorStore`, and `ConnectivitySource`.
