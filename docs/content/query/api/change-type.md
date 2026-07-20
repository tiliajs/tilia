---
name: Change
slug: change-type
kind: type
module: core
since: "0.1"
sort: 225
summary: Local context presented when a remote value arrives.
signature:
  ts: |-
    type Change<T> =
      | { change: "clean", value: T }
      | { change: "created", edited: T }
      | { change: "updated", base: T, edited: T }
      | { change: "removed", base: T }
  res: |-
    @tag("change")
    type change<'a> =
      | @as("clean") Clean({value: 'a})
      | @as("created") Created({edited: 'a})
      | @as("updated") Updated({base: 'a, edited: 'a})
      | @as("removed") Removed({base: 'a})
tags: []
---

`Change` is the local context passed to [Config](api.html#config-type)`.merge` when a remote value arrives.

- `Clean` carries the current value when there is no local write.
- `Created` carries a new local value not yet confirmed remotely.
- `Updated` carries the `base` value and latest local `edited` value. Together with the remote value, these are the three inputs to a three-way merge.
- `Removed` carries the value deleted locally while its remove is pending.

The merge runs inside [`Tilia.batch`](../api.html#batch). Mutate the local value in place and return `true` when the histories reconcile. Return `false` to show remote truth and record the corresponding [Rejection](api.html#rejection-type).

See guide chapter [When the world returns](guide.html#when-the-world-returns).

```typescript
import type { Change } from "@tilia/query";

const merge = (change: Change<Card>, remote: Card) => {
  if (change.change === "clean") Object.assign(change.value, remote);
  return true;
};
```

```rescript
open TiliaQuery

let merge = (~change, ~remote) => {
  switch change {
  | Clean({value}) => value.translation = remote.translation
  | Created(_) | Updated(_) | Removed(_) => ()
  }
  true
}
```
