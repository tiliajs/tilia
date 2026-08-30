---
name: Canopy
slug: canopy-type
kind: type
module: core
since: "0.1"
sort: 295
summary: List observed and cached query keys.
tags: []
signature.ts: |-
  type Canopy = {
    live: string[],
    idle: string[]
  }
signature.res: |-
  type canopy = {
    live: array<string>,
    idle: array<string>,
  }
label: Canopy
---

`Canopy` is returned by [_canopy](api.html#canopy). `live` contains observed query keys; `idle` contains unobserved keys retained until memory expiry.

```typescript
const observed = (canopy: Canopy) => canopy.live.length;
```

```rescript
let observed = (canopy: TiliaQuery.canopy) => canopy.live->Array.length
```
