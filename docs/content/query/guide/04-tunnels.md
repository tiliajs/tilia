---
title: Tunnels
slug: tunnels
sort: 4
refs: [store-make, store-online, upsert, remove, status-type, status]
chapter: "04"
---

The default store follows browser connectivity through `Store.online()`. `Store.make` uses that shared signal unless the application supplies another one, so for most browser apps a tunnel requires no feature-level code.

Connectivity is a permission to try, not proof that a request will succeed. A train can keep its Wi-Fi icon through a dead tunnel. That is why backend operations can still report a transient outcome: online begins the attempt; only the reply settles it.

### Mutations apply now

Every mutation is optimistic: the local state changes before the remote hears about it. Alice's review action barely changes from the tilia guide:

```typescript
const review = (card: Card, result: Result) =>
  store.upsert({
    ...card,
    interval: result === "Pass" ? card.interval * 2 : 1,
    lastReview: clock.today,
  });
```

```rescript
let review = (card, result) =>
  store.upsert({
    ...card,
    interval: result === Pass ? card.interval * 2 : 1,
    lastReview: clock.today,
  })
```

`store.upsert` changes the shared in-memory value immediately. It updates query membership using `matches`: the new value joins every in-memory query it now matches and leaves every one it no longer does, so moving a card between decks updates both lists at once without another find. Then it appends the operation to the **outbox** and, when online, asks the backend to save it. `store.remove(id)` follows the same path in the other direction.

Note what is *not* in that list: waiting. The write path never blocks on the network. The app is responsive by construction, and offline support stops being a mode — it is just the case where delivery waits.

### The outbox

The outbox is an ordered queue of operations the backend has not yet confirmed. The queue is visible through the store as one reactive number:

```typescript
store.status.pending; // operations waiting for the backend
```

```rescript
store.status.pending // operations waiting for the backend
```

`Store.make` preserves that order by issuing one operation and waiting for its outcome before issuing the next. This is not merely an implementation detail. One change may depend on an earlier one; allowing later work to overtake its cause would change the meaning of Alice's actions.

A saved upsert comes back with the backend's authoritative value, so server
corrections can settle into the same row. A conflict comes back with the
server's row: if the histories merge, the rebased operation stays pending; if
they do not, server truth becomes visible and the local story becomes a
rejection. A definitive rejection applies only to that operation: its
optimistic effect is reverted, its context is kept for recovery, and later
independent work may continue. A transient outcome says the backend knows
nothing certain about the operation, so the sequence stops there and that
operation — together with everything after it — waits untouched for a later
tick or reconnect.

Confirmed operations leave the outbox and `pending` counts down. Persistence in [chapter 6](#a-week-at-noras) will make the same ordered queue survive a restart; recovery from a conflict or rejection belongs to [chapter 7](#when-the-world-returns).

::: story
Twenty minutes in, the train drops into the first tunnel mid-review. Alice taps *Pass*; the card reschedules; the queue advances. In the corner of the screen, a small "3 pending" appears, then the mountain ends and it fades away. She notices none of it — which is the entire success criterion for this chapter.
:::

::: pro
Show `status.pending` somewhere small. "3 changes pending" is calm, specific, and true. It is better than silence, far better than an alarm. The number counting down after a tunnel is the app visibly keeping its promise.
:::

The laptop's outbox empties between tunnels, which is about to matter: at the end of this train ride, Alice puts the laptop away. The deck is getting on the bus in a different pocket.
