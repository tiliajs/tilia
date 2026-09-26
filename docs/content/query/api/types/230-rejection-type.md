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
// One line per refused write, in outbox order: retry the first and the ones
// it caused may follow. Conflicts have no message of their own; failures
// carry the server's.
const describe = (rejection: Rejection<Card>) => {
  switch (rejection.rejection) {
    case "createConflict": return `"${rejection.edited.front}" already exists on the server`;
    case "updateConflict": return `"${rejection.edited.front}" changed on the server while you edited it`;
    case "removeConflict": return `"${rejection.base.front}" changed on the server before it was removed`;
    case "removeFailed": return `"${rejection.base.front}": ${rejection.message}`;
    default: return `"${rejection.edited.front}": ${rejection.message}`;
  }
};
```

```rescript
// One line per refused write, in outbox order: retry the first and the ones
// it caused may follow. Conflicts have no message of their own; failures
// carry the server's.
let describe = rejection =>
  switch rejection {
  | CreateConflict({edited}) => `"${edited.front}" already exists on the server`
  | UpdateConflict({edited}) => `"${edited.front}" changed on the server while you edited it`
  | RemoveConflict({base}) => `"${base.front}" changed on the server before it was removed`
  | CreateFailed({edited, message}) | UpdateFailed({edited, message}) => `"${edited.front}": ${message}`
  | RemoveFailed({base, message}) => `"${base.front}": ${message}`
  }
```
