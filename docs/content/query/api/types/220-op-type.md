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
// A push translates each operation to the backend's verb. A remove carries
// the id only: nothing else is needed to delete, and nothing else is sent.
const send = (op: Op<Card>) =>
  op.op === "upsert" ? api.put(`/cards/${op.value.id}`, op.value) : api.delete(`/cards/${op.id}`);
```

```rescript
// A push translates each operation to the backend's verb. A remove carries
// the id only: nothing else is needed to delete, and nothing else is sent.
let send = op =>
  switch op {
  | Upsert({value}) => Api.put(`/cards/${value.id}`, value)->Promise.thenResolve(_ => ())
  | Remove({id}) => Api.delete(`/cards/${id}`)->Promise.thenResolve(_ => ())
  }
```
