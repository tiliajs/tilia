import type { Local as QueryLocal, Op, Remote } from "@tilia/query";
import { watch, type Signal } from "tilia";
import type { Server } from "../server/server";
import { clone, match, type Claim, type ClaimQuery } from "./claim";

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
          record(log, "remote", "set", rows, "fetch", true);
          channel.set(rows);
        }
      });
    },
    push(ops, channel) {
      record(log, "remote", "push", ops, `${ops.length} ops`);
      const next = (index: number) => {
        const op = ops[index];
        if (!op) return;
        if (op.op === "remove") {
          server.remove(user, op.id, (outcome) => {
            if (outcome.kind === "removed") {
              record(log, "remote", "removed", outcome.id, "push", true);
              channel.removed(outcome.id);
              next(index + 1);
            } else if (outcome.kind === "rejected") {
              record(log, "remote", "fail", outcome.message, "push", true);
              channel.fail(outcome.message);
            }
          });
          return;
        }
        server.upsert(user, op.value, (outcome) => {
          switch (outcome.kind) {
            case "saved":
            case "conflict":
              record(log, "remote", "set", outcome.claim, "push", true);
              channel.set(outcome.claim);
              next(index + 1);
              break;
            case "rejected":
              record(log, "remote", "fail", outcome.message, "push", true);
              channel.fail(outcome.message);
              break;
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

export type Local = QueryLocal<Claim, ClaimQuery> & {
  rows: Map<string, Claim>;
  entries: Map<string, Map<string, string>>;
};

// In-memory stand-in for IndexedDB. It outlives the app instance, so an app
// reload demonstrates value, query-record, and outbox recovery.
export function makeLocal(log: AdaptorLog): Local {
  const rows = new Map<string, Claim>();
  const entries = new Map<string, Map<string, string>>();
  return {
    rows,
    entries,
    fetch(query, channel) {
      record(log, "local", "fetch", query);
      const found = [...rows.values()].filter((claim) => match(query, claim)).map(clone);
      record(log, "local", "set", found, "fetch", true);
      channel.set(found);
    },
    push(ops: Op<Claim>[]) {
      record(log, "local", "push", ops, `${ops.length} ops`);
      for (const op of ops) {
        if (op.op === "upsert") rows.set(op.value.id, clone(op.value));
        else rows.delete(op.id);
      }
    },
    set(tag, key, value) {
      record(log, "local", "set", value === undefined ? undefined : decode(value), `${tag}:${key}`);
      let tagged = entries.get(tag);
      if (!tagged) {
        tagged = new Map();
        entries.set(tag, tagged);
      }
      if (value === undefined) tagged.delete(key);
      else tagged.set(key, value);
    },
    get(tag, key, set) {
      record(log, "local", "get", { tag, key: key ?? null }, `${tag}:${key ?? "*"}`);
      const tagged = entries.get(tag);
      if (key === undefined) {
        const values = tagged ? [...tagged.values()] : [];
        record(log, "local", "set", values.map(decode), "get", true);
        set(values);
      } else {
        const value = tagged?.get(key);
        const values = value === undefined ? [] : [value];
        record(log, "local", "set", values.map(decode), "get", true);
        set(values);
      }
    },
    ids(set) {
      record(log, "local", "ids", undefined, `${rows.size} rows`);
      const values = [...rows.keys()];
      record(log, "local", "set", values, "ids", true);
      set(values);
    },
  };
}
