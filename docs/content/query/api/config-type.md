---
name: Config
slug: config-type
kind: type
module: core
since: "0.1"
sort: 210
summary: Configuration for make — identity, adapters, and domain logic.
signature:
  ts: |-
    interface Config<T, Q> {
      id(value: T): string,
      remote: Remote<T, Q>,
      local?: Store<T, Q>,
      stale?: number,
      gc?: number,
      now?: () => number,
      key?: (query: Q) => string,
      matches?: (query: Q, value: T) => boolean,
      sort?: (a: T, b: T) => number
    }
  res: |-
    type config<'a, 'query> = {
      id: 'a => string,
      remote: remote<'a, 'query>,
      local?: store<'a, 'query>,
      stale?: float,
      gc?: float,
      now?: unit => float,
      key?: 'query => string,
      matches?: ('query, 'a) => bool,
      sort?: ('a, 'a) => float,
    }
tags: []
---

The configuration passed to [make](api.html#make). Required: `id`, the object's identity, and [remote](api.html#remote-type), the authoritative adapter.

`local` is the durable [Store](api.html#store-type) — without it, reads have no offline answer, writes no outbox persistence, and query results no persisted registry. `stale` (default 30) and `gc` (default 300) are the seconds before a watched query refreshes and an unwatched one is evicted on [tick](api.html#tick); `now` is the clock in seconds (default `Date.now() / 1000`), injectable for tests.

`key` serializes a filter into the query cache key (default: sorted JSON stringification). `matches` decides membership, letting writes update query id lists in place without any fetch; `sort` keeps those lists ordered and stable across refetches. See guide chapter [A shape for queries](docs.html#a-shape-for-queries).

```typescript
const config: Config<Card, DeckQuery> = {
  id: (card) => card.id,
  remote,
  local,
  stale: 60,
  matches: (q, card) => card.deck === q.deck,
};
```

```rescript
let config: TiliaQuery.config<card, deckQuery> = {
  id: card => card.id,
  remote,
  local,
  stale: 60.0,
  matches: (q, card) => card.deck == q.deck,
}
```
