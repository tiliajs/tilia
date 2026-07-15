---
title: Writing without waiting
slug: writing-without-waiting
sort: 4
refs: [upsert, remove, status, op-type]
---

A write in @tilia/query never waits for the network. `upsert` and `remove` return immediately, and the library takes on the debt of making the write true everywhere else. This chapter is about how that debt is recorded, honored, and never lost.

### One motion, everywhere

When Alice edits a card, `upsert` moves through three layers in one motion:

- **Memory** — the object cache takes the value, and every in-memory query adjusts *in place* through `matches`: the card enters lists whose filter now accepts it and leaves lists it no longer matches. Moving a card between decks updates both results at once, with no refetch — asking the server which lists a value belongs to would be a round trip to compute what a predicate already knows.
- **Disk** — the local store takes the row, and the affected queries' persisted records take the membership change. (Records that exist only on disk are not scanned; they catch up on that query's next refresh.)
- **The outbox** — the operation joins the queue under a sequence number, and the queue entry is itself persisted. If the app dies on the next line, the write already survives.

Then, if online, queued operations are pushed. If not, they wait.

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

### The outbox is an ordered, durable log

Every operation gets a sequence number, and with a local store configured, every operation is persisted the moment it is queued. Three edits to the same card offline are three operations, in order — the server receives the same history the device lived, and order is the one promise that survives everything: disconnection, restart, even rejection. `status.pending` counts the queue reactively, so a "syncing…" badge is one property read.

When the connection allows, a push gathers every pending operation not already **in flight** and sends them as one ordered batch. In flight means sent but unconfirmed; the marking is what stops a second push from sending the same operations twice. The remote confirms each operation individually — an upsert confirmation carries the **authoritative** value, because the server may have corrected it, and whatever comes back replaces the local copy; a remove is confirmed by id. Confirmed operations leave the outbox and the count drops. A transient failure returns the whole unconfirmed batch to pending for a later try: nothing lost, nothing reordered.

`remove` is the same motion with less luggage: the id leaves every in-memory list and the persisted records, the local row is deleted, and an id-only operation queues — a remove never needs the full value. Its confirmation merely clears the operation; the local deletion happened long ago.

::: pro
Confirmations are matched by id, not by position — if your API answers out of order, confirm in whatever order the answers arrive.
:::

### The overlay: a write never flickers

A remote answer describes the server *before* the outbox drains. So every remote delivery is overlaid before it becomes visible: pending operations are re-applied on top — a pending upsert replaces the server's copy of the row, joins results it matches and leaves the ones it no longer does; a pending remove filters its id out. An optimistic write cannot flicker out of a list just because a refresh raced it. The user's intent outranks any snapshot that predates it.

### Replay: reconnect and restart

The outbox drains through one flow, entered from two directions:

- **Reconnect** — `remote.online` flipping to true pushes the queue. The library watches the signal reactively; no adapter code schedules this.
- **Restart** — at boot, persisted operations reload in sequence order and, once online, replay through the exact same push. A write made offline on Tuesday and a write made just now are indistinguishable by the time they reach the remote.

Because durability is part of the write itself and replay reuses the ordinary flow, "the app was closed for a week" is not a special case — it is just a long tunnel.

::: story
Which Alice decides to test: a suitcase, flight mode, a week at Nora's in Madrid with no data plan. That night the phone restarts, offline, in another country. Every deck she has ever opened is there, marked cached; the airport's reviews wait in the outbox; the one screen she never opened at home says *not available offline*. Nothing is lost — it is all just held.
:::

What remains is the uncomfortable part: the server is allowed to say no. That conversation is the next chapter.
