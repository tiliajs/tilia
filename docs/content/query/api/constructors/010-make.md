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

type Card = { id: string; deck: string; front: string; back: string; seen: number };
type DeckQuery = { deck: string };

const [cards, store] = make({
  id: (card: Card) => card.id,
  matches: (query: DeckQuery, card: Card) => card.deck === query.deck,
  store: Store.make<Card, DeckQuery>({ find, upsert, remove }),
});

// Two handles, two verbs. A view reads through `cards`; a review writes
// through `store`, and every open deck that lists the card follows.
const spanish = cards.array({ deck: "spanish" });
store.upsert({ id: "cat.es", deck: "spanish", front: "cat", back: "gato", seen: 1 });
```

```rescript
open TiliaQuery

type card = {id: string, deck: string, front: string, mutable back: string, mutable seen: int}
type deckQuery = {deck: string}

let (cards, store) = make({
  id: card => card.id,
  matches: (query, card) => card.deck === query.deck,
  store: Store.make({find, upsert, remove}),
})

// Two handles, two verbs. A view reads through `cards`; a review writes
// through `store`, and every open deck that lists the card follows.
let spanish = cards.array({deck: "spanish"})
store.upsert({id: "cat.es", deck: "spanish", front: "cat", back: "gato", seen: 1})
```
