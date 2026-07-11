---
name: Remote
slug: remote-type
kind: type
module: core
since: "0.1"
sort: 220
summary: Authoritative adapter — connectivity plus fetch, upsert and remove.
signature:
  ts: |-
    interface Remote<T, Q> {
      readonly online: boolean,
      fetch(query: Q, channel: FetchChannel<T>): void | (() => void),
      upsert(value: T, channel: WriteChannel<T>): void,
      remove(value: T, channel: WriteChannel<T>): void
    }
  res: |-
    type remote<'a, 'query> = {
      online: bool,
      fetch: ('query, Channel.fetch<'a>) => option<unit => unit>,
      upsert: ('a, Channel.write<'a>) => unit,
      remove: ('a, Channel.write<'a>) => unit,
    }
tags: []
---

The remote adapter translates your transport into the lifecycle's vocabulary. `fetch` answers a query through a [FetchChannel](api.html#fetch-channel-type) and may return a cleanup for live subscriptions; `upsert` and `remove` settle writes through a [WriteChannel](api.html#write-channel-type). Remote rows are authoritative: they refresh query freshness and write through to the local store.

`remote` **must be a tilia object**: the core watches `online` reactively to replay the outbox and refresh live queries on reconnect. A plain record has nothing to watch, so [make](api.html#make) refuses it with `make: remote is not a tilia proxy (reconnect could never replay writes)`. See guide chapter [The channel boundary](docs.html#the-channel-boundary).

```typescript
import { tilia } from "tilia";

const remote: Remote<Card, DeckQuery> = tilia({
  online: navigator.onLine,
  fetch: (q, channel) =>
    void api.list(q).then(channel.set, (e) => channel.fail(e.message)),
  upsert: (card, channel) =>
    void api.save(card).then(channel.saved, () => channel.offline()),
  remove: (card, channel) =>
    void api.delete(card.id).then(() => channel.saved(card), () => channel.offline()),
});

window.addEventListener("online", () => (remote.online = true));
window.addEventListener("offline", () => (remote.online = false));
```

```rescript
open Tilia

let remote: TiliaQuery.remote<card, deckQuery> = tilia({
  online: Navigator.onLine,
  fetch: (q, channel) =>
    Api.list(q)->Promise.thenResolve(channel.set)->ignore->None,
  upsert: (card, channel) =>
    Api.save(card)->Promise.thenResolve(channel.saved)->ignore,
  remove: (card, channel) =>
    Api.delete(card.id)->Promise.thenResolve(() => channel.saved(card))->ignore,
})
```
