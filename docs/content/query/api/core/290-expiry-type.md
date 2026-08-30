---
name: Expiry
slug: expiry-type
kind: type
module: core
since: "0.1"
sort: 290
summary: Configure engine refresh and memory timing.
tags: []
signature.ts: |-
  type Expiry = {
    refresh: number,
    memory: number
  }
signature.res: |-
  type expiry = {
    refresh: float,
    memory: float,
  }
label: Expiry
---

`Expiry` contains engine-owned durations in milliseconds:

- `refresh` is the refresh interval for observed non-live queries. Default when `expiry` is omitted: `30_000`.
- `memory` is how long an unobserved query stays in memory. Eviction closes its find and tells the store to forget the query, but leaves persisted data intact. Default: `300_000`.

All checks run from [tick](api.html#tick). Local row retention belongs to [StoreExpiry](api.html#store-expiry-type).

```typescript
const expiry: Expiry = { refresh: 15_000, memory: 120_000 };
```

```rescript
let expiry: TiliaQuery.expiry = {refresh: 15_000., memory: 120_000.}
```
