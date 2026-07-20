---
name: Receive
slug: receive-type
kind: type
module: core
since: "0.1"
sort: 245
summary: Inbound facts pushed by the remote.
signature:
  ts: |-
    type Receive<T> = {
      changed: (values: T[]) => void,
      removed: (ids: string[]) => void
    }
  res: |-
    type receive<'a> = {
      changed: array<'a> => unit,
      removed: array<string> => unit,
    }
tags: []
---

`Receive` accepts facts volunteered by the server, such as websocket deliveries:

- [changed](api.html#receive-changed) receives complete changed values.
- [removed](api.html#receive-removed) receives ids deleted remotely.

Deliveries update matching queries and local storage, reconcile pending changes, and do not affect query freshness.

See guide chapter [Two devices, one deck](guide.html#two-devices-one-deck).
