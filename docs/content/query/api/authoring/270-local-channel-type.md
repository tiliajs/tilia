---
name: LocalChannel
slug: local-channel-type
kind: type
module: core
since: "0.1"
sort: 270
summary: State what locally persisted rows can prove.
tags: []
signature.ts: |-
  type LocalChannel<T> = {
    partial: (values: T[]) => void,
    local: (values: T[]) => void
  }
signature.res: |-
  type Channel.local<'a> = {
    partial: array<'a> => unit,
    local: array<'a> => unit,
  }
label: LocalChannel
---

`LocalChannel` is used by `StoreConfig.lookup`, `StoreChannels.lookup`, and a custom [Source](api.html#source-type).

- `partial(values)` returns rows the store holds without claiming they are the complete result. `partial([])` explicitly says it holds nothing.
- `local(values)` returns the complete result according to local storage.

An empty partial answer remains loading while remote data is possible and becomes an offline absence otherwise. An empty local answer is complete data for `array` and `NoMatch` for `one`.

```typescript
// `lookup` is asked about a deck the store has no record of. A keyspace with
// a deck index can hand back its rows and certify they are all of them:
// `local`. A scan could only say `partial`, and an empty partial is not an
// answer — the engine keeps waiting for the network.
const lookup = (query: DeckQuery, channel: LocalChannel<Card>) =>
  deckIndex.rows(query.deck).then(channel.local);
```

```rescript
// `lookup` is asked about a deck the store has no record of. A keyspace with
// a deck index can hand back its rows and certify they are all of them:
// `local`. A scan could only say `partial`, and an empty partial is not an
// answer — the engine keeps waiting for the network.
let lookup = (query, channel: Channel.local<card>) =>
  DeckIndex.rows(query.deck)->Promise.thenResolve(channel.local)->ignore
```
