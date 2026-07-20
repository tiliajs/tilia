---
title: When the world returns
slug: when-the-world-returns
sort: 7
refs: [change-type, rejection-type, status-type, status, dismiss]
---

Halfway down the valley the phone finds a bar of signal, the connectivity signal flips, and two things happen at once: forty-one operations push to the server in the order Alice made them, and a week of the server's own history comes back the other way. Most of it passes without a ripple — confirmed writes leave the outbox, changed rows slot into their queries. This chapter is about the handful that collide.

While Alice was in the hills, her study group kept editing the shared deck. Nadia rewrote the example sentence on *echar de menos* — the same card Alice rewrote at Nora's table. Two honest edits, one card. What an app does next shows how much it *cares*.

The common answers are both small betrayals: refetch and let the server's copy silently replace Alice's week, or surface a raw "409 Conflict" and make her problem out of the app's. The design here refuses both, using an old idea from version control: never compare two versions when you can compare three.

### Three versions on the table

When a remote value arrives for a row already known locally, the engine calls your `merge` function for two related jobs:

1. fold remote fields into the existing object in place, preserving its reactive identity, and
2. decide whether the local and remote histories can be reconciled.
 
`change` tells the local story: `Clean` carries the current value with no local edit, `Created` a new local value, `Updated` the **base** and the **edit** made from it, and `Removed` the deleted value; `remote` is the server's version. For a conflict, `Updated` provides the full three-way setup — base, yours, theirs. A conflict only happens when the same field changed from *both* sides, away from each other:

```typescript
merge: (change, remote) => {
  switch (change.change) {
    case "clean": 
      // no local edit: fold the server's fields in place
      Object.assign(change.value, remote);
      return true;
    case "updated": {
      const { base, edited: mine } = change;
      for (const key of editableFields) {
        const iChanged = mine[key] !== base[key];
        const theyChanged = remote[key] !== base[key];
        if (iChanged && theyChanged && mine[key] !== remote[key]) return false;
        if (theyChanged) mine[key] = remote[key];
      }
      // both edits survive, in one card
      return true;
    }
    case "created":
      // the server already has this id: same card, or a conflict
      return editableFields.every((key) => change.edited[key] === remote[key]);
    case "removed":
      // keep the freshest version under the pending remove
      Object.assign(change.base, remote);
      return true;
  }
},
```

```rescript
merge: (~change, ~remote) =>
  switch change {
  | Clean({value}) =>
    // fold the server's fields in place
    value.example = remote.example 
    true
  | Updated({base, edited: mine}) =>
    if mine.example !== base.example && remote.example !== base.example {
      mine.example === remote.example // the same rewrite is no conflict
    } else {
      if remote.example !== base.example {
        mine.example = remote.example
      }
      // both edits survive, in one card
      true 
      // …the other fields follow the same three-way rule
    }
    // same card, or a conflict
  | Created({edited}) => edited.example === remote.example 
  | Removed({base}) =>
    // keep the freshest version under the pending remove
    base.example = remote.example 
    true
  },
```

Return `true` and the merged value stands: Nadia fixed the article on one card while Alice tuned its interval, and both changes simply coexist — nobody ever knows there was a disagreement, because there wasn't one. Return `false` and the engine keeps remote truth as the visible value and records the disagreement, with nothing thrown away.

### When a human must choose

Recorded disagreements — and mutations the server definitively refuses at push time — land in `status.rejected`, each carrying the local side of its story: what the row was, what was written, and the server's message when there is one. Remote truth is already visible in the collection. The reactive list is the app's cue to ask, gently, with both versions on screen:

```typescript
const keepTheirs = (r: Rejection<Card>) => cards.dismiss(r);

const keepMine = (r: Rejection<Card>, edited: Card) => {
  cards.upsert(edited); // a newer write wins over an older rejection
  cards.dismiss(r);
};
```

```rescript
let keepTheirs = r => cards.dismiss(r)

let keepMine = (r, edited) => {
  cards.upsert(edited) // a newer write wins over an older rejection
  cards.dismiss(r)
}
```

There is no special conflict-resolution mode: keeping your version is an ordinary write, pushed like any other. `dismiss` only retires the context once a human has resolved or ignored it; it neither retries nor changes data. The invariant underneath is the one from chapter 1 — **no version is ever silently lost**. The server's week is in the deck; Alice's week is either merged in or held, verbatim, in a context waiting for her eyes.

::: story
One card interrupts the bus ride: *echar de menos*, her sentence and Nadia's, side by side. Nadia's verb is better; Alice's ending is funnier. She takes thirty seconds to weave them into one sentence neither of them wrote, taps keep, and the deck moves on — one question asked, out of forty-one writes and a week apart.
:::

::: pro
Design the conflict screen before you need it, in domain language — "two versions of this card" beats "sync error". If the screen is kind, conflicts stop being failures and become what they actually are: two people caring about the same thing.
:::

The trip is over: tunnels, buses, a week in the hills, two devices, one disagreement, zero losses. What remains is to step back and see what was actually built — and what any stack, with or without this library, ought to promise.
