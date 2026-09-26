---
name: Store.memory
slug: store-memory
kind: function
module: core
since: "0.1"
sort: 170
summary: Create a process-local string keyspace.
tags: []
signature.ts: "Store.memory(): Kv"
signature.res: "Store.memory: unit => Store.Kv.t"
label: Store.memory()
---

`Store.memory` creates the in-memory [Kv](api.html#kv-type) used when `persist` is omitted. It follows the same storage path as a durable keyspace but forgets all entries with the process.

```typescript
// A test builds the app on a keyspace that forgets with the process. Rows,
// query records and the outbox go down the same path as with IndexedDB, so
// what the test proves about persistence holds in production.
const [cards, store] = make({
  id: (card: Card) => card.id,
  matches: (query: DeckQuery, card: Card) => card.deck === query.deck,
  store: Store.make<Card, DeckQuery>({ find, upsert, remove, persist: Store.memory() }),
});
```

```rescript
// A test builds the app on a keyspace that forgets with the process. Rows,
// query records and the outbox go down the same path as with IndexedDB, so
// what the test proves about persistence holds in production.
let (cards, store) = make({
  id: card => card.id,
  matches: (query, card) => card.deck === query.deck,
  store: Store.make({find, upsert, remove, persist: Store.memory()}),
})
```
