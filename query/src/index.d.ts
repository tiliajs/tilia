// TypeScript mirror of TiliaQuery.resi — keep both in sync.
import type { Signal } from "tilia";

/**
 * A value as seen by the read path.
 *
 * `fresh` tells whether the data is known-fresh from the remote (`true`) or
 * served from the local cache (`false`).
 *
 * `notLocal` is the offline dead end: nothing cached locally and the remote
 * unreachable. Unlike `loading` it is an answer, not a progress state.
 *
 * `failed` carries the fetch error to the place where the value is read —
 * there is no global error slot to join against.
 */
export type Loadable<T> =
  | "loading"
  | { state: "loaded"; data: T; fresh: boolean }
  | "notFound"
  | "notLocal"
  | { state: "failed"; message: string };

/**
 * An outbox operation: a local change not yet confirmed by the remote.
 * Removes carry only the id — a remove never requires a full value.
 */
export type Op<T> = { op: "upsert"; value: T } | { op: "remove"; id: string };

/**
 * Local context presented when a remote value arrives.
 *
 * `Updated` carries the original base and latest local edit. This is the
 * three-way merge input together with the remote value.
 */
export type Change<T> =
  | { TAG: "Clean"; _0: T }
  | { TAG: "Created"; _0: T }
  | { TAG: "Updated"; _0: T; _1: T }
  | { TAG: "Removed"; _0: T };

/**
 * Context for an optimistic operation reverted by a conflict or definitive
 * failure. At most one rejection is retained per value id.
 */
export type Rejection<T> =
  | { TAG: "CreateConflict"; _0: T }
  | { TAG: "CreateFailed"; _0: T; _1: string }
  | { TAG: "UpdateConflict"; _0: T; _1: T }
  | { TAG: "UpdateFailed"; _0: T; _1: T; _2: string }
  | { TAG: "RemoveConflict"; _0: T }
  | { TAG: "RemoveFailed"; _0: T; _1: string };

/**
 * Read channel, handed to `remote.fetch`.
 *
 * `set` publishes the query's current, complete result set; call it again
 * whenever fresher results arrive. `live` does the same and declares that
 * the adaptor keeps the result fresh on its own (e.g. a server
 * subscription), so the periodic refresh skips this query.
 *
 * `fail` publishes a failed result. It does not close the fetch: a live
 * source may recover by delivering again. A failed non-live query re-enters
 * the refresh loop and is retried once per refresh window.
 *
 * `end` says "the stream is over" — valid after `set` or `live`, not a
 * substitute for `fail`. It closes the fetch: the registered `finally`
 * runs, a live query becomes a normal remote result again and re-enters
 * periodic refresh.
 *
 * `finally` registers the fetch's teardown (e.g. unsubscribe a socket).
 * Single slot, last write wins. The engine runs it exactly once, when the
 * fetch closes: on `end`, when a newer fetch supersedes this one, when the
 * query is evicted from memory, or on `dispose`. Registering on an already
 * closed fetch runs the function immediately.
 *
 * Every callback on a closed fetch is a noop: the engine suppresses late
 * replies from ended, superseded or evicted fetches — adaptors do not
 * need to.
 */
export type ReadChannel<T> = {
  set: (values: T[]) => void;
  live: (values: T[]) => void;
  fail: (message: string) => void;
  end: () => void;
  finally: (fn: () => void) => void;
};

/**
 * Local fetch channel, handed to `local.fetch`.
 *
 * `set` sets the results. `unknown` is called if the local storage cannot
 * answer the query.
 */
export type LocalChannel<T> = {
  set: (values: T[]) => void;
  unknown: () => void;
};

/**
 * Write channel, handed to `remote.push` together with a batch of ops.
 *
 * `set` confirms an upsert with the authoritative value — echo the input,
 * or the server-corrected version. `removed` confirms a remove, by id.
 * `retry` reports a transient failure: unconfirmed ops stay pending and are
 * pushed again later. `fail` is definitive: every op not yet confirmed
 * becomes a rejection in `status.rejected`.
 */
export type WriteChannel<T> = {
  set: (value: T) => void;
  removed: (id: string) => void;
  retry: () => void;
  fail: (message: string) => void;
};

/**
 * Timing configuration in milliseconds. Memory is a small RAM cache of the
 * queries being (or recently) observed — seconds to minutes. Local is the
 * durable superset on disk — days to weeks.
 */
export type Expiry = {
  /** Refresh interval for observed non-live queries. Default: 30_000 (30 s). */
  refresh: number;
  /** How long an unobserved query result stays in RAM. Default: 300_000 (5 min). */
  memory: number;
  /** Local store retention since a query's last refresh. Default: 2_592_000_000 (30 days). */
  local: number;
};

/** Reactive sync state. Read-path errors are NOT here — they live in `Loadable`. */
export type Status<T> = {
  /** Number of ops waiting in the outbox. */
  pending: number;
  /** Contexts for reverted conflicts and definitively rejected writes. */
  rejected: Rejection<T>[];
};

/** Remote adaptor: the authoritative store behind the network. */
export type Remote<T, Q> = {
  /** Connectivity signal, owned by the app: set `online.value` as connectivity changes. */
  online: Signal<boolean>;
  /**
   * Fetch the results for a query. Answer through `channel.set` (one-shot)
   * or `channel.live` (self-refreshing source); register teardown with
   * `channel.finally` and call `channel.end` when the source shuts down.
   */
  fetch: (query: Q, channel: ReadChannel<T>) => void;
  /**
   * Push a batch of pending ops, in order. Confirm each op individually via
   * `channel.set` / `channel.removed`; end with nothing (all confirmed),
   * `channel.retry` (transient) or `channel.fail` (definitive).
   */
  push: (ops: Op<T>[], channel: WriteChannel<T>) => void;
};

/**
 * Local adaptor: a typed values table (`push`, `fetch`) plus a string KV
 * for engine bookkeeping (`set`, `get`). Command-only: a local storage
 * error is the adaptor's own business — tilia/query never sees it.
 */
export type Local<T, Q> = {
  /** Fetch cached results for a query from the values table. */
  fetch: (query: Q, channel: LocalChannel<T>) => void;
  /** Apply value changes to the values table, in order. */
  push: (ops: Op<T>[]) => void;
  /** Store an engine bookkeeping entry by tag and key; `undefined` deletes. */
  set: (tag: string, key: string, value: string | undefined) => void;
  /**
   * Read one entry by key, or every entry for the tag when `key` is
   * `undefined`. Reply through `set` — synchronously or later.
   */
  get: (tag: string, key: string | undefined, set: (values: string[]) => void) => void;
  /** Reply with the id of every row in the values table (purge sweep). */
  ids: (set: (ids: string[]) => void) => void;
};

/** Configuration for {@link make}. */
export type Config<T, Q> = {
  id: (value: T) => string;
  matches: (query: Q, value: T) => boolean;
  remote: Remote<T, Q>;
  local?: Local<T, Q>;
  expiry?: Expiry;
  now?: () => number;
  key?: (query: Q) => string;
  /** Return a sorter for a query. */
  sort?: (query: Q) => (values: T[]) => T[];
  /**
   * Merge a remote value into the local value in place. Return `false` to
   * keep remote truth and record a conflict.
   */
  merge?: (change: Change<T>, remote: T) => boolean;
};

/**
 * Inbound push from the remote (e.g. a websocket subscription), past
 * tense: facts about the server, not commands. Deliveries merge with
 * pending changes and do not touch freshness.
 */
export type Receive<T> = {
  /** These values changed on the server; they replace local clean copies. */
  changed: (values: T[]) => void;
  /** These ids were deleted on the server. Ids, never full values. */
  removed: (ids: string[]) => void;
};

/** Debug view: which query keys are observed (live) vs cached (idle). */
export type Canopy = {
  live: string[];
  idle: string[];
};

export type TiliaQuery<T, Q> = {
  /** Read the first result of a query (first per `sort`). Reactive. */
  one: (query: Q) => Loadable<T>;
  /** Read a query's results. Never `notFound`: an empty result is loaded `[]`. Reactive. */
  array: (query: Q) => Loadable<T[]>;
  /** Write a value: applied locally, persisted, op queued for push. */
  upsert: (value: T) => void;
  /** Remove optimistically by id; the op queues in the outbox like any write. */
  remove: (id: string) => void;
  /** Inbound push from server subscriptions. */
  receive: Receive<T>;
  /** Reactive sync state (tilia object). */
  status: Status<T>;
  /** Remove a resolved or ignored rejection context. */
  dismiss: (rejection: Rejection<T>) => void;
  /**
   * Time heartbeat. The engine owns no timers: refresh, expiry, gc and push
   * retries happen only inside `tick` (and on `remote.online` transitions).
   * Call it on an interval; anything ≤ `expiry.refresh / 2` is fine.
   */
  tick: () => void;
  /**
   * Stop watching remote connectivity and close every open fetch: each
   * registered `finally` teardown runs. Safe to call more than once.
   */
  dispose: () => void;
  /** Internal/debug: observed vs idle query keys. */
  _canopy: () => Canopy;
};

/**
 * Deterministic JSON serialization (sorted keys); the default `key`.
 * Only meaningful on plain data — no functions, no cycles.
 */
export function sortedStringify(value: unknown): string;

export function make<T, Q>(config: Config<T, Q>): TiliaQuery<T, Q>;
