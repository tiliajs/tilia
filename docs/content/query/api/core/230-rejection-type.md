---
name: Rejection
slug: rejection-type
kind: type
module: core
since: "0.1"
sort: 230
summary: Preserve context for a reverted optimistic operation.
tags: []
signature.ts: |-
  type Rejection<T> =
    | { rejection: "createConflict", edited: T }
    | { rejection: "createFailed", edited: T, message: string }
    | { rejection: "updateConflict", base: T, edited: T }
    | { rejection: "updateFailed", base: T, edited: T, message: string }
    | { rejection: "removeConflict", base: T }
    | { rejection: "removeFailed", base: T, message: string }
signature.res: |-
  @tag("rejection")
  type rejection<'a> =
    | @as("createConflict") CreateConflict({edited: 'a})
    | @as("createFailed") CreateFailed({edited: 'a, message: string})
    | @as("updateConflict") UpdateConflict({base: 'a, edited: 'a})
    | @as("updateFailed") UpdateFailed({base: 'a, edited: 'a, message: string})
    | @as("removeConflict") RemoveConflict({base: 'a})
    | @as("removeFailed") RemoveFailed({base: 'a, message: string})
label: Rejection
---

`Rejection` records an optimistic create, update, or remove that was reverted. Conflict variants come from a remote value that `merge` could not reconcile, including one supplied through `WriteChannel.conflict`. Failed variants come from `WriteChannel.reject` or `fail` and carry the remote message.

`edited` is the latest local edit. `base` is the value it started from, or the removed value. These fields are JSON-copied snapshots; the current remote value already stands in the store.

At most one rejection exists per id. A later write clears it. [retry](api.html#retry) queues its work again; [discard](api.html#discard) drops only the record.

```typescript
const failed = (rejection: Rejection<Card>) => "message" in rejection;
```

```rescript
let failed = rejection =>
  switch rejection {
  | CreateFailed(_) | UpdateFailed(_) | RemoveFailed(_) => true
  | CreateConflict(_) | UpdateConflict(_) | RemoveConflict(_) => false
  }
```
