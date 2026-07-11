---
title: Writing without waiting
slug: writing-without-waiting
sort: 4
refs: [upsert, remove, store-type]
---

A write in @tilia/query never waits for the network. `upsert` and `remove` return immediately, and the library takes on the debt of making the write true everywhere else. This chapter is about how that debt is recorded, honored, and never lost.

### Durability first, optimism second

When Alice edits a card, `upsert` does three things, in a deliberate order:

1. **Persist** — the row is saved to the local store marked *dirty*, before anything else. If the app dies on the next line, the write already survives.
2. **Apply** — the object cache is updated, and every query's id list is adjusted *in place* using `matches`: the card enters lists whose filter now matches and leaves lists that no longer do, at the position `sort` dictates. No refetch — the changed object is known, so asking the server which lists it belongs to would be a round trip to compute what a predicate already knows.
3. **Dispatch** — if online, the write is sent to the remote. If not, it waits.

```typescript
cards.upsert({ ...gato, deck: "spanish", dueDate: "2026-07-14" });
// the deck list is already correct; the network is now someone else's problem
```

```rescript
cards.upsert({...gato, deck: "spanish", dueDate: "2026-07-14"})
// the deck list is already correct; the network is now someone else's problem
```

::: story
Tunnel two. Alice flips *gato*, taps *Pass*, and the card reschedules itself a week out. The queue reorders. Nothing about the moment suggests the server hasn't heard yet.
:::

The set of unsent writes is the **outbox**. It is not a log: it keeps *the latest write per id*. If Alice edits the same card three times offline, the server will receive one upsert with the final value — intermediate states are her device's business, not the protocol's.

### Deletes leave tombstones

`remove` follows the same shape with one twist: the local store keeps a *tombstone* — a dirty record saying "this was deleted" — instead of just dropping the row. The card leaves the cache and every list immediately; the tombstone is what lets a delete performed offline still reach the server after a restart. Once the remote confirms, the tombstone is purged.

Tombstones also guard the read path: a fetch that returns rows will not resurrect an id with a pending delete, and a row with a pending upsert keeps its optimistic value rather than being overwritten by a fetch that raced it. Everything defers to unsettled writes — the retention pruning of the [previous chapter](#reads-answer-twice) and inbound updates alike skip dirty rows and tombstones. The user's intent outranks any snapshot that predates it, and nothing removes it from disk until the server has heard it.

### Replay: reconnect and restart

The outbox drains through one flow, entered from two directions:

- **Reconnect** — `remote.online` flipping to true replays every queued write and marks live queries stale for a refresh. The library watches `online` reactively; no adapter code schedules this.
- **Restart** — at boot, `local.dirty()` returns the dirty rows and tombstones of the previous session, and each is fed through the exact same write path as a fresh edit. A write made offline on Tuesday and a write made just now are indistinguishable by the time they reach the remote.

That second entrance is the reason for step 1 above. Because durability comes first and replay reuses the ordinary flow, "the app was closed for a week" is not a special case — it is just a long tunnel.

::: pro
While a write is in flight, a newer write to the same id takes over: the old dispatch's channel is cancelled, so whatever it answers later is ignored. Latest write wins, and it wins completely — including the right to hear the server's reply.
:::

`status.pending` counts the outbox reactively, so a "syncing…" badge is one property read. What remains is the uncomfortable part: the server is allowed to say no. That conversation is the next chapter.
