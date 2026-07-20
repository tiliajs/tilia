---
name: Op
slug: op-type
kind: type
module: core
since: "0.1"
sort: 220
summary: An outbox operation — a local change not yet confirmed.
signature:
  ts: |-
    type Op<T> =
      | { op: "upsert", value: T }
      | { op: "remove", id: string }
  res: |-
    @tag("op")
    type op<'a> =
      | @as("upsert") Upsert({value: 'a})
      | @as("remove") Remove({id: string})
tags: []
---

`Op` is one outbox operation: a local change the remote has not confirmed yet.

- `Upsert` carries the full value.
- `Remove` carries only the id — a remove never requires a full value.

Adaptors meet ops in two places, always as ordered batches:

- [Remote.push](api.html#remote-type) receives every pending op not already in flight, to send to the server.
- [Local.push](api.html#local-type) receives value changes to apply to the local values table.

Order matters: apply and send ops in the order given.

See guide chapter [Tunnels](guide.html#tunnels).

```typescript
import type { Op } from "@tilia/query";

const apply = (ops: Op<Card>[]) =>
  ops.forEach((op) =>
    op.op === "upsert" ? console.log("write", op.value.id) : console.log("delete", op.id)
  );
```

```rescript
let apply = (ops: array<TiliaQuery.op<card>>) =>
  ops->Array.forEach(op =>
    switch op {
    | Upsert({value}) => Console.log2("write", value.id)
    | Remove({id}) => Console.log2("delete", id)
    }
  )
```
