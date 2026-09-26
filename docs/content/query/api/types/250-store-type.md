---
name: Store
slug: store-type
kind: type
module: core
since: "0.1"
sort: 250
summary: Application write and synchronization handle from the shipped store.
tags: []
signature.ts: |-
  type Store<T> = {
    upsert: (value: T) => void,
    remove: (id: string) => void,
    receive: Receive<T>,
    status: Status<T>,
    retry: (rejection: Rejection<T>) => void,
    discard: (rejection: Rejection<T>) => void
  }
signature.res: |-
  type Store.t<'a> = {
    upsert: 'a => unit,
    remove: string => unit,
    receive: receive<'a>,
    status: status<'a>,
    retry: rejection<'a> => unit,
    discard: rejection<'a> => unit,
  }
label: Store
---

`Store<T>` / `Store.t<'a>` is the second tuple item returned by [make](api.html#make) when configured with [Store.make](api.html#store-make) or [Store.custom](api.html#store-custom).

- [upsert](api.html#upsert) and [remove](api.html#remove) perform optimistic writes.
- [receive](api.html#receive-type) accepts changed values and removed ids from server pushes.
- [status](api.html#status) exposes reactive outbox and rejection state.
- [retry](api.html#retry) and [discard](api.html#discard) resolve exact rejection records.

The query engine itself is read-only; all application writes go through this handle.

```typescript
// A feature that edits takes the store handle; one that only displays takes
// the query object. The reviewer needs both verbs and nothing about reads.
const reviewer = (store: Store<Card>) => ({
  pass: (card: Card) => store.upsert({ ...card, seen: card.seen + 1 }),
  drop: (card: Card) => store.remove(card.id),
});
```

```rescript
// A feature that edits takes the store handle; one that only displays takes
// the query object. The reviewer needs both verbs and nothing about reads.
let reviewer = (store: Store.t<card>) => {
  pass: card => store.upsert({...card, seen: card.seen + 1}),
  drop: card => store.remove(card.id),
}
```
