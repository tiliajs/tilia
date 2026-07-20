---
name: Status
slug: status-type
kind: type
module: core
since: "0.1"
sort: 235
summary: Reactive write state — pending operations and rejection contexts.
signature:
  ts: |-
    type Status<T> = {
      pending: number,
      rejected: Rejection<T>[]
    }
  res: |-
    type status<'a> = {
      pending: int,
      rejected: array<rejection<'a>>,
    }
tags: []
---

`Status` is the reactive write state exposed as [TiliaQuery.status](api.html#status).

- `pending` counts operations waiting in the outbox.
- `rejected` contains conflicts and definitive write failures that have reverted to remote truth.

Read failures are returned through [Loadable](api.html#loadable-type), not through `Status`.
