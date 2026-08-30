---
name: StoreExpiry
slug: store-expiry-type
kind: type
module: core
since: "0.1"
sort: 330
summary: Configure retained query records in local storage.
tags: []
signature.ts: |-
  type StoreExpiry = {
    local: number
  }
signature.res: |-
  type Store.expiry = {
    local: float,
  }
label: StoreExpiry
---

`StoreExpiry` contains the shipped store's `local` duration in milliseconds.
It controls how long an unheld query record remains in the retention graph
after that query was last seen. The default is `2_592_000_000` (30 days).

Rows have no separate grace period. Each purge removes rows that no surviving
query record or pending operation references, so a row omitted by a fresh
answer may be swept immediately even when its former query record is young.

Local purge runs from the store half of [tick](api.html#tick). Engine refresh and in-memory query eviction use the separate [Expiry](api.html#expiry-type).

```typescript
const expiry: StoreExpiry = { local: 7 * 24 * 60 * 60 * 1_000 };
```

```rescript
let expiry: TiliaQuery.Store.expiry = {local: 604_800_000.}
```
