---
name: receive.changed
slug: receive-changed
kind: function
module: core
since: "0.1"
sort: 60
summary: Report values changed on the server (inbound push).
signature:
  ts: "receive.changed: (values: T[]) => void"
  res: "changed: array<'a> => unit"
tags: []
---

`receive.changed` reports values that changed on the server — an inbound push, typically wired to a websocket or sync feed. Deliveries are facts about the server (past tense), not commands.

Each delivered value is matched against every in-memory query, like an optimistic upsert:

- It joins the results it `matches` and leaves the results it no longer matches.
- The outbox overlay wins: an id with a pending or rejected op is skipped entirely — the optimistic value stays until the op confirms or is discarded.

Retention and freshness:

- A delivered value is kept in memory only while some in-memory query matches it, and persisted only while some query record lists it. A value matching nothing is dropped.
- Deliveries do not touch freshness: the `fresh` flag and refresh scheduling stay owned by the per-query read channel (`set` / `live`).

See [receive.removed](api.html#receive-removed), [ReadChannel](api.html#read-channel-type), and guide chapter [The channel boundary](docs.html#the-channel-boundary). `cards` is the collection from [make](api.html#make).

```typescript
socket.on("cards-changed", (rows: Card[]) => {
  cards.receive.changed(rows);
});
```

```rescript
socket.on("cards-changed", rows => cards.receive.changed(rows))
```
