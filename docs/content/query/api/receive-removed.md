---
name: receive.removed
slug: receive-removed
kind: function
module: core
since: "0.1"
sort: 70
summary: Report ids deleted on the server (inbound push).
signature:
  ts: "receive.removed: (ids: string[]) => void"
  res: "removed: array<string> => unit"
tags: []
---

`receive.removed` reports ids that were deleted on the server. It takes ids, never full values.

For each delivered id:

- The id leaves every in-memory query result, and its local row is deleted.
- The outbox overlay wins: an id with a pending or rejected op is skipped entirely — memory and the local row keep the optimistic value until the op confirms or is discarded.

Like [receive.changed](api.html#receive-changed), deliveries do not touch freshness: the `fresh` flag and refresh scheduling stay owned by the per-query read channel.

See guide chapter [The channel boundary](guide.html#the-channel-boundary). `cards` is the collection from [make](api.html#make).

```typescript
socket.on("cards-removed", (ids: string[]) => {
  cards.receive.removed(ids);
});
```

```rescript
socket.on("cards-removed", ids => cards.receive.removed(ids))
```
