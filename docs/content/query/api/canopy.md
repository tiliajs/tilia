---
name: _canopy
slug: canopy
kind: function
module: core
since: "0.1"
sort: 140
summary: Debug view — observed vs cached query keys.
signature:
  ts: |-
    _canopy: () => {
      live: string[],
      idle: string[]
    }
  res: |-
    _canopy: unit => {
      live: array<string>,
      idle: array<string>,
    }
tags: []
---

`_canopy` answers which queries the engine currently holds in memory, by key:

- `live` — observed right now: something is reading the query's result inside an observer.
- `idle` — cached but unobserved: still in memory, waiting for `expiry.memory` to evict it.

There is no registration API behind this. Reading a result inside an observer is what keeps a query live; the engine asks tilia's observer graph. This is the same signal `tick` uses to decide what to refresh and what to evict.

The underscore marks a tooling entry point — meant for debugging, devtools and library authors, not everyday application code.

`cards` is the collection from [make](api.html#make). See guide chapter [The pulse and the canopy](docs.html#the-pulse-and-the-canopy).

```typescript
const { live, idle } = cards._canopy();
console.log("observed:", live, "cached:", idle);
```

```rescript
let {live, idle} = cards._canopy()
Console.log4("observed:", live, "cached:", idle)
```
