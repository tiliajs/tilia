/**
 * A value as seen by the read path.
 *
 * `Loaded.local` tells whether the data is known-fresh from the remote
 * (`false`) or served from the local cache (`true`). On `tick`, a query
 * whose data came from the remote (and is not live) and has not received a
 * remote delivery within `expiry.refresh` has its result flipped to
 * `local: true`; the next remote delivery flips it back to `local: false`.
 * While online the flip waits one extra refresh-check period
 * (`expiry.refresh / 8`) so an in-flight refresh can land without a
 * flip/flop; offline it flips right at the refresh expiry limit.
 *
 * `NotLocal` is the offline dead end: nothing cached locally and the remote
 * unreachable. Unlike `Loading` it is an answer, not a progress state —
 * show "not available offline", not a spinner. It only appears while
 * offline: when the remote is online, an empty local answer keeps the
 * query `Loading` until the remote responds. Rare in practice — a local
 * adaptor can instead build partial results from whatever it has (filtering
 * its cache with `matches`) and `set` those.
 *
 * `Failed` carries the fetch error to the place where the value is read —
 * there is no global error slot to join against.
 */
@tag("state")
type loadable<'a> =
  | @as("loading") Loading
  | @as("loaded") Loaded({data: 'a, local: bool})
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
 * An op the remote definitively refused. Keyed by `id`: at most one
 * rejection per id, a newer rejection replaces the older.
 */
type rejection<'a> = {
  /** The op's value id — the key `retry` / `discard` match on. */
  id: string,
  op: op<'a>,
  message: string,
}

module Channel: {
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
    live: array<'a> => unit,
    fail: string => unit,
  }

  /**
   * Local fetch channel, handed to `local.fetch`.
   *
   * `set` sets the results.
   * `unknown` is called if the local storage cannot answer the query.
   */
  type local<'a> = {
    set: array<'a> => unit,
    unknown: unit => unit,
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
  refresh: float,
  /**
   * How long a stale (no longer observed) query result stays in RAM.
   * Eviction only frees memory — the data stays in the local store, and
   * reopening the query re-materializes it from there.
   * Default: 300_000 (5 min).
   */
  memory: float,
  /**
   * How long a query is retained in the local store since its last
   * refresh. Days-to-weeks scale; local gc runs against it.
   * Default: 2_592_000_000. (30 days).
   */
  local: float,
}

/**
 * Reactive sync state. Read-path errors are NOT here — they live in
 * `loadable.Failed`, at the read site.
 *
 * Every write (`upsert` / `remove`) enqueues its op in the outbox and
 * counts in `status.pending`. The outbox is pushed only while online —
 * `remote.push` is never called offline. A confirmation (`channel.set` /
 * `channel.removed`) drops the op from the outbox. The outbox is durable:
 * ops are persisted in the local kv and reloaded at boot, so pending
 * writes survive a restart and replay.
 *
 * A remote delivery reflects the server before our pending writes: the
 * outbox is re-applied on top of every remote result — a pending upsert
 * replaces the server's copy of the same id, joins results it `matches`
 * and leaves results it no longer matches; a pending remove filters the
 * id out. An optimistic write never flickers out of a result.
 *
 * A definitive push failure (`channel.fail`) moves every op of the batch
 * not yet confirmed from the outbox to `status.rejected`, keyed by id —
 * a newer rejection replaces an older one for the same id. The op's
 * persisted outbox entry is kept: after a restart the op reloads as
 * pending and the re-push fails again, so the rejection resurfaces on
 * its own. A rejected op keeps overlaying remote deliveries like a
 * pending one — the refused edit stays visible until `retry` re-queues
 * it or `discard` reverts it.
 */
type status<'a> = {
  /** Number of ops waiting in the outbox. */
  mutable pending: int,
  /** Ops the remote definitively refused. Handle with `retry` / `discard`. */
  rejected: array<rejection<'a>>,
}

/** Remote adaptor: the authoritative store behind the network. */
type remote<'a, 'query> = {
  /**
   * Connectivity signal. Set `online.value` as connectivity changes. The
   * engine reacts to the transitions: flipping to false settles queries
   * still `Loading` to `NotLocal` — an in-flight remote response may still
   * land and is taken as-is, its freshness self-corrects on later ticks;
   * flipping to true pushes pending ops.
   */
  online: Tilia.signal<bool>,
  /**
   * Fetch the results for a query. Call `channel.set` with the full result
   * set, again on every update if the fetch is live (declare that with
   * `channel.live`). Optionally return a cancel function; the engine
   * calls it when the query expires.
   */
  fetch: ('query, Channel.read<'a>) => unit,
  /**
   * Push a batch of pending ops, in order. One push carries every pending
   * op not already in flight, in order. Confirm each op individually via
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
   * Fetch cached results for a query from the values table. First argument is
   * the query, second is the callback to set the results, third is the callback
   * to call if there is no answer.
   */
  fetch: ('query, Channel.local<'a>) => unit,
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
  /**
   * Reply with the id of every row in the values table. The sweep phase of the
   * local purge enumerates rows through this. Reply through `set` —
   * synchronously or later.
   */
  ids: (~set: array<string> => unit) => unit,
}

/** Inbound push from the remote (e.g. websocket), past tense. */
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
  /**
   * Write a value: applied locally, persisted, op queued for push.
   *
   * An upsert joins matching queries immediately: the value's id is
   * appended to every in-memory query result whose `matches` accepts it,
   * and removed from those it no longer matches — a move updates both
   * queries at once. Both changes reach the affected queries' persisted
   * records. Query records only on disk
   * are not scanned — they catch up on the query's next refresh. If after
   * the join no persisted query record lists the id, a synthetic record
   * is written so the row survives the local purge for `expiry.local`.
   * The next purge offers such a row to every persisted query (records
   * carry their query — keep queries plain data): a match adopts the row
   * and drops the synthetic record.
   */
  upsert: 'a => unit,
  /**
   * Remove is optimistic: the id leaves every in-memory query result and
   * the persisted query records, and the local row is deleted, before the
   * remote confirms. The op queues in the outbox like any write.
   */
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
  /** Testing hook: ids held by an in-memory query. Returns a copy. */
  _ids: 'query => option<array<string>>,
}

/**
 * Deterministic JSON serialization (sorted keys); the default `key`.
 * Only meaningful on plain data — no functions, no cycles.
 */
let sortedStringify: 'a => string

let make: (
  ~id: 'a => string,
  ~matches: ('query, 'a) => bool,
  ~remote: remote<'a, 'query>,
  ~local: local<'a, 'query>=?,
  ~expiry: expiry=?,
  ~now: unit => float=?,
  ~key: 'query => string=?,
  ~sort: array<'a> => array<'a>=?,
) => t<'a, 'query>
