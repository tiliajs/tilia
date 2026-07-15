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

A local adaptor that can filter its cache with the collection's `matches` may prefer building partial results and calling `set` — a partial answer beats `NotLocal` for the user standing in a tunnel.

See guide chapter [Reads answer twice](guide.html#reads-answer-twice).

```typescript
// Answer from an id-keyed cache, or admit ignorance.
fetch: (query: Query, channel: LocalChannel<Card>) => {
  db.cards
    .where("deck")
    .equals(query.deck)
    .toArray()
    .then((rows) => (rows.length > 0 ? channel.set(rows) : channel.unknown()));
}
```

```rescript
// Answer from an id-keyed cache, or admit ignorance.
let fetch = (query: query, channel: TiliaQuery.Channel.local<card>) =>
  db.cards.filter(card => card.deck === query.deck)
  ->Promise.thenResolve(rows =>
    rows->Array.length > 0 ? channel.set(rows) : channel.unknown()
  )
  ->ignore
```
