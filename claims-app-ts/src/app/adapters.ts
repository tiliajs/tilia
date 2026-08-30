import { Store, type Kv, type Remote } from "@tilia/query";
import { watch, type Signal } from "tilia";
import type { Server } from "../server/server";
import type { Claim, ClaimQuery } from "./claim";

export type AdaptorCall = {
  seq: number;
  tag: "local" | "remote";
  name: string;
  label?: string;
  value?: unknown;
  reply?: boolean;
};

export type Network = {
  online: Signal<boolean>;
};

export type AdaptorLog = {
  calls: AdaptorCall[];
};

const record = (
  log: AdaptorLog,
  tag: AdaptorCall["tag"],
  name: string,
  value?: unknown,
  label?: string,
  reply = false
) => {
  const snapshot = value === undefined ? undefined : (JSON.parse(JSON.stringify(value)) as unknown);
  log.calls.push({ seq: log.calls.length + 1, tag, name, value: snapshot, label, reply });
};

const decode = (value: string) => {
  try {
    return JSON.parse(value) as unknown;
  } catch {
    return value;
  }
};

// One remote per logged-in user: the shared server sees who calls, the
// reactive `online` flag drives reconnect replay for this user only.
export function makeRemote(
  server: Server,
  user: string,
  network: Network,
  log: AdaptorLog
): Remote<Claim, ClaimQuery> {
  return {
    online: network.online,
    fetch(query, channel) {
      record(log, "remote", "fetch", query, server.live ? "live" : undefined);
      if (server.live) {
        let unsubscribe: (() => void) | undefined;
        const connect = () => {
          if (unsubscribe || !network.online.value) return;
          unsubscribe = server.subscribe(user, query, (rows) => {
            if (network.online.value) {
              record(log, "remote", "live", rows, "fetch", true);
              channel.live(rows);
            }
          });
        };
        connect();
        const stop = watch(
          () => network.online.value,
          (online) => {
            if (online) connect();
            else {
              unsubscribe?.();
              unsubscribe = undefined;
            }
          }
        );
        channel.finally(() => {
          stop();
          unsubscribe?.();
        });
        return;
      }
      server.fetch(user, query, (rows) => {
        if (network.online.value) {
          record(log, "remote", "fresh", rows, "fetch", true);
          channel.fresh(rows);
        }
      });
    },
    push(ops, channel) {
      record(log, "remote", "push", ops, `${ops.length} ops`);
      const next = (index: number) => {
        const op = ops[index];
        if (!op) return;
        if (op.op === "remove") {
          const id = op.id;
          server.remove(user, id, (outcome) => {
            if (outcome.kind === "removed") {
              record(log, "remote", "removed", outcome.id, "push", true);
              channel.removed(outcome.id);
              next(index + 1);
            } else if (outcome.kind === "rejected") {
              // This remove and no other: order does not imply dependency.
              record(log, "remote", "reject", outcome.message, "push", true);
              channel.reject(id, outcome.message);
              next(index + 1);
            }
          });
          return;
        }
        const value = op.value;
        server.upsert(user, value, (outcome) => {
          switch (outcome.kind) {
            case "saved":
              record(log, "remote", "set", outcome.claim, "push", true);
              channel.set(outcome.claim);
              next(index + 1);
              break;
            // The write was not refused, it was out of date: hand back what
            // the server holds and the write rebases onto it.
            case "conflict":
              record(log, "remote", "conflict", outcome.claim, "push", true);
              channel.conflict(outcome.claim);
              next(index + 1);
              break;
            case "rejected":
              record(log, "remote", "reject", outcome.message, "push", true);
              channel.reject(value.id, outcome.message);
              next(index + 1);
              break;
            // The row is gone on the server: this push says nothing about
            // the write, so it goes again later.
            case "removed":
              record(log, "remote", "retry", undefined, "push", true);
              channel.retry();
              break;
          }
        });
      };
      next(0);
    },
  };
}

export type Local = Kv & {
  entries: Map<string, Map<string, string>>;
  /** The row the keyspace holds, decoded. Whoever writes the keyspace knows
   * how the store keeps its rows — that is why `Store.rowTag` is public. */
  row(id: string): Claim | undefined;
};

// In-memory stand-in for IndexedDB. It outlives the app instance, so an app
// reload demonstrates row, query-record and outbox recovery. One table: the
// store keeps everything it needs as entries under a tag.
export function makeLocal(log: AdaptorLog): Local {
  const entries = new Map<string, Map<string, string>>();
  const tagged = (tag: string) => {
    let found = entries.get(tag);
    if (!found) {
      found = new Map();
      entries.set(tag, found);
    }
    return found;
  };
  return {
    entries,
    row(id) {
      const value = tagged(Store.rowTag).get(id);
      return value === undefined ? undefined : (JSON.parse(value) as Claim);
    },
    set(tag, key, value) {
      record(log, "local", "set", value === undefined ? undefined : decode(value), `${tag}:${key}`);
      if (value === undefined) tagged(tag).delete(key);
      else tagged(tag).set(key, value);
    },
    get(tag, keys, set) {
      record(log, "local", "get", { tag, keys: keys ?? null }, `${tag}:${keys?.join(",") ?? "*"}`);
      const found = tagged(tag);
      const values =
        keys === undefined
          ? [...found.values()]
          : keys.flatMap((key) => {
              const value = found.get(key);
              return value === undefined ? [] : [value];
            });
      record(log, "local", "set", values.map(decode), "get", true);
      set(values);
    },
    keys(tag, set) {
      const found = [...tagged(tag).keys()];
      record(log, "local", "keys", found, `${tag}: ${found.length}`);
      set(found);
    },
  };
}
