---
name: make
slug: make
kind: function
module: core
since: "0.1"
sort: 10
summary: Build the query state for one collection from its configuration.
signature:
  ts: "function make<T, Q>(config: Config<T, Q>): Collection<T, Q>"
  res: "let make: config<'a, 'query> => t<'a, 'query>"
tags: []
---

`make` creates a collection: an object cache by id, a query cache of id lists, and the read/write lifecycle connecting them to the adapters in [Config](api.html#config-type). In TypeScript the returned type is `Collection<T, Q>`; in ReScript it is the module type `TiliaQuery.t`.

The returned collection carries the whole public surface — views ([one](api.html#one), [array](api.html#array), [dict](api.html#dict), [get](api.html#get)), writes ([upsert](api.html#upsert), [remove](api.html#remove)), inbound events ([changed](api.html#changed), [removed](api.html#removed)), scheduling ([tick](api.html#tick)) and lifecycle ([status](api.html#status), [clear](api.html#clear), [dispose](api.html#dispose)).

At creation, `local.dirty()` is replayed through the normal write flow, so unsynced writes from the previous session dispatch on the next reconnect — and `local.queries()` loads the persisted query registry, so retention survives restarts and a query re-opened offline serves its full persisted row set. See guide chapter [A shape for queries](docs.html#a-shape-for-queries).

`make` throws `make: remote is not a tilia proxy (reconnect could never replay writes)` if [remote](api.html#remote-type) is not a tilia object — the core watches `remote.online` to drive reconnect replay, and a plain record has nothing to watch.

```typescript
import { make } from "@tilia/query";

const cards = make<Card, DeckQuery>({
  id: (card) => card.id,
  remote,
  local,
  matches: (q, card) => card.deck === q.deck,
  sort: (a, b) => (a.dueDate < b.dueDate ? -1 : 1),
});
```

```rescript
let cards = TiliaQuery.make({
  id: card => card.id,
  remote,
  local,
  matches: (q, card) => card.deck == q.deck,
  sort: (a, b) => a.dueDate < b.dueDate ? -1.0 : 1.0,
})
```
