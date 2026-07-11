---
name: .remove
slug: remove
kind: function
module: core
since: "0.1"
sort: 70
summary: Optimistic delete — tombstoned locally, pushed to the remote when online.
signature:
  ts: "collection.remove(value: T): void"
  res: "collection.remove: 'a => unit"
tags: []
---

`remove` deletes optimistically: the local store writes a dirty tombstone, the object leaves the cache and every query id list, and `remote.remove` is dispatched when online.

While the delete is pending, fetches cannot resurrect the id, and inbound updates for it are ignored. If the remote answers `conflict(server)` or `rejected(message)`, the row is restored from server truth — the server said it still exists. Tombstones survive restarts, replay like any queued write, and are never touched by reconciliation or retention pruning. See guide chapter [Writing without waiting](docs.html#writing-without-waiting).

```typescript
cards.remove(gato);
// gone from every list; the tombstone syncs when online
```

```rescript
cards.remove(gato)
// gone from every list; the tombstone syncs when online
```
