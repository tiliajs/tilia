---
name: remove
slug: remove
kind: function
module: core
since: "0.1"
sort: 50
summary: Remove a value by id, optimistically.
signature:
  ts: "remove: (id: string) => void"
  res: "remove: string => unit"
tags: []
---

`remove` deletes a value by id, before the remote confirms. A remove never requires a full value — the op carries only the id.

What happens immediately:

- The id leaves every in-memory query result and the persisted query records.
- The local row is deleted.
- The op queues in the outbox and counts in [status](api.html#status)`.pending`, like any write.

Edge cases:

- The remote's confirmation ([WriteChannel](api.html#write-channel-type)`.removed`) only clears the op — the local deletion is already complete.
- A pending remove keeps overlaying remote deliveries: the id is filtered out of every result until the op confirms.
- A stale id left in a query record from an earlier session is harmless: the purge sweep only examines rows that still exist locally, and the next refresh rewrites the record without the id.

`cards` below is the collection from [make](api.html#make). See guide chapter [Writing without waiting](docs.html#writing-without-waiting).

```typescript
cards.remove("cat");
```

```rescript
cards.remove("cat")
```
