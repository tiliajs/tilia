---
name: .removed
slug: removed
kind: function
module: core
since: "0.1"
sort: 85
summary: Apply inbound deletes — evict everywhere, purge the clean local rows.
signature:
  ts: "collection.removed(items: T[]): void"
  res: "collection.removed: array<'a> => unit"
tags: []
---

`removed` is the delete twin of [changed](api.html#changed), for deletions that arrive from outside. It takes an array and applies the batch as a single reactive transaction: each id is evicted from the object cache and every query id list, its clean row is purged from the local store, and the id is dropped from persisted query records. Without the purge, a delete pushed over a socket would vanish from the screen but linger on disk — and reappear as a ghost on the next offline start.

No remote call, and no tombstone: the server already knows. An id with a pending optimistic write is skipped — the local write wins until it settles. Dirty rows and tombstones are never touched. See guide chapter [When the server disagrees](docs.html#when-the-server-disagrees).

```typescript
socket.on("cardDeleted", (card: Card) => cards.removed([card]));
```

```rescript
Socket.on(socket, "cardDeleted", card => cards.removed([card]))
```
