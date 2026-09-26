---
name: Schema
slug: schema-type
kind: type
module: core
since: "0.1"
sort: 350
summary: Share resolved collection behavior with a custom store.
tags: []
signature.ts: |-
  type Schema<T, Q> = {
    id: (value: T) => string,
    matches: (query: Q, value: T) => boolean,
    key: (query: Q) => string,
    sort: (query: Q) => (values: T[]) => T[],
    now: () => number
  }
signature.res: |-
  type schema<'query, 'a> = {
    id: 'a => string,
    matches: ('query, 'a) => bool,
    key: 'query => string,
    sort: 'query => array<'a> => array<'a>,
    now: unit => float,
  }
label: Schema
---

`Schema` is the root [Config](api.html#config-type) after defaults are resolved. [make](api.html#make) passes it once to a custom [StoreFactory](api.html#store-factory-type), so engine and store share the same id, membership, key, ordering, and clock behavior.

The store must not apply its own defaults for these fields.

```typescript
// A custom store answers finds with the engine's own rules — `matches`,
// `sort`, `id`, `key`, `now`, defaults resolved — and never re-derives them.
// Here a find over rows the store holds: filter by the engine's membership,
// order by the engine's sort, and the two halves cannot disagree.
const findIn = (schema: Schema<Card, DeckQuery>, rows: Card[]) =>
  (query: DeckQuery, channel: LocalChannel<Card>) =>
    channel.local(schema.sort(query)(rows.filter((card) => schema.matches(query, card))));
```

```rescript
// A custom store answers finds with the engine's own rules — `matches`,
// `sort`, `id`, `key`, `now`, defaults resolved — and never re-derives them.
// Here a find over rows the store holds: filter by the engine's membership,
// order by the engine's sort, and the two halves cannot disagree.
let findIn = (schema: schema<deckQuery, card>, rows) => (query, channel: Channel.local<card>) =>
  channel.local(schema.sort(query)(rows->Array.filter(card => schema.matches(query, card))))
```
