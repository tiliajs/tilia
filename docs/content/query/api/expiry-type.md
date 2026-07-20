---
name: Expiry
slug: expiry-type
kind: type
module: core
since: "0.1"
sort: 290
summary: Timing configuration — refresh, memory and local tiers.
signature:
  ts: |-
    type Expiry = {
      refresh: number,
      memory: number,
      local: number
    }
  res: |-
    type expiry = {
      refresh: float,
      memory: float,
      local: float,
    }
tags: []
---

`Expiry` sets the three timing tiers, all in milliseconds. Memory and local are different **tiers**, not different strictness: memory is a small RAM cache of the queries being (or recently) observed — seconds to minutes. Local is the durable superset on disk — days to weeks. 100 MB is fine in local; it is not fine in memory.

- `refresh` — interval between refreshes for observed queries. Default: `30_000` (30 s). A query whose channel declared `live` is skipped — its source keeps it fresh.
- `memory` — how long an unobserved query result stays in RAM. Default: `300_000` (5 min). Eviction only frees memory: the data stays in the local store, and reopening the query re-materializes it from there. Eviction also closes the query's fetch — an unobserved live query keeps its subscription open until this expiry, then its `finally` teardown runs.
- `local` — how long a query is retained in the local store since its last refresh. Default: `2_592_000_000` (30 days). The local purge runs against it, at most once per `local / 8`.

All timing takes effect only when [tick](api.html#tick) runs — the engine owns no timers.

See guide chapters [Reads answer twice](guide.html#reads-answer-twice) and [A week at Nora's](guide.html#a-week-at-noras).

```typescript
import type { Expiry } from "@tilia/query";

const expiry: Expiry = {
  refresh: 15_000, // 15 s
  memory: 120_000, // 2 min
  local: 7 * 24 * 3_600_000, // one week
};
```

```rescript
let expiry: TiliaQuery.expiry = {
  refresh: 15_000., // 15 s
  memory: 120_000., // 2 min
  local: 604_800_000., // one week
}
```
