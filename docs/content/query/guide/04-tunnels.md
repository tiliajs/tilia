---
title: Tunnels
slug: tunnels
sort: 4
refs: []
---

The engine never guesses about connectivity. The application owns a tilia signal and tells the state as it changes:

```typescript
import { signal } from "tilia";

const [online, setOnline] = signal(navigator.onLine);
window.addEventListener("online", () => setOnline(true));
window.addEventListener("offline", () => setOnline(false));
```

```rescript
open Tilia

let (online, setOnline) = signal(true)
window.addEventListener("online", () => setOnline(true))
window.addEventListener("offline", () => setOnline(false))
```

That signal went into the config in [chapter 2](#a-shape-for-queries). Everything this chapter describes hangs off it and off one decision about mutations.

### Mutations apply now

Every mutation is optimistic: the local state changes before the remote hears about it. Alice's review action barely changes from the tilia guide:

```typescript
const review = (card: Card, result: Result) =>
  cards.upsert({
    ...card,
    interval: result === "Pass" ? card.interval * 2 : 1,
    lastReview: clock.today,
  });
```

```rescript
let review = (card, result) =>
  cards.upsert({
    ...card,
    interval: result === Pass ? card.interval * 2 : 1,
    lastReview: clock.today,
  })
```

`upsert` does four things, in order. It updates the value in memory and in the local store. It updates query membership using `matches`: the new value joins every in-memory query it now matches and leaves every one it no longer does, so moving a card between decks updates both lists at once, no refetch. It appends the operation to the **outbox**. And if the remote is online, it pushes. Voilà.

Note what is *not* in that list: waiting. This is where you win your users. The write path never blocks on the network. The app is snappy by construction, and offline support stops being a mode — it is just the case where step four waits.

### The outbox

The outbox is an ordered queue of operations the remote has not yet confirmed. Each mutation gets a sequence number; when the local store is configured, each is persisted, so pending writes survive a restart. The queue is visible as one observable number:

```typescript
cards.status.pending; // operations waiting for the remote — reactive
```

```rescript
cards.status.pending // operations waiting for the remote — reactive
```

When the connection returns, the signal flips to `true` and pending operations are pushed as one ordered batch. The remote confirms each one; a confirmed upsert comes back with the authoritative value, because the server may have corrected it, and that value replaces memory and local storage.

Confirmed operations leave the outbox, `pending` counts down, and the app is exactly where it would be if the network had never left. A transient failure just returns the batch to pending for a later try. A failure that is *not* transient (when the server says "no") is explained in [chapter 7](#when-the-world-returns).

::: story
Twenty minutes in, the train drops into the first tunnel mid-review. Alice taps *Pass*; the card reschedules; the queue advances. In the corner of the screen, a small "3 pending" appears, then the mountain ends and it fades away. She notices none of it — which is the entire review criterion for this chapter.
:::

::: pro
Show `status.pending` somewhere small. "3 changes pending" is calm, specific, and true. It is better than silence, far better than an alarm. The number counting down after a tunnel is the app visibly keeping its promise.
:::

The laptop's outbox empties between tunnels, which is about to matter: at the end of this train ride, Alice puts the laptop away. The deck is getting on the bus in a different pocket.
