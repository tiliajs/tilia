---
name: upsert
slug: upsert
kind: function
module: core
since: "0.1"
sort: 40
summary: Optimistically write a value through the store handle.
tags: []
signature.ts: "upsert: (value: T) => void"
signature.res: "upsert: 'a => unit"
label: store.upsert(value)
---

`upsert` belongs to the [Store](api.html#store-type) handle returned beside the query engine. It places the value immediately, updates every in-memory query whose `matches` result changed, persists the new optimistic state, and queues an ordered outbox operation.

Writing an id clears its current rejection. A saved confirmation replaces the
value with authoritative server data. A conflict is offered to `merge`: an
accepted merge rebases the write and keeps it pending, while a declined or
missing merge keeps remote truth and records a conflict
[Rejection](api.html#rejection-type). A definitive rejection reverts the
optimistic change and records its message.

```typescript
// Alice passes a card in a tunnel. The deck view moves on now — the row is
// placed and every open query that lists it follows — while the write waits
// in the outbox and goes when the train comes out.
const pass = (card: Card) => store.upsert({ ...card, seen: card.seen + 1 });

// A new card is the same call. The id is the client's, and the backend keeps it.
const add = (deck: string, front: string, back: string) =>
  store.upsert({ id: crypto.randomUUID(), deck, front, back, seen: 0 });
```

```rescript
// Alice passes a card in a tunnel. The deck view moves on now — the row is
// placed and every open query that lists it follows — while the write waits
// in the outbox and goes when the train comes out.
let pass = card => store.upsert({...card, seen: card.seen + 1})

// A new card is the same call. The id is the client's, and the backend keeps it.
let add = (~deck, ~front, ~back) => store.upsert({id: newId(), deck, front, back, seen: 0})
```
