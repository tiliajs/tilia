import type { Remote, Store, Write, WriteChannel } from "@tilia/query";
import { computed, tilia } from "tilia";
import type { Outcome, Server } from "../server/server";
import { clone, match, type Claim, type ClaimQuery } from "./claim";

export type Network = { online: boolean };

function settle(channel: WriteChannel<Claim>, outcome: Outcome) {
  switch (outcome.kind) {
    case "saved":
      channel.emit(outcome.claim);
      break;
    case "conflict":
      channel.conflict(outcome.claim);
      break;
    case "rejected":
      channel.reject(outcome.message);
      break;
  }
}

// One remote per logged-in user: the shared server sees who calls, the
// reactive `online` flag drives reconnect replay for this user only.
export function makeRemote(server: Server, user: string, network: Network): Remote<Claim, ClaimQuery> {
  return tilia({
    online: computed(() => network.online),
    fetch(query, channel) {
      if (server.live) {
        // Live mode: register the query on the server; the channel stays open
        // and receives a push whenever this query's result changes. The
        // returned cleanup unsubscribes on query GC or refetch.
        return server.subscribe(user, query, (rows) => {
          // A dropped connection silences the socket; reconnect re-subscribes.
          if (network.online) channel.emit(rows);
        });
      }
      server.fetch(user, query, (rows) => channel.emit(rows));
    },
    upsert(claim, channel) {
      server.upsert(user, claim, (outcome) => settle(channel, outcome));
    },
    remove(claim, channel) {
      server.remove(user, claim, (outcome) => settle(channel, outcome));
    },
  });
}

type Row = { value: Claim; dirty: boolean; deleted: boolean };

export type Local = Store<Claim, ClaimQuery> & { rows: Map<string, Row> };

// In-memory stand-in for IndexedDB, using the recommended in-row flags
// (`dirty`, `deleted`). It outlives the app instance, so an app reload
// demonstrates boot replay of the outbox.
export function makeLocal(): Local {
  const rows = new Map<string, Row>();
  return {
    rows,
    fetch(query, channel) {
      const found = [...rows.values()]
        .filter((row) => !row.deleted && match(query, row.value))
        .map((row) => clone(row.value));
      channel.emit(found);
    },
    save(claim, dirty) {
      rows.set(claim.id, { value: clone(claim), dirty, deleted: false });
    },
    remove(claim, dirty) {
      if (dirty) rows.set(claim.id, { value: clone(claim), dirty: true, deleted: true });
      else rows.delete(claim.id);
    },
    dirty: () =>
      Promise.resolve(
        [...rows.values()]
          .filter((row) => row.dirty)
          .map((row): Write<Claim> => ({ value: clone(row.value), deleted: row.deleted }))
      ),
  };
}
