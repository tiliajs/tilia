---
name: make
slug: make
kind: function
module: core
since: "0.1"
sort: 10
summary: Build a query engine and its application-facing store handle.
tags: []
signature.ts: "function make<T, Q, S>(config: Config<T, Q, S>): [TiliaQuery<T, Q>, S]"
signature.res: "let make: config<'query, 'a, 'store> => (t<'query, 'a>, 'store)"
label: make(config)
---

`make` resolves the engine [Config](api.html#config-type), creates its [StoreFactory](api.html#store-factory-type), and returns a tuple:

- The read-only [TiliaQuery](api.html#tilia-query-type) engine handle.
- Whatever application handle the store factory returns. [Store.make](api.html#store-make) and [Store.custom](api.html#store-custom) return a writable [Store](api.html#store-type).

Values and queries must not be `null` or `undefined`. Queries, and values used
with the shipped store, must survive a JSON round trip unchanged: query
records, persisted rows, and rejection snapshots all rely on it, even when
the keyspace is only in memory. The backend must preserve client-supplied ids.

```typescript
import { make, Store } from "@tilia/query";

const [cards, store] = make<Card, Query, Store<Card>>({
  id: (card) => card.id,
  matches: (query, card) => query.deck === card.deck,
  store: Store.make({ find, upsert, remove }),
});
```

```rescript
open TiliaQuery

let (cards, store) = make({
  id: card => card.id,
  matches: (query, card) => query.deck === card.deck,
  store: Store.make({find, upsert, remove}),
})
```
