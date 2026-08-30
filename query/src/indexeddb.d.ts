// TypeScript surface of `@tilia/query/indexeddb`, on top of
// src/TiliaQueryIndexedDb.res — keep in sync with it.
import type { Kv } from "./index";

export type Config = {
  /** Database name. */
  name: string;
  /** Object store name. Default: `"entries"`. */
  store?: string;
  /** Database version. Default: 1. */
  version?: number;
  /**
   * A database that will not open, a transaction that aborts. Reads still
   * answer — with nothing — and writes are dropped, because persistence is
   * command-only and the store has no way to care. This is how you find out.
   */
  onError?: (error: Error) => void;
};

/**
 * A keyspace over IndexedDB. One object store, compound key `[tag, key]`, so
 * a tag is a range. A call made before the database is open waits for it;
 * writes are batched into one transaction, and flushed before any read.
 */
export function make(config: Config): Kv;
