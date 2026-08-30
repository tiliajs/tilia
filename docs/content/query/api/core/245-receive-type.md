---
name: Receive
slug: receive-type
kind: type
module: core
since: "0.1"
sort: 245
summary: Accept authoritative facts pushed by the server.
tags: []
signature.ts: |-
  type Receive<T> = {
    changed: (values: T[]) => void,
    removed: (ids: string[]) => void
  }
signature.res: |-
  type receive<'a> = {
    changed: array<'a> => unit,
    removed: array<string> => unit,
  }
label: Receive
---

`Receive` is exposed by the application [Store](api.html#store-type) handle for server-initiated facts.

[receive.changed](api.html#receive-changed) applies complete values; [receive.removed](api.html#receive-removed) applies deleted ids. Both update matching queries, persistence, and pending-write reconciliation without changing query freshness.

```typescript
const receive: Receive<Card> = store.receive;
```

```rescript
let receive: TiliaQuery.receive<card> = store.receive
```
