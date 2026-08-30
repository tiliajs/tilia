---
name: Config
slug: config-type
kind: type
module: core
since: "0.1"
sort: 205
summary: Configure the query engine and its store factory.
tags: []
signature.ts: |-
  type Config<T, Q, S> = {
    id: (value: T) => string,
    matches: (query: Q, value: T) => boolean,
    store: StoreFactory<T, Q, S>,
    expiry?: Expiry,
    now?: () => number,
    key?: (query: Q) => string,
    sort?: (query: Q) => (values: T[]) => T[],
    onError?: (query: Q, message: string) => void
  }
signature.res: |-
  type config<'query, 'a, 'store> = {
    id: 'a => string,
    matches: ('query, 'a) => bool,
    store: store<'query, 'a, 'store>,
    expiry?: expiry,
    now?: unit => float,
    key?: 'query => string,
    sort?: 'query => array<'a> => array<'a>,
    onError?: (~query: 'query, ~message: string) => unit,
  }
label: Config
---

`Config` contains engine concerns; store concerns belong to the supplied [StoreFactory](api.html#store-factory-type).

- `id` returns the stable unique id for a value.
- `matches` is a pure per-row query membership predicate. A find must return
  the complete result set; limits, pagination, and aggregates do not fit this
  query shape.
- `store` creates the source and application store handle.
- `expiry` sets engine refresh and memory timing.
- `now` returns milliseconds; the default is the current system time.
- `key` identifies a query; the default is [sortedStringify](api.html#sorted-stringify).
- `sort` returns a sorter for the full result array; the default preserves
  delivery order.
- `onError` receives a find failure that cannot be shown at the read site
  because an existing answer is retained. That includes a complete empty
  answer. A first failure with no answer becomes `NoData({Failed})`; refresh
  failures that preserve an answer call `onError`. `Loaded` has no error
  field.

```typescript
const config: Config<Card, Query, Store<Card>> = {
  id: (card) => card.id,
  matches: (query, card) => query.deck === card.deck,
  store: Store.make({ find, upsert, remove }),
  onError: (_query, message) => console.error(message),
};
```

```rescript
let config: TiliaQuery.config<query, card, TiliaQuery.Store.t<card>> = {
  id: card => card.id,
  matches: (query, card) => query.deck === card.deck,
  store: Store.make({find, upsert, remove}),
  onError: (~query=_, ~message) => Console.error(message),
}
```
