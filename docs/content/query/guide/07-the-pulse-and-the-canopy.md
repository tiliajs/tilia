---
title: The pulse and the canopy
slug: the-pulse-and-the-canopy
sort: 7
refs: [tick, canopy, expiry-type]
---

@tilia/query owns no timers. Freshness decays, idle queries expire, the disk gets swept — but nothing happens until the application calls `tick()`. This chapter explains that inversion, and the reactive trick that lets a tick know which queries anyone still cares about.

### The heartbeat is yours

```typescript
const beat = setInterval(() => cards.tick(), 5000);
```

```rescript
let beat = setInterval(() => cards.tick(), 5000)
```

Any interval up to half the refresh window is fine. Each tick does the same rounds:

- **Refresh** — every watched query whose last remote delivery is older than the refresh window (`expiry.refresh`, 30 seconds by default) is refetched, while online. Live queries are skipped — their source is their freshness. Failed queries re-enter this same loop: one retry per window.
- **Honesty** — results past the window flip to `fresh: false`, with the online grace period of [chapter 3](#reads-answer-twice).
- **Eviction** — a watched query re-stamps its last-seen time on every tick, so only unwatched ones age. Past the memory window (`expiry.memory`, 5 minutes by default), an unwatched query's in-memory entry is dropped and its fetch is closed — an idle live subscription runs its teardown here — and cached values no remaining query references leave memory with it. Disk is untouched: eviction frees RAM, nothing else, and reopening the query re-materializes it from the local store.
- **The push** — pending operations not in flight get another chance, as [chapter 4](#writing-without-waiting) described.

Owning the heartbeat sounds like a chore until you need to change it: pause ticking when the tab is hidden, tick immediately on window focus, slow down on battery, drive it from a test's fake clock. Scheduling policy is application knowledge, and a library timer would just be a default you'd fight. The windows stay honest under any cadence because they are measured against `now()` — the tick decides *when to look*, not *how time passes*.

::: pro
In tests, inject `now` and call `tick()` by hand. "31 seconds pass and the query refreshes" becomes a synchronous assertion — no waiting, no flakiness. The executable specification behind this guide does exactly that.
:::

### Liveness is observation

Refresh and eviction hinge on the same question: is anyone *watching* this query? Most caches answer with reference counting — acquire on mount, release on unmount, leak on the path nobody tested. @tilia/query answers with tilia's observer graph instead: a query is **live** when its result is currently being read by an observer — a component, an `observe` callback, a computed that something renders — and **idle** otherwise.

Nobody registers or releases anything. The component that stopped rendering the Spanish deck stopped reading its result, so the result has no observers, so the query is idle — the fact is *derived from the reactive graph*, not tracked beside it. The canopy metaphor is the library's own: queries in the light, still photosynthesizing, versus branches the foliage has left. Only live queries burn network on refresh; only idle ones age toward eviction; switching a screen's filter retires one key and enlivens the other with no code at all.

`_canopy()` returns the current live and idle key lists — the underscore marks a tooling entry point, good for a dev overlay or an assertion that a screen releases what it reads. It is the same signal the tick itself consults.

### The third clock: the purge

Memory forgets in minutes. Disk is allowed weeks: the local window (`expiry.local`, 30 days by default) answers a different question — how long can a device stay away and still come home to its data? The default is sized for coming back from a long trip with margin to spare.

The purge is garbage collection for the local store, and it works by proof, in the mark-and-sweep sense:

- The **query registry** persists, for each query, the query itself, its latest row ids, and when it was last seen. Queries stay plain data precisely so that `matches` can run against records whose query left memory sessions ago.
- Records unseen past the local window are dropped. Every row id listed by a surviving record is marked. Pending and rejected operations are roots too — an unsynced write can never be swept, no matter how old. Then every unmarked row is removed.
- A written row that no record claims gets a **synthetic record** so it survives until a real query adopts it — each purge offers such rows to every persisted query — or until the local window expires it.

Purging costs local I/O, so it alone is gated: it runs on the first tick after boot, then at most once per eighth of the local window — 3.75 days at the default. Everything else above runs on every tick.

This is also where [chapter 3](#reads-answer-twice)'s write-through debt settles. Rows that fell out of every server answer linger on disk only until a sweep proves no retained query claims them. The local store is bounded by proof, not by guesswork — eventually, but certainly.

::: story
Alice checks her stats screen, then goes back to reviewing. Five minutes later the stats query is gone from memory as if it had never been asked; its rows stay on disk for the weeks it would take her to actually stop caring. Next week the same tap asks the same question — and disk answers first. The week at Nora's, for the record, fit inside the local window five times over.
:::

The lifecycle is now complete: shape, reads, writes, disagreement, adapters, time. What remains is the exit — and a step back.
