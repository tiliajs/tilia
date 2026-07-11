---
name: .changed
slug: changed
kind: function
module: core
since: "0.1"
sort: 80
summary: Apply inbound updates — cache, query membership, and a clean local save.
signature:
  ts: "collection.changed(items: T[]): void"
  res: "collection.changed: array<'a> => unit"
tags: []
---

`changed` is for changes that arrive from outside: a WebSocket push, a delta-sync batch. It takes an array and applies the batch as a single reactive transaction: each item updates the object cache, adjusts query membership via `matches`, and is saved clean to the local store — so a pushed change survives an offline restart. No remote call: the change came from the remote. An id with a pending optimistic write is skipped — the local write wins until it settles. An engine that already wrote its own database can still call `changed`; the extra clean save is idempotent.

Do not use [upsert](api.html#upsert) for inbound data: it would echo the change back to the server and dirty the local store on the way. The naming carries the direction: outbound commands are imperative and take one item (`upsert`, `remove`); inbound events are past tense and take an array. `changed` is the inbound counterpart of the `covered()` callback on [FetchChannel](api.html#fetch-channel-type); [removed](api.html#removed) is its delete twin. See guide chapter [When the server disagrees](docs.html#when-the-server-disagrees).

```typescript
socket.on("card", (card: Card) => cards.changed([card]));
socket.on("cards", (batch: Card[]) => cards.changed(batch));
```

```rescript
Socket.on(socket, "card", card => cards.changed([card]))
Socket.on(socket, "cards", batch => cards.changed(batch))
```
