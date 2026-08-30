/**
 * A `Kv` over IndexedDB, for `Store`'s `persist`.
 *
 * One object store, compound key `[tag, key]`, so a tag is a range: reading
 * everything under one, or listing its keys, never touches the rest. Rows,
 * query records and the outbox all live here as strings — what they mean is
 * the store's business, not this one's.
 *
 * A call made before the database is open waits for it, because the store
 * asks in its own constructor. Writes are batched into one transaction, and
 * a read flushes them before answering, so it can never answer without a row
 * the store believes it has already written.
 */
type config = {
  /** Database name. */
  name: string,
  /** Object store name. Default: `"entries"`. */
  store?: string,
  /** Database version. Default: 1. */
  version?: float,
  /**
   * A database that will not open, a transaction that aborts. Reads still
   * answer — with nothing — and writes are dropped, because persistence is
   * command-only and the store has no way to care. This is how you find out.
   */
  onError?: JsError.t => unit,
}

let make: config => TiliaQueryStore.Kv.t
