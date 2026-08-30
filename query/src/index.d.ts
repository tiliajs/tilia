// TypeScript mirror of TiliaQuery.resi — keep both in sync.
import type { Signal } from "tilia";

/**
 * How strong an answer is. `partial` and `local` both come out of the store
 * and differ only in whether it could certify the answer was the whole
 * answer. `fresh` means authoritative as of now — not "from the network": a
 * synchronized store is entitled to say it.
 *
 * A query climbs `partial -> fresh -> local -> fresh`. Only `tick` lowers a
 * claim, as data ages.
 */
export type Claim = "partial" | "local" | "fresh";

/**
 * Why there is nothing to show. A value, not a sentence: each is a different
 * affordance, and only `failed` carries prose — the store's.
 *
 * `noMatch` says the answer set was empty, never that the row does not
 * exist. It carries its claim because an absence ages like any other answer.
 */
export type Reason =
  | "offline"
  | { reason: "failed"; message: string }
  | { reason: "noMatch"; claim: Claim };

/**
 * A value as seen by the read path: wait, render, or explain.
 *
 * `claim` is a field rather than a state of its own, so the common case —
 * render whatever we have — does not grow a branch.
 *
 * An empty partial answer is not a result. It reads as `"loading"` while a
 * remote answer is still possible and `{noData, offline}` otherwise. `array`
 * on a complete but empty query stays `{loaded, data: []}`: an empty list is
 * data. Only `one` projects it into `noMatch`.
 */
export type Loadable<T> =
  | "loading"
  | { state: "loaded"; claim: Claim; data: T }
  | { state: "noData"; reason: Reason };

/**
 * An outbox operation: a local change not yet confirmed by the remote.
 * Removes carry only the id — a remove never requires a full value.
 */
export type Op<T> = { op: "upsert"; value: T } | { op: "remove"; id: string };

/**
 * Context for an optimistic operation that was reverted.
 *
 * `edited` is the latest local edit, `base` the value it started from (or
 * the removed value). Failed variants carry the remote's `message`. The
 * current remote value is already in memory.
 *
 * Both are snapshots, copied through JSON when the operation was refused:
 * the row moves on, the record does not.
 */
export type Rejection<T> =
  | { rejection: "createConflict"; edited: T }
  | { rejection: "createFailed"; edited: T; message: string }
  | { rejection: "updateConflict"; base: T; edited: T }
  | { rejection: "updateFailed"; base: T; edited: T; message: string }
  | { rejection: "removeConflict"; base: T }
  | { rejection: "removeFailed"; base: T; message: string };

/**
 * Local context presented when a remote value arrives. `clean` carries the
 * current value; the others name their payloads like `Rejection`.
 */
export type Change<T> =
  | { change: "clean"; value: T }
  | { change: "created"; edited: T }
  | { change: "updated"; base: T; edited: T }
  | { change: "removed"; base: T };

/**
 * Read channel handed to `Remote.fetch`.
 *
 * `fresh` publishes a complete result set, replacing the previous one.
 * `live` does the same and declares that the source keeps the result fresh,
 * so periodic refresh is skipped. Both claim `fresh`: `live` adds
 * maintenance, not strength.
 *
 * `fail` publishes a failure without closing the find, so a live source can
 * recover. `end` closes it and returns a live query to periodic refresh.
 * `finally` registers the teardown, run once when the find closes. Callbacks
 * on a closed find are ignored.
 */
export type ReadChannel<T> = {
  fresh: (values: T[]) => void;
  live: (values: T[]) => void;
  fail: (message: string) => void;
  end: () => void;
  finally: (teardown: () => void) => void;
};

/**
 * What a store may say about what it holds. `local` is a complete result
 * set; `partial` is rows it holds without claiming they are all of them —
 * `partial([])` is how a store says it holds nothing.
 */
export type LocalChannel<T> = {
  partial: (values: T[]) => void;
  local: (values: T[]) => void;
};

/**
 * Write channel handed to `Remote.push` with a batch of ops.
 *
 * `set`, `removed`, `conflict` and `reject` answer one operation; `retry`
 * and `fail` apply to every operation in the push that has not been
 * answered. Answering is not settling: `conflict` leaves its operation
 * pending.
 *
 * `conflict` hands back the server's row for one operation and keeps it
 * pending, so the local change rebases through `merge` and the heartbeat
 * pushes it again. `reject` refuses one operation and no other: order does
 * not imply dependency. `retry` says nothing about the writes themselves and
 * ends the push. `fail` rejects every operation not yet answered; earlier
 * outcomes stand, so a server that acknowledged an operation and then rolled
 * it back has to say so through `receive`.
 *
 * `set(value)` and `conflict(value)` find their operation by `id(value)`: a
 * backend that assigns its own id leaves that operation pending forever.
 */
export type WriteChannel<T> = {
  set: (value: T) => void;
  removed: (id: string) => void;
  conflict: (value: T) => void;
  reject: (id: string, message: string) => void;
  retry: () => void;
  fail: (message: string) => void;
};

/** Timing the engine owns, in milliseconds. What a store keeps, and for how
 * long, is its own business — see {@link StoreExpiry}. */
export type Expiry = {
  /** Refresh interval for observed non-live queries. Default: 30 s. */
  refresh: number;
  /**
   * How long an unobserved query stays in memory. Eviction closes its find
   * and tells the store to forget the query, but leaves stored data intact.
   * Default: 5 min.
   */
  memory: number;
};

/** What both halves must agree on. Resolved once by {@link make} from the
 * config and handed to the store: neither half defaults anything itself. */
export type Schema<T, Q> = {
  id: (value: T) => string;
  matches: (query: Q, value: T) => boolean;
  key: (query: Q) => string;
  sort: (query: Q) => (values: T[]) => T[];
  now: () => number;
};

/**
 * What a store may do to the engine's rows.
 *
 * `item` is a getter, not the row table: the object it hands back *is* the
 * live one, so merging in place works, while inserting or deleting a key
 * stays unexpressible. Mutate the object in place; write only through
 * `changed`, `removed` and `place`. One live object per id — a store must
 * never keep a second canonical copy.
 *
 * `place` is an optimistic write and keeps its row whether or not a query
 * lists it. `changed` is remote truth and keeps a row only while some query
 * in memory matches it.
 */
export type Binding<T> = {
  item: (id: string) => T | undefined;
  changed: (values: T[]) => void;
  removed: (ids: string[]) => void;
  place: (value: T) => void;
};

/**
 * What the engine asks of a store. One `find` per query, whatever tier
 * answers it — the engine does not know how many there are, and asks again
 * on every refresh. `forget` says the query left memory, on eviction only.
 * `tick` and `dispose` are the store's half of the heartbeat and of
 * shutdown; the engine runs its own half first and then calls them.
 */
export type Source<T, Q> = {
  online: Signal<boolean>;
  find: (query: Q, channel: ReadChannel<T> & LocalChannel<T>) => void;
  forget: (query: Q) => void;
  tick: () => void;
  dispose: () => void;
};

/**
 * A store, as {@link make} takes it: not a built store but a factory, given
 * the schema the engine resolved and a binding that already works. It hands
 * back its source in the same breath, so neither half ever exists
 * unconnected and a store may use the binding while its own constructor is
 * still running.
 *
 * `S` is whatever that store offers the application — `void` if it offers
 * nothing, {@link Store} for the one this package ships.
 */
export type StoreFactory<T, Q, S> = (schema: Schema<T, Q>, binding: Binding<T>) => [Source<T, Q>, S];

/** Remote adaptor: the authoritative store behind the network. */
export type Remote<T, Q> = {
  /**
   * App-owned connectivity signal. Update `online.value` as connectivity
   * changes; pending ops are pushed only while online.
   */
  online: Signal<boolean>;
  /** Fetch a query's complete result set. */
  fetch: (query: Q, channel: ReadChannel<T>) => void;
  /** Push an ordered batch of pending ops. */
  push: (ops: Op<T>[], channel: WriteChannel<T>) => void;
};

/**
 * A string keyspace, and the whole of what the shipped store asks of
 * persistence. Rows, query records and the outbox are all entries under a
 * tag; what they mean is the store's business.
 *
 * Every reply comes back through `set` — synchronously or later. Errors
 * belong to whoever implements it: a keyspace that cannot answer answers
 * with nothing.
 */
export type Kv = {
  /** Read the named entries under a tag, or every entry under it when
   * `keys` is `undefined`. */
  get: (tag: string, keys: string[] | undefined, set: (values: string[]) => void) => void;
  /** Reply with the key of every entry under a tag. With IndexedDB this is
   * `primaryKeys()`. */
  keys: (tag: string, set: (keys: string[]) => void) => void;
  /** Write or, with `undefined`, delete one entry. */
  set: (tag: string, key: string, value: string | undefined) => void;
};

/** Timing the shipped store owns, in milliseconds. */
export type StoreExpiry = {
  /** How long an unheld query record remains in storage after that query was
   * last seen. Rows no surviving record or pending operation references are
   * removed by the next purge. Default: 30 days. */
  local: number;
};

/** What a find may answer, for a backend that answers when asked. */
export type Answer<T> = {
  fresh: (values: T[]) => void;
  fail: (message: string) => void;
};

/**
 * What became of one write. The words are the channel's, in the past tense:
 * `saved` is `set`, `conflict` is `conflict`, `rejected` is `reject`,
 * `transient` is `retry`.
 *
 * `conflict` hands back the row the backend holds and keeps the write
 * pending, so it rebases through `merge` and goes again. `rejected` refuses
 * this one write and no other. `transient` says nothing about the write at
 * all — the batch stops there, and everything unanswered goes again later.
 */
export type Outcome<T> =
  | { outcome: "saved"; value: T }
  | { outcome: "conflict"; value: T }
  | { outcome: "rejected"; message: string }
  | "transient";

/** What became of one remove. Its own type, and not a variant of
 * {@link Outcome}: a shared one would let `saved` answer a remove, which
 * matches no operation and hangs it forever. */
export type Removal = "removed" | { outcome: "rejected"; message: string } | "transient";

/** Configuration for `Store.make`: a backend described by what it does when
 * asked. */
export type StoreConfig<T, Q> = {
  /** Answer this query with everything that matches it, or fail. */
  find: (query: Q, answer: Answer<T>) => void;
  /** Write one row and say what became of it. */
  upsert: (value: T, reply: (outcome: Outcome<T>) => void) => void;
  /** Remove one row by id and say what became of it. */
  remove: (id: string, reply: (outcome: Removal) => void) => void;
  /** Defaults to `Store.online()`. */
  online?: Signal<boolean>;
  /**
   * Where rows and bookkeeping are kept. Absent means an in-memory
   * keyspace — not a second mode, but the same code path over a dict that
   * forgets when the process does.
   */
  persist?: Kv;
  /**
   * An index of your own, for a query the store has no record of. It may
   * answer `partial` with rows it holds, and `local` only when it can
   * certify that they are the whole answer. Without it such a query is
   * answered by a scan, which never can.
   */
  lookup?: (query: Q, channel: LocalChannel<T>) => void;
  /**
   * Merge a remote value into the local value in place. Return `true` when
   * merged; `false` records the corresponding conflict and keeps the remote
   * value.
   */
  merge?: (change: Change<T>, remote: T) => boolean;
  expiry?: StoreExpiry;
};

/** Configuration for `Store.custom`: a backend described by its channels. */
export type StoreChannels<T, Q> = {
  remote: Remote<T, Q>;
  persist?: Kv;
  lookup?: (query: Q, channel: LocalChannel<T>) => void;
  merge?: (change: Change<T>, remote: T) => boolean;
  expiry?: StoreExpiry;
};

/**
 * Facts pushed by the remote, such as websocket deliveries. Changed values
 * join and leave matching queries. Remote values are merged with pending
 * changes and win on conflict. Deliveries do not affect query freshness.
 */
export type Receive<T> = {
  /** These values changed on the server; they replace local clean copies. */
  changed: (values: T[]) => void;
  /** These ids were deleted on the server. Ids, never full values. */
  removed: (ids: string[]) => void;
};

/**
 * Reactive write state. Read failures are returned through
 * `{noData, failed}` instead.
 */
export type Status<T> = {
  /** Number of ops waiting in the outbox. */
  pending: number;
  /**
   * Contexts for reverted conflicts and definitively rejected writes, in
   * outbox order whatever order the replies arrived in: a cascade is refused
   * cause-first, so working down the list retries the cause before the
   * consequence. At most one rejection per id, and writing to an id clears
   * the one it had.
   */
  rejected: Rejection<T>[];
};

/** What the shipped store offers the application. {@link make} hands it back
 * beside the query object. */
export type Store<T> = {
  /**
   * Optimistically write a value, update matching in-memory queries, and
   * queue the op for remote push.
   */
  upsert: (value: T) => void;
  /** Optimistically remove a value by id and queue the op for remote push. */
  remove: (id: string) => void;
  /** Inbound push from server subscriptions. */
  receive: Receive<T>;
  /** Reactive sync state (tilia object). */
  status: Status<T>;
  /**
   * Queue the refused work again and drop the rejection. The edit is
   * re-applied as an ordinary optimistic write, so its change is computed
   * against the value that stands now rather than the one it was refused
   * against. The work is queued as a copy, so the record stays history even
   * once the row it describes is back in play. Acts only on the exact record
   * it is handed: a rejection already replaced or cleared is a no-op.
   */
  retry: (rejection: Rejection<T>) => void;
  /** Drop a rejection without retrying it. Same exact-record rule as
   * `retry`. */
  discard: (rejection: Rejection<T>) => void;
};

/** Debug view: which query keys are observed (live) vs cached (idle). */
export type Canopy = {
  live: string[];
  idle: string[];
};

/** Configuration for {@link make}. Everything here is the engine's; what
 * belongs to a store is in the value you give `store`. */
export type Config<T, Q, S> = {
  /** Return a unique id for a given value. */
  id: (value: T) => string;
  /**
   * Return true if a value belongs to a query. Queries must be expressible
   * as pure predicates over one row, and a find must answer with the complete
   * result set: limits, pagination and aggregates do not fit this shape.
   */
  matches: (query: Q, value: T) => boolean;
  /** Where answers come from and where writes go. `Store.custom` and
   * `Store.make` are the ones this package ships; any factory of this shape
   * will do. */
  store: StoreFactory<T, Q, S>;
  expiry?: Expiry;
  now?: () => number;
  key?: (query: Q) => string;
  /** Return a sorter for a query. */
  sort?: (query: Q) => (values: T[]) => T[];
  /**
   * A find failed and the read site will not be told, because it still has
   * something to show. Refresh failures land here; a first failure, with
   * nothing behind it, reaches the read site as `{noData, failed}` instead.
   */
  onError?: (query: Q, message: string) => void;
};

export type TiliaQuery<T, Q> = {
  /** Read the first result of a query (first per `sort`). Answers
   * `{noData, noMatch}` when the result set is empty. Reactive. */
  one: (query: Q) => Loadable<T>;
  /** Read a query's results. Reactive. */
  array: (query: Q) => Loadable<T[]>;
  /**
   * Time heartbeat, for both halves: refresh, expiry, gc, local purge and
   * push retries all happen here. The engine owns no timers. Call it at
   * least twice per refresh interval.
   */
  tick: () => void;
  /**
   * Stop watching connectivity, close every open find — each registered
   * `finally` teardown runs — and then dispose the store. Cached data is
   * left to normal expiry and nothing is written on the way out. Safe to
   * call more than once.
   */
  dispose: () => void;
  /** Internal/debug: observed vs idle query keys. */
  _canopy: () => Canopy;
};

/**
 * The store this package ships: a write-through cache with an outbox, a
 * three-way merge, a query registry and local expiry. It is one value the
 * `store` field can take, not a second entry point.
 */
export declare const Store: {
  /** A keyspace that forgets when the process does. What `persist` defaults
   * to, and the only one this package ships — IndexedDB lives behind
   * `@tilia/query/indexeddb`. */
  memory(): Kv;
  /** The tag rows are kept under: one entry per row, keyed by its id,
   * holding the value as JSON. Documented because whoever writes the
   * keyspace is who can index it — and `lookup` is theirs to write too. */
  rowTag: string;
  /**
   * Connectivity, once per process. Where there is no `addEventListener`
   * there is nothing to listen to, and a process that cannot be told it is
   * offline is treated as online.
   */
  online(): Signal<boolean>;
  /**
   * A store described by what its backend does when asked. Operations are
   * issued one at a time, each waiting for its outcome: that is what lets a
   * batch stop at the first `transient` with nothing further sent, and it
   * keeps a cascade in the order the outbox holds it.
   */
  make<T, Q>(config: StoreConfig<T, Q>): StoreFactory<T, Q, Store<T>>;
  /**
   * A store described by its channels: an adaptor that answers a find when
   * it can, pushes a batch when asked, and may push facts in at any time.
   * Anything that pushes uses this one.
   */
  custom<T, Q>(channels: StoreChannels<T, Q>): StoreFactory<T, Q, Store<T>>;
};

/**
 * Deterministic JSON serialization (sorted keys); the default `key`.
 * Only meaningful on plain data — no functions, no cycles.
 */
export function sortedStringify(value: unknown): string;

/**
 * Build the query object, and whatever the store offers beside it.
 *
 * Values and queries are held in plain JavaScript objects and absence is
 * read as `undefined`, so a value or a query must never be `null` or
 * `undefined` itself.
 *
 * The store this package ships asks two more things of a value, and another
 * store may not: that it survive a JSON round trip unchanged — no functions,
 * no cycles, no class instances, nothing whose identity carries meaning —
 * and that the backend preserve the id the client sent.
 */
export function make<T, Q, S>(config: Config<T, Q, S>): [TiliaQuery<T, Q>, S];
