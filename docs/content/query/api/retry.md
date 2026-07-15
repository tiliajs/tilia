---
name: retry
slug: retry
kind: function
module: core
since: "0.1"
sort: 90
summary: Re-queue a rejected op for another push.
signature:
  ts: "retry: (rejection: Rejection<T>) => void"
  res: "retry: rejection<'a> => unit"
tags: []
---

`retry` re-queues a rejected op, matched by its `id`. The entry leaves [status](api.html#status)`.rejected` and the op returns to the outbox.

- The op keeps its original sequence number, so edit order is preserved: an edit made after the rejection still pushes later and wins.
- Nothing is written to disk — the op's persisted outbox entry never left the local store.
- When online, the push happens immediately, like a fresh write.
- An id with no rejected entry raises.

See [discard](api.html#discard) for the other way out, and guide chapter [When the server disagrees](guide.html#when-the-server-disagrees). `cards` is the collection from [make](api.html#make).

```typescript
const [rejection] = cards.status.rejected;
if (rejection) cards.retry(rejection);
```

```rescript
switch cards.status.rejected[0] {
| Some(rejection) => cards.retry(rejection)
| None => ()
}
```
