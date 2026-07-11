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
 * Read-path channel handed to `fetch` (local and remote). A channel can set
 * the result several times (cached rows now, fresh rows later, live updates
 * forever) and becomes inert once cancelled: late callbacks are ignored by
 * the core.
 */
export type FetchChannel<T> = {
  readonly state: ChannelState;
  /** Replace the query's result with these rows (complete result, not a delta). */
  set(rows: T[]): void;
  /** Transport error: freshness untouched, retried on the next stale window. */
  fail(message: string): void;
  /** A delta-sync engine owns this query: mark fresh, keep current data. */
  covered(): void;
};

/** Write-path channel handed to remote `upsert` and `remove`. */
export type WriteChannel<T> = {
  readonly state: ChannelState;
  /** The write was saved: settle it clean with the canonical value. */
  saved(value: T): void;
  /** Transient failure: keep the write queued and dirty for next reconnect. */
  offline(): void;
  /** Server wins: resolve the server value into cache, save clean. */
  conflict(server: T): void;
  /** Permanent refusal: drop the write, surface it on status. */
  rejected(message: string): void;
};

/** An unsynced operation: a put, or a delete when `deleted` is true. */
export type Write<T> = {
  value: T;
  deleted: boolean;
};

/** A write permanently refused by the remote. */
export type Rejection<T> = {
  readonly value: T;
  readonly deleted: boolean;
  readonly message: string;
};

export type FetchError = {
  readonly key: string;
  readonly message: string;
};

/**
 * A persisted query result: the ids the remote last returned for a key.
 * The union of these records (plus dirty rows) is what the local store
 * must retain to serve every known query on an offline start.
 */
export type QueryRecord = {
  key: string;
  ids: string[];
  fetched: number;
};

export type Canopy = {
  live: string[];
  idle: string[];
};

/** Reactive sync state for UI (a tilia object: watch it from render code). */
export type Status<T> = {
  /** Number of writes waiting to sync. */
  readonly pending: number;
  /** Writes refused by the remote, until `dismiss()`. */
  readonly rejected: readonly Rejection<T>[];
  /** Last remote fetch failure, cleared on the next successful fetch. */
  readonly error: FetchError | undefined;
};

/**
 * Remote adapter. Must be a tilia object (or contain a computed `online`):
 * the core watches `online` reactively to drive reconnect replay.
 */
export type Remote<T, Q> = {
  readonly online: boolean;
  /** May return a cleanup for live subscriptions. */
  fetch(query: Q, channel: FetchChannel<T>): void | (() => void);
  upsert(value: T, channel: WriteChannel<T>): void;
  remove(value: T, channel: WriteChannel<T>): void;
};

/**
 * Local store adapter (optional). Answers every query offline and holds the
 * durable write outbox (dirty rows and delete tombstones).
 */
export type Store<T, Q> = {
  fetch(query: Q, channel: FetchChannel<T>): void | (() => void);
  /** Upsert a row; dirty=true marks it unsynced. */
  save(value: T, dirty: boolean): void;
  /** dirty=true writes a delete tombstone; dirty=false purges row and tombstone. */
  remove(value: T, dirty: boolean): void;
  /** Unsynced writes from the previous session, replayed at boot. */
  dirty(): Promise<Write<T>[]>;
  /** Persisted query registry from the previous session, loaded at boot. */
  queries(): Promise<QueryRecord[]>;
  /** Persist a query's id-list (upsert by `record.key`). */
  saveQuery(record: QueryRecord): void;
  /** Drop a query's persisted record. */
  removeQuery(key: string): void;
};

export type Config<T, Q> = {
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
  /**
   * Membership predicate: does this object belong to this query's result?
   * With it, writes update query id-lists in place (enter matching lists,
   * leave lists that contain the id but no longer match) without any fetch.
   */
  matches?: (query: Q, value: T) => boolean;
  /** Result order. With it, id-lists stay sorted and stable across refetches. */
  sort?: (a: T, b: T) => number;
};

export type Collection<T, Q> = {
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
  /** Inbound updates (websocket / delta sync): cache, membership, and a clean
   * local save. A pending optimistic write for the same id wins. The batch is
   * applied as one reactive transaction. */
  changed(items: T[]): void;
  /** Inbound deletes: evict, purge the clean local rows, drop the ids from
   * persisted query records. A pending optimistic write wins. The batch is
   * applied as one reactive transaction. */
  removed(items: T[]): void;
  /** Stale refresh + garbage collection; call it from your own scheduler. */
  tick(): void;
  /** Debug helper: observed query keys split by canopy state. */
  canopy(): Canopy;
  status: Status<T>;
  /** Clear the rejected writes list. */
  dismiss(): void;
  /** Stop the connectivity watcher and cancel open channels. */
  dispose(): void;
  /** Empty memory state and outbox (logout). Local database is not touched. */
  clear(): void;
};

export function make<T, Q>(config: Config<T, Q>): Collection<T, Q>;
