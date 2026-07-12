// TYPES

/**
 * A value as seen by the read path.
 *
 * `Failed` carries the fetch error to the place where the value is read —
 * there is no global error slot to join against.
 */
@tag("state")
type loadable<'a> =
  | @as("loading") Loading
  | @as("loaded") Loaded({data: 'a})
  | @as("notFound") NotFound
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
 * An op the remote definitively refused. Keyed by `id`: at most one
 * rejection per id, a newer rejection replaces the older.
 */
type rejection<'a> = {
  /** The op's value id — the key `retry` / `discard` match on. */
  id: string,
  op: op<'a>,
  message: string,
}

module Channel = {
  /**
   * Read channel, handed to `remote.fetch` and `local.fetch`.
   *
   * `set` publishes the query's current, complete result set. It is the
   * idiomatic "I am keeping this value fresh" call: invoke it again whenever
   * fresher results arrive. Each call replaces the previous results for
   * this query.
   *
   * `live` declares that this channel keeps its result fresh on its own
   * (e.g. a server subscription): while the channel is open,
   * `expiry.refresh` skips this query. Each `set` still advances
   * freshness; when the channel ends — `fail` or the engine's cancel —
   * the query re-enters normal refresh. One-shot adaptors never call it
   * and get periodic refresh.
   *
   * `fail` is definitive: this fetch is dead. The first `fail` wins; after
   * it — or after the engine invokes the cancel function returned by
   * `fetch` — every callback on this channel is a noop. Calling `fail`
   * twice is an adaptor bug, but a harmless one.
   */
  type read<'a> = {
    set: array<'a> => unit,
    live: unit => unit,
    fail: string => unit,
  }

  /**
   * Write channel, handed to `remote.push` together with a batch of ops.
   *
   * `set` confirms an upsert: this value is now fresh on the remote. Pass
   * the authoritative value — echo the input, or the server-corrected /
   * conflict-resolved version. Whatever is set replaces the local value and
   * drops the op from the outbox. Call it once per confirmed upsert;
   * multiple calls (one per op in the batch) are the normal case.
   *
   * `removed` confirms a remove, by id.
   *
   * `retry` reports a transient failure (offline, timeout): every op not
   * yet confirmed stays pending and is pushed again on a later `tick` or
   * when `remote.online` flips back to true.
   *
   * `fail` is definitive: every op not yet confirmed becomes a rejection in
   * `status.rejected`. As on the read channel: first definitive call wins,
   * everything on the channel is a noop afterwards.
   */
  type write<'a> = {
    set: 'a => unit,
    removed: string => unit,
    retry: unit => unit,
    fail: string => unit,
  }
}

/**
 * Timing configuration. All values in milliseconds, but note the scales:
 * memory and local are different tiers, not different strictness. Memory
 * is a small RAM cache of the queries being (or recently) observed —
 * seconds to minutes. Local is the durable superset on disk — days to
 * weeks (long enough to come back from two weeks on a beach). 100 MB is
 * fine in local; it is not fine in memory.
 */
type expiry = {
  /**
   * Interval between refreshes for observed queries — except those whose
   * channel declared `live`. Default: 30_000 (30 s).
   */
  refresh?: float,
  /**
   * How long a stale (no longer observed) query result stays in RAM.
   * Eviction only frees memory — the data stays in the local store, and
   * reopening the query re-materializes it from there.
   * Default: 300_000 (5 min).
   */
  memory?: float,
  /**
   * How long a query is retained in the local store since its last
   * refresh. Days-to-weeks scale; local gc runs against it.
   * Default: 2_592_000_000. (30 days).
   */
  local?: float,
}

/**
 * Reactive sync state. Read-path errors are NOT here — they live in
 * `loadable.Failed`, at the read site.
 */
type status<'a> = {
  /** Number of ops waiting in the outbox. */
  pending: int,
  /** Ops the remote definitively refused. Handle with `retry` / `discard`. */
  rejected: array<rejection<'a>>,
}

/** Remote adaptor: the authoritative store behind the network. */
type remote<'a, 'query> = {
  /**
   * Connectivity signal. Set `online.value` as connectivity changes; the
   * engine pushes pending ops whenever it flips to true.
   */
  online: Tilia.signal<bool>,
  /**
   * Fetch the results for a query. Call `channel.set` with the full result
   * set, again on every update if the fetch is live (declare that with
   * `channel.live`). Optionally return a
   * cancel function; the engine calls it when the query expires.
   */
  fetch: ('query, Channel.read<'a>) => option<unit => unit>,
  /**
   * Push a batch of pending ops, in order. Confirm each op individually via
   * `channel.set` / `channel.removed`; end with nothing (all confirmed),
   * `channel.retry` (transient) or `channel.fail` (definitive).
   */
  push: (array<op<'a>>, Channel.write<'a>) => unit,
}

/**
 * Local adaptor: a typed values table (`push`, `fetch`) plus a string KV
 * for engine bookkeeping (`set`, `get`). Values reach the adaptor typed,
 * so it stores them natively and can index them for `fetch`.
 *
 * There is no local write channel: local persistence is command-only.
 * Confirmation, retry and rejection are remote concepts; a local storage
 * error is the adaptor's own business (log, retry, surface in app state) —
 * tilia/query never sees it.
 */
type local<'a, 'query> = {
  /**
   * Fetch cached results for a query from the values table. Same channel
   * discipline as `remote.fetch`.
   */
  fetch: ('query, Channel.read<'a>) => option<unit => unit>,
  /**
   * Apply value changes to the values table, in order: `Upsert` writes
   * or replaces the row, `Remove` drops it. Command-only — no channel.
   */
  push: array<op<'a>> => unit,
  /** Store an engine bookkeeping entry by tag and key; `None` deletes. */
  set: (~tag: string, ~key: string, option<string>) => unit,
  /**
   * Read one entry by key, or every entry for the tag when omitted.
   * Reply through `set` — synchronously or later, like everything else.
   */
  get: (~tag: string, ~key: string=?, ~set: array<string> => unit) => unit,
}

/** Inbound push from the remote (e.g. websocket), past tense. */
type receive<'a> = {
  /** These values changed on the server; they replace local clean copies. */
  changed: array<'a> => unit,
  /** These ids were deleted on the server. Ids, never full values. */
  removed: array<string> => unit,
}

type config<'a, 'query> = {
  /** Extract the unique id of a value. */
  id: 'a => string,
  /**
   * Does a value belong to a query's result set? Drives optimistic
   * updates: local upserts/removes appear in cached query results
   * immediately, and membership moves between lists.
   */
  matches: ('query, 'a) => bool,
  remote: remote<'a, 'query>,
  local?: local<'a, 'query>,
  expiry?: expiry,
  /** Injectable clock (ms). Defaults to `Date.now`. For tests. */
  now?: unit => float,
  /** Stable cache key for a query. Defaults to `sortedStringify`. */
  key?: 'query => string,
  /** Result ordering (JS comparator). Also decides which item `one` picks. */
  sort?: array<'a> => array<'a>,
}

/** Debug view: which query keys are observed (live) vs cached (idle). */
type canopy = {
  live: array<string>,
  idle: array<string>,
}

type t<'a, 'query> = {
  /**
   * Read the first result of a query (first per `sort`). `NotFound` when
   * the fetch completed empty. Reactive. Reading by id is an id query
   * read with `one`.
   */
  one: 'query => loadable<'a>,
  /**
   * Read a query's results. Never `NotFound`: an empty result is
   * `Loaded({data: []})`. Reactive.
   */
  array: 'query => loadable<array<'a>>,
  /** Write a value: applied locally, persisted, op queued for push. */
  upsert: 'a => unit,
  /** Remove by id: applied locally, persisted, op queued for push. */
  remove: string => unit,
  /** Inbound push from the server. */
  receive: receive<'a>,
  /** Reactive sync state (tilia object). */
  status: status<'a>,
  /**
   * Re-queue a rejected op, matched by its `id` (removes it from
   * `status.rejected`). An id with no rejected entry raises.
   */
  retry: rejection<'a> => unit,
  /**
   * Drop a rejected op for good, matched by its `id`; local state
   * reverts to the remote's. An id with no rejected entry raises.
   */
  discard: rejection<'a> => unit,
  /**
   * Time heartbeat. The engine owns no timers: refresh, expiry, gc and
   * push retries happen only inside `tick` (and on `remote.online`
   * transitions). Call it on an interval; anything ≤ `expiry.refresh / 2`
   * is fine.
   */
  tick: unit => unit,
  /** Cancel fetches, stop watching, release everything. Keeps local data. */
  dispose: unit => unit,
  /** Internal/debug: observed vs idle query keys. */
  _canopy: unit => canopy,
}

// --------------- IMPLEMENTATION

let sortedStringify: 'a => string = %raw(`
function sortedStringify(value) {
  return JSON.stringify(value, function(_key, value) {
    if (value && typeof value === "object" && !Array.isArray(value)) {
      const sorted = {};
      for (const key of Object.keys(value).sort()) {
        sorted[key] = value[key];
      }
      return sorted;
    }
    return value;
  });
}`)

let _expiry = {
  // 30 seconds
  refresh: 30_000.0,
  // 5 minutes
  memory: 300_000.0,
  // 30 days
  local: 2_592_000_000.0,
}

let _now = () => Date.now()
let _no_sort = array => array

let make = (
  ~id as _id,
  ~matches as _matches,
  ~remote as _remote,
  ~local as _local=?,
  ~expiry as _expiry=_expiry,
  ~now as _now=_now,
  ~key as _key=sortedStringify,
  ~sort as _sort=_no_sort,
) => {
  {
    one: _query => Loading,
    array: _query => Loaded({data: []}),
    upsert: _value => (),
    remove: _id => (),
    receive: {changed: _values => (), removed: _ids => ()},
    status: {pending: 0, rejected: []},
    retry: _rejection => (),
    discard: _rejection => (),
    tick: () => (),
    dispose: () => (),
    _canopy: () => {live: [], idle: []},
  }
}
