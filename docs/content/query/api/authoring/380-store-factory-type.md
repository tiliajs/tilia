---
name: StoreFactory
slug: store-factory-type
kind: type
module: core
since: "0.1"
sort: 380
summary: Connect a store to an initialized query engine.
tags: []
signature.ts: |-
  type StoreFactory<T, Q, S> =
    (schema: Schema<T, Q>, binding: Binding<T>) => [Source<T, Q>, S]
signature.res: |-
  type store<'query, 'a, 'store> =
    (schema<'query, 'a>, binding<'a>) => (source<'query, 'a>, 'store)
label: StoreFactory
---

`StoreFactory` is the `store` value accepted by [Config](api.html#config-type). [make](api.html#make) calls it once with the resolved [Schema](api.html#schema-type) and an already working [Binding](api.html#binding-type). It returns the store's [Source](api.html#source-type) and any application handle `S`.

The factory shape ensures neither engine nor store exists unconnected. A custom store may use the binding during construction. Use `void` / `unit` for `S` when it exposes no application handle.

```typescript
// The factory shape: given the schema and a binding that already works, hand
// the source back in the same breath. Rows placed here are readable before
// `make` returns, and a store with nothing to offer the app returns `undefined`.
const seeded = (rows: Card[]): StoreFactory<Card, DeckQuery, void> => (schema, binding) => {
  rows.forEach(binding.place);
  return [source(schema, binding), undefined];
};

const [cards] = make({
  id: (card: Card) => card.id,
  matches: (query: DeckQuery, card: Card) => card.deck === query.deck,
  store: seeded(fixtures),
});
```

```rescript
// The factory shape: given the schema and a binding that already works, hand
// the source back in the same breath. Rows placed here are readable before
// `make` returns, and a store with nothing to offer the app returns `()`.
let seeded = (rows): store<deckQuery, card, unit> => (schema, binding) => {
  rows->Array.forEach(binding.place)
  (source(schema, binding), ())
}

let (cards, ()) = make({
  id: card => card.id,
  matches: (query, card) => card.deck === query.deck,
  store: seeded(fixtures),
})
```
