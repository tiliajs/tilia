---
name: status
slug: status
kind: function
module: core
since: "0.1"
sort: 80
summary: Reactive sync state — pending ops and rejections.
signature:
  ts: "status: Status<T>"
  res: "status: status<'a>"
tags: []
---

`status` is the collection's reactive [Status](api.html#status-type). It is a tilia object: reading it inside `observe`, `watch` or a component tracks it.

- `pending` — number of ops waiting in the outbox. Every [upsert](api.html#upsert) / [remove](api.html#remove) counts immediately, including offline writes: `remote.push` is never called while offline, so the count only drains once online.
- `rejected` — contexts for conflicts and writes the remote definitively refused, keyed by value id (a newer rejection replaces an older one). Resolve or ignore each entry, then remove it with [dismiss](api.html#dismiss).

Edge cases:

- Read-path errors are **not** here — a failed fetch shows up as `Failed` in [Loadable](api.html#loadable-type), at the read site.
- The outbox is durable when a local store is configured: pending ops persist, reload at boot in sequence order, and replay when online. Rejected ops have already left the outbox; rejection contexts are not persisted.

`cards` below is the collection from [make](api.html#make). See guide chapters [Tunnels](guide.html#tunnels) and [When the world returns](guide.html#when-the-world-returns).

```typescript
import { observe } from "tilia";

observe(() => {
  console.log(`${cards.status.pending} pending`);
  for (const rejection of cards.status.rejected) {
    console.log(rejection.rejection);
  }
});
```

```rescript
Tilia.observe(() => {
  Console.log(`${cards.status.pending->Int.toString} pending`)
  cards.status.rejected->Array.forEach(rejection =>
    switch rejection {
    | CreateConflict(_) => Console.log("create conflict")
    | CreateFailed(_) => Console.log("create failed")
    | UpdateConflict(_) => Console.log("update conflict")
    | UpdateFailed(_) => Console.log("update failed")
    | RemoveConflict(_) => Console.log("remove conflict")
    | RemoveFailed(_) => Console.log("remove failed")
    }
  )
})
```
