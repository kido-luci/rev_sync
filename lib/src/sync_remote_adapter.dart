import 'remote_record.dart';
import 'syncable.dart';

/// The server side of one synced resource, implemented per feature.
///
/// The adapter is the only place that knows the wire format: it maps the
/// feature's DTOs to [RemoteRecord]s and translates transport errors into the
/// engine's vocabulary — returning a [PushResult] for outcomes the engine acts
/// on (conflict, gone, superseded) and throwing [SyncTransientException] /
/// [SyncTerminalException] for retryable / non-retryable failures.
abstract interface class SyncRemoteAdapter<T extends Syncable> {
  /// A stable key naming this resource (e.g. `'bookmarks'`), used for the delta
  /// cursor.
  String get resource;

  /// Optional pre-push step, e.g. upload local media and persist the resulting
  /// URLs back onto [row] before it is sent. Defaults to a no-op.
  Future<void> beforePush(T row) async {}

  /// POSTs a locally-created [row].
  Future<PushResult<T>> create(T row);

  /// PUTs a locally-edited [row], echoing its base revision for conflict
  /// detection.
  Future<PushResult<T>> update(T row);

  /// DELETEs a locally-tombstoned [row], echoing its base revision.
  Future<PushResult<T>> delete(T row);

  /// Fetches server changes with a revision greater than [cursor], as
  /// [RemoteRecord]s.
  ///
  /// Must be **complete**: return *every* record (including tombstones) whose
  /// `rev` is greater than [cursor]. Order does not matter — the engine advances
  /// the cursor to the highest `rev` among the returned records, then requests
  /// changes above that on the next pull. So omitting a record whose `rev` sits
  /// below another returned record's `rev` drops it permanently: the cursor
  /// moves past it and no later pull will ever ask for it again.
  Future<List<RemoteRecord<T>>> listSince(int cursor);
}
