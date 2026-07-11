---
title: The pulse and the canopy
slug: the-pulse-and-the-canopy
sort: 7
refs: [tick, canopy]
---

@tilia/query owns no timers. Staleness decays and idle queries expire, but nothing happens until the application calls `tick()`. This chapter explains that inversion, and the reactive trick that lets a tick know which queries anyone still cares about.

### The heartbeat is yours

```typescript
const beat = setInterval(() => cards.tick(), 5000);
```

```rescript
let beat = setInterval(() => cards.tick(), 5000)
```

Every tick does two jobs: refresh and cleanup. Any *watched* query whose last authoritative answer is older than the `stale` window (30 seconds by default) is refetched — while online; offline, freshness simply waits, because retrying into a dead network teaches nothing. Any *unwatched* query starts an idle countdown, and one that stays unwatched past the `gc` window (5 minutes by default) is evicted: its views, its id list, its metadata. After an eviction, cached objects no longer referenced by any remaining query are dropped too — and the same release happens on disk: the query's persisted id list is removed, and local rows no remaining list claims are purged. Memory and store forget together, so neither outlives the questions that filled it. Retention follows the server's persisted answers, never a re-run of `matches` — and unsynced writes always survive.

Owning the heartbeat sounds like a chore until you need to change it: pause ticking when the tab is hidden, tick immediately on window focus, slow down on battery, drive it from a test's fake clock. Scheduling policy is application knowledge, and a library timer would just be a default you'd fight. The `stale` and `gc` windows stay honest under any cadence because they are measured in seconds against `now()` — the tick decides *when to look*, not *how time passes*.

::: pro
In tests, inject `now` and call `tick()` by hand. "31 seconds pass and the query refreshes" becomes a synchronous assertion — no waiting, no flakiness. The executable specification behind this guide does exactly that.
:::

### Liveness is observation

Both jobs hinge on the same question: is anyone *watching* this query? Most caches answer with reference counting — acquire on mount, release on unmount, leak on the path nobody tested. @tilia/query answers with tilia's observer graph instead: a query is **live** when one of its views is currently observed — read by a component, an `observe` callback, a computed that something renders — and **idle** otherwise.

Nobody registers or releases anything. The component that stopped rendering the Spanish deck stopped reading its view, so the view has no observers, so the query is idle — the fact is *derived from the reactive graph*, not tracked beside it. The canopy metaphor is the library's own: queries in the light, still photosynthesizing, versus branches the foliage has left. Only live queries burn network on refresh; only idle ones age toward eviction; switching a screen's filter retires one key and enlivens the other with no code at all.

::: story
Alice checks her stats screen, then goes back to reviewing. Five minutes later the stats query is gone as if it had never been asked. When she looks again next week, it will simply be asked again.
:::

`canopy()` returns the current live and idle key lists — a debug window into the split, good for a dev overlay or an assertion that a screen releases what it reads.

The lifecycle is now complete: shape, reads, writes, disagreement, adapters, time. What remains is the housekeeping at the edges of a session — and a step back.
