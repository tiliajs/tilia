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
// A devtools line: what the UI is asking right now, and what is kept warm
// for a return visit until memory expiry evicts it.
const report = ({ live, idle }: Canopy) => `${live.length} observed, ${idle.length} kept warm`;
```

```rescript
// A devtools line: what the UI is asking right now, and what is kept warm
// for a return visit until memory expiry evicts it.
let report = ({live, idle}: canopy) =>
  `${live->Array.length->Int.toString} observed, ${idle->Array.length->Int.toString} kept warm`
```
