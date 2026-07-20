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

`receive.removed` is part of [Receive](api.html#receive-type). It reports ids that were deleted on the server. It takes ids, never full values.

For each delivered id:

- The id leaves every in-memory query result, and its local row is deleted.
- A pending create or update is cleared and becomes a conflict in `status.rejected`; the server deletion remains visible.
- A pending remove is confirmed and cleared without a rejection.

Like [receive.changed](api.html#receive-changed), deliveries do not touch freshness: the `fresh` flag and refresh scheduling stay owned by the per-query read channel.

See guide chapters [Two devices, one deck](guide.html#two-devices-one-deck) and [When the world returns](guide.html#when-the-world-returns). `cards` is the collection from [make](api.html#make).

```typescript
socket.on("cards-removed", (ids: string[]) => {
  cards.receive.removed(ids);
});
```

```rescript
socket.on("cards-removed", ids => cards.receive.removed(ids))
```
