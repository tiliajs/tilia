---
name: Remote
slug: remote-type
kind: type
module: core
since: "0.1"
sort: 240
summary: Connect Store.custom to an authoritative remote backend.
tags: []
signature.ts: |-
  type Remote<T, Q> = {
    online: Signal<boolean>,
    fetch: (query: Q, channel: ReadChannel<T>) => void,
    push: (ops: Op<T>[], channel: WriteChannel<T>) => void
  }
signature.res: |-
  type remote<'query, 'a> = {
    online: Tilia.signal<bool>,
    fetch: ('query, Channel.read<'a>) => unit,
    push: (array<op<'a>>, Channel.write<'a>) => unit,
  }
label: Remote
---

`Remote` is the advanced channel adapter consumed by [Store.custom](api.html#store-custom).

- `online` is an application-owned reactive connectivity signal. Pending operations push only while it is true.
- `fetch` answers one query through a [ReadChannel](api.html#read-channel-type), using `fresh` for a complete current answer or `live` when the source maintains it.
- `push` receives an ordered batch of pending [Op](api.html#op-type) values and answers through a [WriteChannel](api.html#write-channel-type).

```typescript
// A remote for `Store.custom`: the app's connectivity signal, one fetch per
// query, one push per batch. `push` answers each operation through the write
// channel — see WriteChannel for it in full.
const remote: Remote<Card, DeckQuery> = {
  online: network.online,
  fetch: (query, channel) =>
    api.get(`/decks/${query.deck}`).then(channel.fresh, (error: ApiError) => channel.fail(error.message)),
  push,
};
```

```rescript
// A remote for `Store.custom`: the app's connectivity signal, one fetch per
// query, one push per batch. `push` answers each operation through the write
// channel — see Channel.write for it in full.
let remote: remote<deckQuery, card> = {
  online: network.online,
  fetch: (query, channel) =>
    Api.get(`/decks/${query.deck}`)
    ->Promise.thenResolve(result =>
      switch result {
      | Ok(cards) => channel.fresh(cards)
      | Error(message) => channel.fail(message)
      }
    )
    ->ignore,
  push,
}
```
