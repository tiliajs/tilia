---
name: .upsert
slug: upsert
kind: function
module: core
since: "0.1"
sort: 60
summary: Optimistic write — durable locally, pushed to the remote when online.
signature:
  ts: "collection.upsert(value: T): void"
  res: "collection.upsert: 'a => unit"
tags: []
---

`upsert` records a write and returns immediately. In order: the row is saved dirty to the local store, the object cache is updated, and every query's id list is adjusted in place using `matches` and `sort` — no refetch. If online, the write dispatches to `remote.upsert`; otherwise it waits in the outbox.

The outbox keeps the latest write per id: a newer `upsert` to the same id cancels the in-flight channel of the older one. Until it settles, the dirty row is untouchable — fetches, inbound [changed](api.html#changed), reconciliation and retention pruning all defer to it. Replay happens on reconnect and, via `local.dirty()`, after a restart. Outcomes are settled through [WriteChannel](api.html#write-channel-type); refusals surface on [status](api.html#status). See guide chapter [Writing without waiting](docs.html#writing-without-waiting).

```typescript
cards.upsert({ ...gato, dueDate: "2026-07-14" });
// lists are already correct; sync happens in the background
```

```rescript
cards.upsert({...gato, dueDate: "2026-07-14"})
// lists are already correct; sync happens in the background
```
