---
name: discard
slug: discard
kind: function
module: core
since: "0.1"
sort: 100
summary: Drop a rejected op and revert to remote truth.
signature:
  ts: "discard: (rejection: Rejection<T>) => void"
  res: "discard: rejection<'a> => unit"
tags: []
---

`discard` drops a rejected op for good, matched by its `id`. The entry leaves [status](api.html#status)`.rejected` and its persisted outbox entry is deleted — a restart can no longer replay and re-fail the op.

The optimistic write replaced both the in-memory value and the local row, so the client cannot rebuild remote truth on its own. Discard therefore refetches:

- A discarded upsert refetches every in-memory query that lists the row. The remote result restores the value — and a rejected *new* row disappears, since the remote result does not contain it.
- A discarded remove refetches every observed query instead (no result lists the row anymore). The row returns with those results.
- A live query is refetched too: its subscription is torn down (the registered `finally` runs) and a new fetch re-subscribes.
- While offline the refetch cannot answer; the optimistic value stays visible until the next online refresh.

An id with no rejected entry raises.

See [retry](api.html#retry) and guide chapter [When the server disagrees](guide.html#when-the-server-disagrees). `cards` is the collection from [make](api.html#make).

```typescript
const [rejection] = cards.status.rejected;
if (rejection) cards.discard(rejection);
```

```rescript
switch cards.status.rejected[0] {
| Some(rejection) => cards.discard(rejection)
| None => ()
}
```
