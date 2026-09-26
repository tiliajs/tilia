---
name: Channel.find
slug: find-channel-type
kind: type
module: core
since: "0.1"
sort: 275
summary: Combine local and authoritative answers for one engine find.
tags: []
signature.ts: "ReadChannel<T> & LocalChannel<T>"
signature.res: |-
  type Channel.find<'a> = {
    partial: array<'a> => unit,
    local: array<'a> => unit,
    fresh: array<'a> => unit,
    live: array<'a> => unit,
    fail: string => unit,
    end: unit => unit,
    finally: (unit => unit) => unit,
  }
label: Channel.find
---

`Channel.find` is the combined channel passed to a custom
[Source](api.html#source-type). TypeScript expresses it as the intersection
`ReadChannel<T> & LocalChannel<T>`; ReScript exports the named
`Channel.find<'a>` type.

It lets one engine find receive `partial` or `local` answers from storage and
`fresh` or `live` answers from an authoritative source. `fail`, `end`, and
`finally` use the [ReadChannel](api.html#read-channel-type) lifecycle. The
engine ignores an answer that would weaken the strongest claim already
published during that find.

```typescript
// A custom source answers one find twice: storage first, so the deck shows at
// once, then the network. The engine keeps the stronger claim — a `local`
// that lands after `fresh` cannot pull the result back down.
const find = (query: DeckQuery, channel: ReadChannel<Card> & LocalChannel<Card>) => {
  storage.rows(query).then(channel.local);
  if (online.value) server.fetch(query).then(channel.fresh, (error: Error) => channel.fail(error.message));
};
```

```rescript
// A custom source answers one find twice: storage first, so the deck shows at
// once, then the network. The engine keeps the stronger claim — a `local`
// that lands after `fresh` cannot pull the result back down.
let find = (query, channel: Channel.find<card>) => {
  storage.rows(query)->Promise.thenResolve(channel.local)->ignore
  if online.value {
    server.fetch(query)
    ->Promise.thenResolve(result =>
      switch result {
      | Ok(cards) => channel.fresh(cards)
      | Error(message) => channel.fail(message)
      }
    )
    ->ignore
  }
}
```
