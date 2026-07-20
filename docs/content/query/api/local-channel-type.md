---
name: LocalChannel
slug: local-channel-type
kind: type
module: core
since: "0.1"
sort: 270
summary: Channel handed to local.fetch — set or unknown.
signature:
  ts: |-
    type LocalChannel<T> = {
      set: (values: T[]) => void,
      unknown: () => void
    }
  res: |-
    type local<'a> = {
      set: array<'a> => unit,
      unknown: unit => unit,
    }
tags: []
---

`LocalChannel` is handed to [Local.fetch](api.html#local-type). It has exactly two answers:

- `set` — here are the cached results.
- `unknown` — the local storage cannot answer this query.

What the engine does with `unknown` depends on connectivity:

- Online, the query stays `Loading` until the remote responds.
- Offline, it settles to `NotLocal` — an answer, not progress. See [Loadable](api.html#loadable-type).

Call `set([])` when the store knows the result is empty. Reserve `unknown` for a store that cannot distinguish an empty result from a query it has never cached.

See guide chapter [Reads answer twice](guide.html#reads-answer-twice).

```typescript
// This indexed table can answer the query, including with an empty result.
fetch: (query: Query, channel: LocalChannel<Card>) => {
  db.cards
    .where("deck")
    .equals(query.deck)
    .toArray()
    .then(channel.set);
}
```

```rescript
// This indexed table can answer the query, including with an empty result.
let fetch = (query: query, channel: TiliaQuery.Channel.local<card>) =>
  db.cards.filter(card => card.deck === query.deck)
  ->Promise.thenResolve(channel.set)
  ->ignore
```
