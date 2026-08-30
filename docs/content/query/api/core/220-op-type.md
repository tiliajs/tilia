---
name: Op
slug: op-type
kind: type
module: core
since: "0.1"
sort: 220
summary: Describe one unconfirmed outbox operation.
tags: []
signature.ts: |-
  type Op<T> =
    | { op: "upsert", value: T }
    | { op: "remove", id: string }
signature.res: |-
  @tag("op")
  type op<'a> =
    | @as("upsert") Upsert({value: 'a})
    | @as("remove") Remove({id: string})
label: Op
---

`Op` is one optimistic write not yet confirmed by the remote. `upsert` carries the full value; `remove` carries only its id.

[Remote.push](api.html#remote-type) receives operations as an ordered batch. Confirm them through the matching [WriteChannel](api.html#write-channel-type) method.

```typescript
const id = (op: Op<Card>) => op.op === "upsert" ? op.value.id : op.id;
```

```rescript
let id = op =>
  switch op {
  | Upsert({value}) => value.id
  | Remove({id}) => id
  }
```
