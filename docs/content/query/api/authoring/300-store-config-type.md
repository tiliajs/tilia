---
name: StoreConfig
slug: store-config-type
kind: type
module: core
since: "0.1"
sort: 300
summary: Configure Store.make with backend operations and storage.
tags: []
signature.ts: |-
  type StoreConfig<T, Q> = {
    find: (query: Q, answer: Answer<T>) => void,
    upsert: (value: T, reply: (outcome: Outcome<T>) => void) => void,
    remove: (id: string, reply: (outcome: Removal) => void) => void,
    online?: Signal<boolean>,
    persist?: Kv,
    lookup?: (query: Q, channel: LocalChannel<T>) => void,
    merge?: (change: Change<T>, remote: T) => boolean,
    expiry?: StoreExpiry
  }
signature.res: |-
  type Store.config<'query, 'a> = {
    find: ('query, Store.answer<'a>) => unit,
    upsert: ('a, Store.Outcome.t<'a> => unit) => unit,
    remove: (string, Store.Removal.t => unit) => unit,
    online?: Tilia.signal<bool>,
    persist?: Store.Kv.t,
    lookup?: ('query, Channel.local<'a>) => unit,
    merge?: (~change: change<'a>, ~remote: 'a) => bool,
    expiry?: Store.expiry,
  }
label: StoreConfig
---

`StoreConfig` describes the high-level backend consumed by [Store.make](api.html#store-make).

- `find` answers with [Answer](api.html#answer-type).
- `upsert` replies once with an [Outcome](api.html#outcome-type).
- `remove` replies once with a [Removal](api.html#removal-type).
- `online` defaults to [Store.online](api.html#store-online).
- `persist` defaults to an in-memory [Kv](api.html#kv-type).
- `lookup` may answer an unregistered query as `partial` or, when it can certify completeness, `local`. Without it, the store scans its rows and can only answer `partial`.
- `merge` reconciles a [Change](api.html#change-type) with remote truth in place.
- `expiry` controls how long unheld query records remain in local retention.

```typescript
// The three required functions, then what the shipped store can do with more:
// durable rows, an index to answer decks it has no record of, a merge that
// keeps both sides' edits, and a shorter memory than the default month.
const config: StoreConfig<Card, DeckQuery> = {
  find,
  upsert,
  remove,
  persist: indexeddb({ name: "flashcards" }),
  lookup,
  merge,
  expiry: { local: 7 * 24 * 60 * 60_000 },
};
```

```rescript
// The three required functions, then what the shipped store can do with more:
// durable rows, an index to answer decks it has no record of, a merge that
// keeps both sides' edits, and a shorter memory than the default month.
let config: Store.config<deckQuery, card> = {
  find,
  upsert,
  remove,
  persist: TiliaQueryIndexedDb.make({name: "flashcards"}),
  lookup,
  merge,
  expiry: {local: 604_800_000.},
}
```
