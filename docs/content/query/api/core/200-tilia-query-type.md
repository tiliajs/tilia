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
const read = (query: TiliaQuery<Card, Query>) => query.array({ deck: "es" });
```

```rescript
let read = (query: TiliaQuery.t<query, card>) => query.array({deck: "es"})
```
