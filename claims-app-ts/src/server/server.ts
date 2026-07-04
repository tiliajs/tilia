import { tilia } from "tilia";
import { clone, limit, match, type Claim, type ClaimQuery } from "../app/claim";

export type Outcome =
  | { kind: "saved"; claim: Claim }
  | { kind: "conflict"; claim: Claim }
  | { kind: "rejected"; message: string };

// Last operation per claim id, drives the server pane animations.
export type Touch = { by: string; kind: "read" | "write"; seq: number };

// A registered live query: `sig` fingerprints the last pushed result so a
// write only pushes to clients whose result actually changed.
export type Sub = {
  id: number;
  client: string;
  query: ClaimQuery;
  push: (rows: Claim[]) => void;
  sig: string;
  seq: number;
};

export type Server = {
  rows: Record<string, Claim>;
  latency: number;
  live: boolean;
  touches: Record<string, Touch>;
  // Reads answered (fetches and subscriptions): writes should not add any.
  fetches: number;
  subs: Sub[];
  fetch(by: string, query: ClaimQuery, reply: (rows: Claim[]) => void): void;
  subscribe(by: string, query: ClaimQuery, push: (rows: Claim[]) => void): () => void;
  upsert(by: string, claim: Claim, reply: (outcome: Outcome) => void): void;
  remove(by: string, claim: Claim, reply: (outcome: Outcome) => void): void;
};

const sig = (rows: Claim[]) =>
  rows
    .map((claim) => `${claim.id}:${claim.version}`)
    .sort()
    .join("|");

export function makeServer(seed: Claim[]): Server {
  let seq = 0;
  let subId = 0;
  const rows: Record<string, Claim> = {};
  for (const claim of seed) rows[claim.id] = { ...claim, version: 1 };

  // The core calls the adapters (and through them this server) inside a
  // tracked scope: reactive reads there would refetch queries whenever the
  // value changes. `later` moves all server work out of the tracked scope.
  const later = (fn: () => void) => queueMicrotask(() => setTimeout(fn, server.latency));

  const touch = (id: string, by: string, kind: "read" | "write") => {
    seq += 1;
    server.touches[id] = { by, kind, seq };
  };

  const matching = (query: ClaimQuery) => Object.values(server.rows).filter((claim) => match(query, claim));

  // After an accepted write, push the new result to every subscription whose
  // result set changed (content, membership, or both).
  const broadcast = () => {
    for (const sub of server.subs) {
      const found = matching(sub.query);
      const s = sig(found);
      if (s !== sub.sig) {
        sub.sig = s;
        sub.seq += 1;
        sub.push(clone(found));
      }
    }
  };

  const server: Server = tilia({
    rows,
    latency: 800,
    live: false,
    touches: {},
    fetches: 0,
    subs: [],

    fetch(by, query, reply) {
      later(() => {
        server.fetches += 1;
        const found = matching(query);
        for (const claim of found) touch(claim.id, by, "read");
        reply(clone(found));
      });
    },

    subscribe(by, query, push) {
      subId += 1;
      const id = subId;
      let dead = false;
      later(() => {
        if (dead) return;
        server.fetches += 1;
        const found = matching(query);
        for (const claim of found) touch(claim.id, by, "read");
        server.subs.push({ id, client: by, query, push, sig: sig(found), seq: 1 });
        push(clone(found));
      });
      return () => {
        // Cleanups also run in tracked scope: defer the registry write.
        dead = true;
        queueMicrotask(() => {
          server.subs = server.subs.filter((s) => s.id !== id);
        });
      };
    },

    upsert(by, claim, reply) {
      later(() => {
        const current = server.rows[claim.id];
        if (current && current.version !== claim.version) {
          reply({ kind: "conflict", claim: clone(current) });
        } else if (claim.estimate > limit) {
          reply({ kind: "rejected", message: "estimate above authority limit" });
        } else {
          const saved = { ...clone(claim), version: claim.version + 1 };
          server.rows[claim.id] = saved;
          touch(claim.id, by, "write");
          reply({ kind: "saved", claim: clone(saved) });
          broadcast();
        }
      });
    },

    remove(_by, claim, reply) {
      later(() => {
        const current = server.rows[claim.id];
        if (current && current.version !== claim.version) {
          reply({ kind: "conflict", claim: clone(current) });
        } else {
          delete server.rows[claim.id];
          delete server.touches[claim.id];
          reply({ kind: "saved", claim: clone(claim) });
          broadcast();
        }
      });
    },
  });

  return server;
}
