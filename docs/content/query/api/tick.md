---
name: .tick
slug: tick
kind: function
module: core
since: "0.1"
sort: 90
summary: Stale refresh and garbage collection, driven by your own scheduler.
signature:
  ts: "collection.tick(): void"
  res: "collection.tick: unit => unit"
tags: []
---

The library owns no timers; the application calls `tick` from whatever scheduler it already has. Each tick refetches watched queries whose last authoritative answer is older than `stale` (while online), and ages unwatched queries toward eviction after `gc` seconds — views, id list and metadata are dropped, then cached objects no longer referenced by any query. Eviction also releases retention: the query's persisted record is dropped (`removeQuery`) and local rows no remaining record references are purged. Unsynced writes always survive — retention never touches dirty rows or tombstones.

Liveness is read from tilia's observer graph: a query is watched when one of its views is currently observed. No registration, no reference counting. See [canopy](api.html#canopy) and guide chapter [The pulse and the canopy](docs.html#the-pulse-and-the-canopy).

In tests, inject `now` in [Config](api.html#config-type) and call `tick` by hand — time becomes a synchronous assertion.

```typescript
const beat = setInterval(() => cards.tick(), 5000);
```

```rescript
let beat = setInterval(() => cards.tick(), 5000)
```
