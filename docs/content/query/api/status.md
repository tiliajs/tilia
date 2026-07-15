---
name: status
slug: status
kind: function
module: core
since: "0.1"
sort: 80
summary: Reactive sync state — pending ops and rejections.
signature:
  ts: |-
    status: {
      pending: number,
      rejected: Rejection<T>[]
    }
  res: |-
    status: {
      mutable pending: int,
      rejected: array<rejection<'a>>,
    }
tags: []
---

`status` is the collection's sync state. It is a tilia object: reading it inside `observe`, `watch` or a component tracks it.

- `pending` — number of ops waiting in the outbox. Every [upsert](api.html#upsert) / [remove](api.html#remove) counts immediately, including offline writes: `remote.push` is never called while offline, so the count only drains once online.
- `rejected` — ops the remote definitively refused, keyed by id (a newer rejection replaces an older one for the same id). Handle each entry with [retry](api.html#retry) or [discard](api.html#discard).

Edge cases:

- Read-path errors are **not** here — a failed fetch shows up as `Failed` in [Loadable](api.html#loadable-type), at the read site.
- The outbox is durable when a local store is configured: ops persist, reload at boot in sequence order, and replay when online. A rejection resurfaces the same way — its persisted op re-pushes and fails again after a restart.

`cards` below is the collection from [make](api.html#make). See guide chapters [Writing without waiting](guide.html#writing-without-waiting) and [When the server disagrees](guide.html#when-the-server-disagrees).

```typescript
import { observe } from "tilia";

observe(() => {
  console.log(`${cards.status.pending} pending`);
  for (const rejection of cards.status.rejected) {
    console.log(rejection.id, rejection.message);
  }
});
```

```rescript
Tilia.observe(() => {
  Console.log(`${cards.status.pending->Int.toString} pending`)
  cards.status.rejected->Array.forEach(rejection =>
    Console.log2(rejection.id, rejection.message)
  )
})
```
