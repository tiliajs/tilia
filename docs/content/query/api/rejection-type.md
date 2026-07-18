---
name: Rejection
slug: rejection-type
kind: type
module: core
since: "0.1"
sort: 230
summary: Context for an optimistic operation that was reverted.
signature:
  ts: |-
    type Rejection<T> =
      | { rejection: "createConflict"; edited: T }
      | { rejection: "createFailed"; edited: T; message: string }
      | { rejection: "updateConflict"; base: T; edited: T }
      | { rejection: "updateFailed"; base: T; edited: T; message: string }
      | { rejection: "removeConflict"; base: T }
      | { rejection: "removeFailed"; base: T; message: string }
  res: |-
    @tag("rejection")
    type rejection<'a> =
      | @as("createConflict") CreateConflict({edited: 'a})
      | @as("createFailed") CreateFailed({edited: 'a, message: string})
      | @as("updateConflict") UpdateConflict({base: 'a, edited: 'a})
      | @as("updateFailed") UpdateFailed({base: 'a, edited: 'a, message: string})
      | @as("removeConflict") RemoveConflict({base: 'a})
      | @as("removeFailed") RemoveFailed({base: 'a, message: string})
tags: []
---

`Rejection` is the context kept when an optimistic operation was reverted — either a *conflict* (the [merge](api.html#config-type) refused a remote value) or a *failure* (the remote definitively refused the push). Rejections live in [status](api.html#status)`.rejected`.

- `edited` is the latest local edit, `base` the value it started from — or the removed value, for remove variants.
- Failed variants carry the remote's `message`.
- The current remote value is already in memory: remote truth is what the queries show, the rejection holds the local side of the story.
- At most one rejection is retained per value id: a newer rejection replaces the older.

Keeping your version is an ordinary write — `upsert` the `edited` value and it wins like any other write. [dismiss](api.html#dismiss) retires the context once a human has seen it.

See guide chapter [When the world returns](guide.html#when-the-world-returns).

```typescript
import type { Rejection } from "@tilia/query";

const describe = (r: Rejection<Card>) =>
  "message" in r ? `refused: ${r.message}` : "two versions of this card";
```

```rescript
let describe = (r: TiliaQuery.rejection<card>) =>
  switch r {
  | CreateFailed({message}) | UpdateFailed({message}) | RemoveFailed({message}) =>
    `refused: ${message}`
  | CreateConflict(_) | UpdateConflict(_) | RemoveConflict(_) => "two versions of this card"
  }
```
