---
name: tick
slug: tick
kind: function
module: core
since: "0.1"
sort: 110
summary: Run the engine and store heartbeat.
tags: []
signature.ts: "tick: () => void"
signature.res: "tick: unit => unit"
label: query.tick()
---

`tick` runs all time-based work; the engine owns no timers. Call it at least twice per configured refresh interval.

The engine first refreshes observed non-live queries, lowers aged claims, updates observation times, and evicts idle queries past `Expiry.memory`. It then calls the store heartbeat, which handles local purge and push retries. [Expiry](api.html#expiry-type) and [StoreExpiry](api.html#store-expiry-type) configure the two halves independently.

```typescript
const timer = setInterval(query.tick, 10_000);
```

```rescript
let timer = setInterval(query.tick, 10_000)
```
