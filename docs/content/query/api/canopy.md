---
name: .canopy
slug: canopy
kind: function
module: core
since: "0.1"
sort: 100
summary: Debug view of observed query keys, split into live and idle.
signature:
  ts: "collection.canopy(): Canopy"
  res: "collection.canopy: unit => canopy"
tags: []
---

`canopy` returns the current query keys split by liveness: `live` keys have an observed view ([one](api.html#one), [array](api.html#array) or [dict](api.html#dict) currently read by an observer), `idle` keys do not and are aging toward eviction on [tick](api.html#tick).

It is a debug helper — good for a dev overlay, or a test asserting that a screen releases the queries it reads.

```typescript
const { live, idle } = cards.canopy();
console.log(`live: ${live.length}, idle: ${idle.length}`);
```

```rescript
let {live, idle} = cards.canopy()
Js.log2(Array.length(live), Array.length(idle))
```
