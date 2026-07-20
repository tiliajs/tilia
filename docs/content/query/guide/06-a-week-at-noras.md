---
title: A week at Nora's
slug: a-week-at-noras
sort: 6
refs: [local-type, local-channel-type, expiry-type, tick]
---

A tunnel tests whether offline *works*. A week tests whether offline was *designed*. Seven days without a signal means restarts, storage limits, and a growing pile of unsent writes — and the app code, notably, does nothing special about any of it. Nothing in Alice's features branches on connectivity. The engine and one adaptor absorb the whole week.

### The local adaptor

The durable half of every promise so far lives behind the `local` config: a table for rows, plus a small string store for the engine bookkeeping (query records, outbox entries). The adaptor is command-only plumbing over whatever the platform offers (IndexedDB in a browser, SQLite in an app), written once:

```typescript
const cardStore: Local<Card, DeckQuery> = {
  fetch, // answer a query from the values table, or say unknown()
  push,  // apply ordered mutations
  set,   // engine bookkeeping: write one entry
  get,   // engine bookkeeping: read entries back
  ids,   // list every stored row id (for the purge below)
};
```

```rescript
let cardStore: TiliaQuery.local<deckQuery, card> = {
  fetch, // answer a query from the values table, or say unknown()
  push,  // apply ordered mutations
  set,   // engine bookkeeping: write one entry
  get,   // engine bookkeeping: read entries back
  ids,   // list every stored row id (for the purge below)
}
```

With it configured, the week holds together by construction. Reads answer from the values table — `Loaded`, honest `fresh: false`, all week. Writes apply to memory and disk, and their outbox entries are persisted too. When the phone dies at two percent and restarts, the outbox loads back in sequence order and the app resumes as if nothing happened, because as far as the data is concerned, nothing did. The outbox is data, not process state.

### Three clocks

Retention is governed by three independent expiries, each answering a different question:

```typescript
expiry: {
  refresh: 30_000,            // is this result current? — 30 seconds
  memory: 300_000,            // should this be kept in RAM? - 5 minutes
  local: 30 * 24 * 3_600_000, // should local store keep this? - 30 days
},
```

```rescript
expiry: {
  refresh: 30_000,            // is this result current? — 30 seconds
  memory: 300_000,            // should this be kept in RAM? - 5 minutes
  local: 30 * 24 * 3_600_000, // should local store keep this? - 30 days
},
```

Expiring one layer never implies expiring another. A result going stale (refresh) does not evict it from RAM; leaving RAM (memory) does not touch the disk; and the disk (local) forgets only what was unseen for weeks. 

The local entry (30 days) measures *not used*, not time offline. Each time Alice views the deck, its persisted query is seen again, so its cards remain on disk even after months without connectivity. Only a query left unopened for thirty days becomes eligible for purging.

The disk clock comes with a garbage collector: once in a while, a purge walks the persisted query records, marks every row a retained query still references, and sweeps the rest — mark and sweep, the same reachability idea as any GC. One guarantee in it matters more than the mechanism: **pending writes are roots**. An edit that has not reached the server cannot be purged, ever, no matter how old the queries around it grow. Retention tidies memory of the *server's* data; it has no authority over promises not yet kept.

All of this runs inside the same `tick()` the app was already calling. No daemons, no timers of the engine's own — the week is maintained by the heartbeat.

::: story
Evenings at Nora's kitchen table, the phone propped against the fruit bowl. Alice is reviewing her cards. She updates the clumsy example sentence on *echar de menos*, and adds new cards from dinner conversations: *sobremesa* has no direct English translation, so she writes *time spent talking at the table after a meal* . The counter reads "41 waiting" by Friday, a number she has stopped reading as a warning. It isn't one. It is an inventory of things the app is keeping for her.
:::

::: pro
Never dress `pending` up as an error state offline. Forty-one held writes on day five is the system working exactly as designed — show it like a draft count, not a failure count.
:::

Forty-one operations, one week, two versions of a few shared cards — because Alice's study group kept living while she was in the hills. The bus back down is where the deck finds out.
