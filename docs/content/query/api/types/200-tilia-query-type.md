---
name: TiliaQuery
slug: tilia-query-type
kind: type
module: core
since: "0.1"
sort: 200
summary: Read-only query and lifecycle handle returned by make.
tags: []
signature.ts: |-
  type TiliaQuery<T, Q> = {
    one: (query: Q) => Loadable<T>,
    array: (query: Q) => Loadable<T[]>,
    tick: () => void,
    dispose: () => void,
    _canopy: () => Canopy
  }
signature.res: |-
  type t<'query, 'a> = {
    one: 'query => loadable<'a>,
    array: 'query => loadable<array<'a>>,
    tick: unit => unit,
    dispose: unit => unit,
    _canopy: unit => canopy,
  }
label: TiliaQuery
---

`TiliaQuery<T, Q>` / `t<'query, 'a>` is the first item returned by [make](api.html#make). Its application surface is read-only:

- [one](api.html#one) and [array](api.html#array) perform reactive reads.
- [tick](api.html#tick) advances engine and store time.
- [dispose](api.html#dispose) shuts both halves down.
- [_canopy](api.html#canopy) exposes debug state.

Writes, inbound server facts, and synchronization status are on the separate [Store](api.html#store-type) handle returned by the shipped store factories.

```typescript
// A feature that only displays takes the query object, and nothing else: it
// can ask, it cannot write. The store handle stays with the feature that edits.
const dueCount = (cards: TiliaQuery<Card, DeckQuery>, deck: string) => {
  const result = cards.array({ deck });
  return result !== "loading" && result.state === "loaded" ? result.data.filter(due).length : 0;
};
```

```rescript
// A feature that only displays takes the query object, and nothing else: it
// can ask, it cannot write. The store handle stays with the feature that edits.
let dueCount = (cards: t<deckQuery, card>, deck) =>
  switch cards.array({deck: deck}) {
  | Loaded({data}) => data->Array.filter(due)->Array.length
  | Loading | NoData(_) => 0
  }
```
