---
name: remove
slug: remove
kind: function
module: core
since: "0.1"
sort: 50
summary: Optimistically remove a value through the store handle.
tags: []
signature.ts: "remove: (id: string) => void"
signature.res: "remove: string => unit"
label: store.remove(id)
---

`remove` belongs to the [Store](api.html#store-type) handle. It removes the id from in-memory queries and persistence immediately, then queues an outbox operation containing only the id.

The optimistic removal continues to overlay incoming query answers until
confirmed. A conflict is offered to `merge`: an accepted merge updates the
saved base and keeps the remove pending, while a declined or missing merge
keeps remote truth and records the removed value as the rejection's `base`.
A definitive rejection restores and records the base when one is known; an
unknown-id remove has no value from which to make a rejection. Writing the
same id clears its current rejection.

```typescript
// The card leaves every open deck at once, and the outbox carries only its
// id. If the server refuses, the card comes back, with a rejection that holds
// the removed value as `base`.
const drop = (card: Card) => store.remove(card.id);
```

```rescript
// The card leaves every open deck at once, and the outbox carries only its
// id. If the server refuses, the card comes back, with a rejection that holds
// the removed value as `base`.
let drop = card => store.remove(card.id)
```
