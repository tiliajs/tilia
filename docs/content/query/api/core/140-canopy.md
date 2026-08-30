---
name: _canopy
slug: canopy
kind: function
module: core
since: "0.1"
sort: 140
summary: Inspect observed and idle query keys.
tags: []
signature.ts: "_canopy: () => Canopy"
signature.res: "_canopy: unit => canopy"
label: query._canopy()
---

`_canopy` returns a [Canopy](api.html#canopy-type) with the query keys currently observed (`live`) and cached but unobserved (`idle`).

It is an internal/debug surface for tooling. The engine uses the same observation state to refresh and evict queries.

```typescript
console.log(query._canopy());
```

```rescript
Console.log(query._canopy())
```
