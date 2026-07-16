/**
 * A value as seen by the read path.
 *
 * `Loaded.fresh` says whether the remote is known to be current.
 * `NotLocal` means no local answer is available while offline.
 * `Failed` carries the fetch error to the read site.
 */
@tag("state")
type loadable<'a> =
  | @as("loading") Loading
  | @as("loaded") Loaded({data: 'a, fresh: bool})
  | @as("notFound") NotFound
  | @as("notLocal") NotLocal
  | @as("failed") Failed({message: string})

/**
 * An outbox operation: a local change not yet confirmed by the remote.
 * Removes carry only the id — a remove never requires a full value.
 */
@tag("op")
type op<'a> =
  | @as("upsert") Upsert({value: 'a})
  | @as("remove") Remove({id: string})

/**
 * Context for an optimistic operation that was reverted.
 *
 * Create variants carry `edited`; update variants carry `base, edited`;
 * remove variants carry `base`. Failed variants end with `message`.
 * The current remote value is already in memory.
 */
type rejection<'a> =
  | CreateConflict('a)
  | CreateFailed('a, string)
  | UpdateConflict('a, 'a)
  | UpdateFailed('a, 'a, string)
  | RemoveConflict('a)
  | RemoveFailed('a, string)

/**
 * Local context presented when a remote value arrives. `Clean` carries the
 * current value; the other variants use the same tuple order as `rejection`.
 */
type change<'a> =
  | Clean('a)
  | Created('a)
  | Updated('a, 'a)
  | Removed('a)

module Channel: {
  /**
   * Read channel handed to `remote.fetch`.
   *
   * `set` publishes a complete result set, replacing the previous one.
   * `live` does the same and declares that the adaptor keeps the result
   * fresh, so periodic refresh is skipped.
   *
   * `fail` publishes a failed result without closing the fetch, allowing a
   * live source to recover. `end` closes the fetch and returns a live query
   * to periodic refresh.
   *
   * `finally` registers the fetch's teardown (e.g. unsubscribe a socket).
   * The last registered teardown runs once when the fetch closes. Callbacks
   * on a closed fetch are ignored.
   */
  type read<'a> = {
    set: array<'a> => unit,
    live: array<'a> => unit,
    fail: string => unit,
    end: unit => unit,
    finally: (unit => unit) => unit,
  }

  /**
   * Local fetch channel, handed to `local.fetch`.
   *
   * Answer with `set`, or call `unknown` when local storage cannot answer.
   */
  type local<'a> = {
    set: array<'a> => unit,
    unknown: unit => unit,
  }

  /**
   * Write channel, handed to `remote.push` together with a batch of ops.
   *
   * Confirm each upsert with its authoritative value through `set`, and
   * each remove by id through `removed`. `retry` keeps unconfirmed ops
   * pending; `fail` reverts them and adds rejection contexts.
   */
  type write<'a> = {
    set: 'a => unit,
    removed: string => unit,
    retry: unit => unit,
    fail: string => unit,
  }
}

/** Timing configuration in milliseconds. */
type expiry = {
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
 * Reactive write state. Read failures are returned through `loadable.Failed`.
 */
type status<'a> = {
  /** Number of ops waiting in the outbox. */
  pending: int,
  /** Contexts for reverted conflicts and definitively rejected writes. */
  rejected: array<rejection<'a>>,
}

/** Remote adaptor: the authoritative store behind the network. */
type remote<'query, 'a> = {
  /**
   * App-owned connectivity signal. Update `online.value` as connectivity
   * changes; pending ops are pushed only while online.
   */
  online: Tilia.signal<bool>,
  /**
   * Fetch a query's complete result set. Use `set` for periodically
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
type local<'query, 'a> = {
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
}

/**
 * Facts pushed by the remote, such as websocket deliveries. Changed values
 * join and leave matching queries. Remote values are merged with pending
 * changes and win on conflict. Deliveries do not affect query freshness.
 */
type receive<'a> = {
  /** These values changed on the server; they replace local clean copies. */
  changed: array<'a> => unit,
  /** These ids were deleted on the server. Ids, never full values. */
  removed: array<string> => unit,
}

/** Debug view: which query keys are observed (live) vs cached (idle). */
type canopy = {
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
  /** Remove a resolved or ignored rejection context. */
  dismiss: rejection<'a> => unit,
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

let make: config<'query, 'a> => t<'query, 'a>
