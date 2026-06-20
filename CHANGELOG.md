# Changelog

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
