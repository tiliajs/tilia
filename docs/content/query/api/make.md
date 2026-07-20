---
name: make
slug: make
kind: function
module: core
since: "0.1"
sort: 10
summary: Create the query state for one collection.
signature:
  ts: |-
    function make<T, Q>(config: Config<T, Q>): TiliaQuery<T, Q>
  res: |-
    let make: config<'query, 'a> => t<'query, 'a>
tags: []
---

`make` builds a [TiliaQuery](api.html#tilia-query-type) from its [Config](api.html#config-type): the query state for one collection, coordinating memory, an optional local store and the authoritative remote.

- `id` — extract a value's unique id.
- `matches` — membership: does this value belong to this query? It must be a pure predicate over one value. Limits, pagination and aggregates do not fit this shape.
- `remote` — the authoritative adaptor. See [Remote](api.html#remote-type).
- `local` — optional durable cache. See [Local](api.html#local-type). Without it there is no offline persistence and no durable outbox.
- `expiry` — timing configuration. See [Expiry](api.html#expiry-type). Defaults: 30 s refresh, 5 min memory, 30 days local.
- `now` — clock in milliseconds. Default: `Date.now`. Inject a fake clock in tests.
- `key` — query identity as a string. Default: [sortedStringify](api.html#sorted-stringify).
- `sort` — return the result sorter for a query. [one](api.html#one) returns the first value per this order. Default: delivery order.
- `merge` — merge a remote value into its local value in place using the local [Change](api.html#change-type). Return `false` to keep remote truth and record a conflict.

Queries should be plain data that survives a JSON round trip. The default `key` needs it, and so does the local purge: persisted query records store the query itself, so `matches` can run against records whose query is no longer in memory.

The engine owns no timers. Call [tick](api.html#tick) on an interval to drive refresh, expiry, garbage collection and push retries.

See guide chapter [A shape for queries](guide.html#a-shape-for-queries).

```typescript
import { make } from "@tilia/query";
import { signal } from "tilia";

type Card = { id: string; deck: string; english: string; translation: string };
type Query = { deck: string };

const gato: Card = { id: "cat", deck: "es", english: "cat", translation: "gato" };
const [online] = signal(true);

const cards = make<Card, Query>({
  id: (card) => card.id,
  matches: (query, card) => card.deck === query.deck,
  remote: {
    online,
    fetch: (query, channel) =>
      channel.set([gato].filter((card) => card.deck === query.deck)),
    push: (ops, channel) =>
      ops.forEach((op) =>
        op.op === "upsert" ? channel.set(op.value) : channel.removed(op.id)
      ),
  },
});

const timer = setInterval(cards.tick, 10_000);
```

```rescript
open TiliaQuery

type card = {id: string, deck: string, english: string, translation: string}
type query = {deck: string}

let gato = {id: "cat", deck: "es", english: "cat", translation: "gato"}
let (online, _setOnline) = Tilia.signal(true)

let cards = make({
  id: card => card.id,
  matches: (query, card) => card.deck === query.deck,
  remote: {
    online,
    fetch: (query, channel) =>
      channel.set([gato]->Array.filter(card => card.deck === query.deck)),
    push: (ops, channel) =>
      ops->Array.forEach(op =>
        switch op {
        | Upsert({value}) => channel.set(value)
        | Remove({id}) => channel.removed(id)
        }
      ),
  },
})

let timer = setInterval(cards.tick, 10_000)
```
