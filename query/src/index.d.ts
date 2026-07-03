/**
 * @tilia/query - offline-first query and cache layer for Tilia apps.
 *
 * The source contract lives in `src/TiliaQuery.resi`; these declarations
 * mirror it 1:1.
 */

/** Read state of a query or cached object. */
export type Loadable<T> = "loading" | "notFound" | { state: "loaded"; data: T };

export type ChannelState = "live" | "cancelled";

/**
 * Read-path channel handed to `fetch` (local and remote). A channel can emit
 * several times (cached rows now, fresh rows later, live updates forever) and
 * becomes inert once cancelled: late callbacks are ignored by the core.
 */
export interface FetchChannel<T> {
  readonly state: ChannelState;
  /** Push rows for the query. */
  emit(rows: T[]): void;
  /** Transport error: freshness untouched, retried on the next stale window. */
  fail(message: string): void;
  /** A delta-sync engine owns this query: mark fresh, keep current data. */
  covered(): void;
}

/** Write-path channel handed to remote `upsert` and `remove`. */
export interface WriteChannel<T> {
  readonly state: ChannelState;
  /** Saved: settle the write clean. */
  emit(saved: T): void;
  /** Transient failure: keep the write queued and dirty for next reconnect. */
  offline(): void;
  /** Server wins: resolve the server value into cache, save clean. */
  conflict(server: T): void;
  /** Permanent refusal: drop the write, surface it on status. */
  reject(message: string): void;
}

/** An unsynced operation: a put, or a delete when `deleted` is true. */
export interface Write<T> {
  value: T;
  deleted: boolean;
}

/** A write permanently refused by the remote. */
export interface Rejection<T> {
  readonly value: T;
  readonly deleted: boolean;
  readonly message: string;
}

export interface FetchError {
  readonly key: string;
  readonly message: string;
}

/** Reactive sync state for UI (a tilia object: watch it from render code). */
export interface Status<T> {
  /** Number of writes waiting to sync. */
  readonly pending: number;
  /** Writes refused by the remote, until `dismiss()`. */
  readonly rejected: readonly Rejection<T>[];
  /** Last remote fetch failure, cleared on the next successful fetch. */
  readonly error: FetchError | undefined;
}

/**
 * Remote adapter. Must be a tilia object (or contain a computed `online`):
 * the core watches `online` reactively to drive reconnect replay.
 */
export interface Remote<T, Q> {
  readonly online: boolean;
  /** May return a cleanup for live subscriptions. */
  fetch(query: Q, channel: FetchChannel<T>): void | (() => void);
  upsert(value: T, channel: WriteChannel<T>): void;
  remove(value: T, channel: WriteChannel<T>): void;
}

/**
 * Local store adapter (optional). Answers every query offline and holds the
 * durable write outbox (dirty rows and delete tombstones).
 */
export interface Store<T, Q> {
  fetch(query: Q, channel: FetchChannel<T>): void | (() => void);
  /** Upsert a row; dirty=true marks it unsynced. */
  save(value: T, dirty: boolean): void;
  /** dirty=true writes a delete tombstone; dirty=false purges row and tombstone. */
  remove(value: T, dirty: boolean): void;
  /** Unsynced writes from the previous session, replayed at boot. */
  dirty(): Promise<Write<T>[]>;
}

export interface Config<T, Q> {
  id(value: T): string;
  remote: Remote<T, Q>;
  local?: Store<T, Q>;
  /** Seconds before a watched query is refreshed on `tick()`. Default 30. */
  stale?: number;
  /** Seconds before an unwatched query is evicted on `tick()`. Default 300. */
  gc?: number;
  /** Clock in seconds. Default `Date.now() / 1000`. */
  now?: () => number;
  /** Query cache key. Default: sorted JSON stringification. */
  key?: (query: Q) => string;
  /** Marks queries stale when a changed object matches their filter. */
  invalidates?: (query: Q, value: T) => boolean;
}

export interface Query<T, Q> {
  /** Cached object by id (no fetch). */
  get(id: string): Loadable<T>;
  /** Detail view: two-tier fetch resolving the first row. */
  one(query: Q): Loadable<T>;
  /** List view: reactive array of rows. Empty results are loaded, not notFound. */
  array(query: Q): Loadable<T[]>;
  /** Same as `array`, keyed by id. */
  dict(query: Q): Loadable<Record<string, T>>;
  /** Optimistic write: durable in the local store, pushed when online. */
  upsert(value: T): void;
  /** Optimistic delete: tombstoned locally, pushed when online. */
  remove(value: T): void;
  /** Inbound update (websocket / delta sync): cache + invalidation only. */
  sync(value: T): void;
  /** Stale refresh + garbage collection; call it from your own scheduler. */
  tick(): void;
  status: Status<T>;
  /** Clear the rejected writes list. */
  dismiss(): void;
  /** Stop the connectivity watcher and cancel open channels. */
  dispose(): void;
  /** Empty memory state and outbox (logout). Local database is not touched. */
  clear(): void;
}

export function make<T, Q>(config: Config<T, Q>): Query<T, Q>;
