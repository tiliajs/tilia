---
name: Status
slug: status-type
kind: type
module: core
since: "0.1"
sort: 235
summary: Represent reactive outbox and rejection state.
tags: []
signature.ts: |-
  type Status<T> = {
    pending: number,
    rejected: Rejection<T>[]
  }
signature.res: |-
  type status<'a> = {
    pending: int,
    rejected: array<rejection<'a>>,
  }
label: Status
---

`Status` is the reactive write state at [store.status](api.html#status).

`pending` counts operations waiting in the outbox. `rejected` is ordered by the outbox, even when replies arrived in another order, so a cascade can be retried cause-first. It contains at most one record per id, and any new write to that id clears the record.

Read failures are returned through [Loadable](api.html#loadable-type).

```typescript
const syncing = (status: Status<Card>) => status.pending > 0;
```

```rescript
let syncing = (status: TiliaQuery.status<card>) => status.pending > 0
```
