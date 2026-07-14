---
name: tick
slug: tick
kind: function
module: core
since: "0.1"
sort: 110
summary: Time heartbeat — the engine owns no timers.
signature:
  ts: "tick: () => void"
  res: "tick: unit => unit"
tags: []
---

`tick` is the collection's heartbeat. The engine owns no timers: everything time-based happens inside `tick`, plus reactions to `remote.online` transitions. Call it on an interval; anything ≤ `expiry.refresh / 2` is fine.

One tick can:

- Refresh observed queries whose last remote delivery is older than `expiry.refresh` — except live queries, whose source keeps them fresh.
- Flip a stale result to `fresh: false` (see [Loadable](api.html#loadable-type)) and retry failed non-live queries.
- Update observed queries' last-seen time, and evict unobserved queries past `expiry.memory` — eviction closes the query's fetch, running its `finally` teardown.
- Push pending ops that are not already in flight.
- Run the local purge — gated: on the first tick after boot, then at most once per `expiry.local / 8` (3.75 days at the default).

Only the purge is gated; refresh checks, last-seen updates and memory expiry run on every tick.

See [Expiry](api.html#expiry-type), [dispose](api.html#dispose), and guide chapter [The pulse and the canopy](docs.html#the-pulse-and-the-canopy). `cards` is the collection from [make](api.html#make).

```typescript
const timer = setInterval(cards.tick, 10_000);
```

```rescript
let timer = setInterval(cards.tick, 10_000)
```
