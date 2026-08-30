/**
 * How strong an answer is. `Partial` and `Local` both come out of local
 * storage and differ only in whether it could certify the answer was the
 * whole answer. `Fresh` means authoritative as of now — not "from the
 * network": a synchronized local store is entitled to say it.
 *
 * A query climbs `Partial -> Fresh -> Local -> Fresh`. Only `tick` lowers a
 * claim, as data ages.
 */
type claim = TiliaQuerySchema.claim =
  | @as("partial") Partial
  | @as("local") Local
  | @as("fresh") Fresh

/**
 * Why there is nothing to show. A value, not a sentence: each is a different
 * affordance, and only `Failed` carries prose — the adaptor's.
 *
 * `NoMatch` says the answer set was empty, never that the row does not
 * exist. It carries its claim because an absence ages like any other answer.
 */
@tag("reason")
type reason = TiliaQuerySchema.reason =
  | @as("failed") Failed({message: string})
  | @as("offline") Offline
  | @as("noMatch") NoMatch({claim: claim})

/**
 * A value as seen by the read path: wait, render, or explain.
 *
 * `claim` is a field rather than a constructor so the common case — render
 * whatever we have — does not grow a branch.
 *
 * An empty `Partial` is not a result. It reads as `Loading` while a remote
 * answer is still possible and `NoData({Offline})` otherwise. `array` on a
 * complete but empty query stays `Loaded({data: []})`: an empty list is data.
 * Only `one` projects it into `NoMatch`.
 */
@tag("state")
type loadable<'a> = TiliaQuerySchema.loadable<'a> =
  | @as("loading") Loading
  | @as("loaded") Loaded({claim: claim, data: 'a})
  | @as("noData") NoData({reason: reason})

/**
 * An outbox operation: a local change not yet confirmed by the remote.
 * Removes carry only the id — a remove never requires a full value.
 */
@tag("op")
type op<'a> = TiliaQueryStore.op<'a> =
  | @as("upsert") Upsert({value: 'a})
  | @as("remove") Remove({id: string})

/**
 * Context for an optimistic operation that was reverted.
 *
 * `edited` is the latest local edit, `base` the value it started from
 * (or the removed value). Failed variants carry the remote's `message`.
 * The current remote value is already in memory.
 *
 * Both are snapshots, copied through JSON when the operation was refused:
 * the row moves on, the record does not.
 */
@tag("rejection")
type rejection<'a> = TiliaQueryStore.rejection<'a> =
  | @as("createConflict") CreateConflict({edited: 'a})
  | @as("createFailed") CreateFailed({edited: 'a, message: string})
  | @as("updateConflict") UpdateConflict({base: 'a, edited: 'a})
  | @as("updateFailed") UpdateFailed({base: 'a, edited: 'a, message: string})
  | @as("removeConflict") RemoveConflict({base: 'a})
  | @as("removeFailed") RemoveFailed({base: 'a, message: string})

/**
 * Local context presented when a remote value arrives. `Clean` carries the
 * current value; the other variants name their payloads like `rejection`.
 */
@tag("change")
type change<'a> = TiliaQueryStore.change<'a> =
  | @as("clean") Clean({value: 'a})
  | @as("created") Created({edited: 'a})
  | @as("updated") Updated({base: 'a, edited: 'a})
  | @as("removed") Removed({base: 'a})

/**
 * The vocabulary a store answers in: `read` is what a remote may say,
 * `local` what storage may say, `find` the whole of it, and `write` how a
 * push is answered. Defined, and documented, in `TiliaQuerySchema`.
 */
module Channel = TiliaQuerySchema.Channel

type expiry = TiliaQuerySchema.expiry = {
  /** Refresh interval for observed non-live queries. Default: 30 s. */
  refresh: float,
  /**
   * How long an unobserved query stays in memory. Eviction closes its fetch
   * but leaves local data intact. Default: 5 min.
   */
  memory: float,
  /** Local query retention since its last refresh. Default: 30 days. */
  local: float,
}

/**
 * Reactive write state. Read failures are returned through
 * `loadable.NoData({Failed})`.
 */
type status<'a> = TiliaQueryStore.status<'a> = {
  /** Number of ops waiting in the outbox. */
  pending: int,
  /**
   * Contexts for reverted conflicts and definitively rejected writes, in
   * outbox order whatever order the replies arrived in: a cascade is refused
   * cause-first, so working down the list retries the cause before the
   * consequence. At most one rejection per id, and writing to an id clears
   * the one it had.
   */
  rejected: array<rejection<'a>>,
}

/** Remote adaptor: the authoritative store behind the network. */
type remote<'query, 'a> = TiliaQueryStore.remote<'query, 'a> = {
  /**
   * App-owned connectivity signal. Update `online.value` as connectivity
   * changes; pending ops are pushed only while online.
   */
  online: Tilia.signal<bool>,
  /**
   * Fetch a query's complete result set. Use `fresh` for periodically
   * refreshed results or `live` for a source that keeps itself fresh.
   */
  fetch: ('query, Channel.read<'a>) => unit,
  /**
   * Push an ordered batch of pending ops. Confirm each op through the
   * channel, or report a transient or definitive failure.
   */
  push: (array<op<'a>>, Channel.write<'a>) => unit,
}

/**
 * Local adaptor: a typed values table (`push`, `fetch`) plus a string KV
 * for engine bookkeeping (`set`, `get`). Persistence is command-only;
 * local storage errors are handled by the adaptor.
 */
type local<'query, 'a> = TiliaQueryStore.local<'query, 'a> = {
  /** Fetch cached results through the local channel. */
  fetch: ('query, Channel.local<'a>) => unit,
  /** Apply value changes to the values table in order. */
  push: array<op<'a>> => unit,
  /** Store an engine bookkeeping entry by tag and key; `None` deletes. */
  set: (~tag: string, ~key: string, option<string>) => unit,
  /**
   * Read one entry by key, or every entry for the tag when omitted.
   * Reply through `set` — synchronously or later, like everything else.
   */
  get: (~tag: string, ~key: string=?, ~set: array<string> => unit) => unit,
  /** Reply through `set` with every row id in the values table. */
  ids: (~set: array<string> => unit) => unit,
}

/** Configuration for `make`. */
type config<'query, 'a> = {
  /** Return a unique id for a given value. */
  id: 'a => string,
  /** Return true if a given value matches a given query. */
  matches: ('query, 'a) => bool,
  remote: remote<'query, 'a>,
  local?: local<'query, 'a>,
  expiry?: expiry,
  /** Return the current time in milliseconds. */
  now?: unit => float,
  /** Return a unique key for a given query. */
  key?: 'query => string,
  /** Return a sort function for a given query. */
  sort?: 'query => array<'a> => array<'a>,
  /**
   * Merge a remote value into the local value in place. Runs inside
   * `Tilia.batch`. Return true when merged; false records the corresponding
   * conflict and keeps the remote value.
   */
  merge?: (~change: change<'a>, ~remote: 'a) => bool,
  /**
   * A find failed and the read site will not be told, because it still has
   * something to show. Refresh failures land here; a first failure, with
   * nothing behind it, reaches the read site as `NoData({Failed})` instead.
   *
   * There is no error field on `Loaded`: an adaptor can log every failure
   * itself, but it cannot know whether the engine had rows to keep.
   */
  onError?: (~query: 'query, ~message: string) => unit,
}

/**
 * Facts pushed by the remote, such as websocket deliveries. Changed values
 * join and leave matching queries. Remote values are merged with pending
 * changes and win on conflict. Deliveries do not affect query freshness.
 */
type receive<'a> = TiliaQueryStore.receive<'a> = {
  /** These values changed on the server; they replace local clean copies. */
  changed: array<'a> => unit,
  /** These ids were deleted on the server. Ids, never full values. */
  removed: array<string> => unit,
}

/** Debug view: which query keys are observed (live) vs cached (idle). */
type canopy = TiliaQueryEngine.canopy = {
  live: array<string>,
  idle: array<string>,
}

type t<'query, 'a> = {
  /**
   * Read the first result of a query (first per `sort`). Returns `NotFound`
   * when the fetch completes empty. Reactive.
   */
  one: 'query => loadable<'a>,
  /** Read a query's results. Reactive. */
  array: 'query => loadable<array<'a>>,
  /**
   * Optimistically write a value, update matching in-memory queries, and
   * queue the op for remote push.
   */
  upsert: 'a => unit,
  /** Optimistically remove a value by id and queue the op for remote push. */
  remove: string => unit,
  /** Inbound push from server subscriptions. */
  receive: receive<'a>,
  /** Reactive sync state (tilia object). */
  status: status<'a>,
  /**
   * Queue the refused work again and drop the rejection. The edit is
   * re-applied as an ordinary optimistic write, so its change is computed
   * against the value that stands now rather than the one it was refused
   * against. The work is queued as a copy, so the record stays history even
   * once the row it describes is back in play. Acts only on the exact record
   * it is handed: a rejection already replaced or cleared is a no-op.
   */
  retry: rejection<'a> => unit,
  /** Drop a rejection without retrying it. Same exact-record rule as `retry`. */
  discard: rejection<'a> => unit,
  /**
   * Time heartbeat. The engine owns no timers: refresh, expiry, gc and
   * push retries happen here. Call it at least twice per refresh interval.
   */
  tick: unit => unit,
  /**
   * Stop watching remote connectivity and close every open fetch: each
   * registered `finally` teardown (live subscriptions) runs. Cached data is
   * left to normal expiry. Safe to call more than once.
   */
  dispose: unit => unit,
  /** Internal/debug: observed vs idle query keys. */
  _canopy: unit => canopy,
}

/**
 * Deterministic JSON serialization (sorted keys); the default `key`.
 * Only meaningful on plain data — no functions, no cycles.
 */
let sortedStringify: 'a => string

/**
 * Build the engine. Values and queries are held in plain JavaScript
 * objects and absence is read as `undefined`, so a value or a query must
 * never be `null` or `undefined` itself.
 *
 * A value must also survive a JSON round trip unchanged: no functions, no
 * cycles, no class instances, nothing whose identity carries meaning. A
 * `local` adaptor needs it, and so does every rejection — the record is
 * copied through JSON whether or not persistence is configured.
 */
let make: config<'query, 'a> => t<'query, 'a>
