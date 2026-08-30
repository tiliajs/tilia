---
title: When the world returns
slug: when-the-world-returns
sort: 7
refs: [store-make, change-type, rejection-type, status-type, status, retry, discard]
chapter: "07"
---

Halfway down the valley, the phone finds a bar of signal. Forty-one operations begin reaching the server in the order Alice made them, while ordinary query refresh brings back the week as the server now knows it. Most of the reunion passes without a ripple — saved writes leave the outbox and fresh rows settle into their queries. This chapter is about the handful that collide.

While Alice was in the hills, her study group kept editing the shared deck. Nadia rewrote the example sentence on *echar de menos* — the same card Alice rewrote at Nora's table. Two honest edits, one card. What an app does next shows how much it *cares*.

The common answers are both small betrayals: refetch and let the server's copy silently replace Alice's week, or surface a raw "409 Conflict" and make the app's problem hers. The design here refuses both, using an old idea from version control: never compare two versions when you can compare three.

### Three versions on the table

When a fetched value, inbound delivery, or conflict response meets a row
already known locally, the store calls the `merge` function given to
`Store.make` for two related jobs. A successful save confirmation is already
authoritative and replaces the row directly.

1. fold remote fields into the existing object in place, preserving its reactive identity, and
2. decide whether the local and remote histories can be reconciled.

An `updated` change carries the **base** and the **edit** made from it; `remote` is the server's version. That provides the full three-way setup — base, yours, theirs. A true conflict exists only where the same field changed on both sides in different ways:

```typescript
const conflicts = <T>(base: T, mine: T, theirs: T) =>
  mine !== base && theirs !== base && mine !== theirs;
```

```rescript
let conflicts = (~base, ~mine, ~theirs) =>
  mine !== base && theirs !== base && mine !== theirs
```

Applied field by field, this rule separates disagreement from mere concurrency. If only Nadia changed the example, her sentence can be folded into Alice's existing object. If only Alice changed the interval, her edit remains. The [Change reference](api.html#change-type) gives the exact shapes for clean rows, creations, updates, and removals; the design purpose is the same in each case: preserve identity, preserve every distinct edit, and ask a human only when the histories truly disagree.

Return `true`, and the merged value stands. If this happened while an operation was pending, that operation has been rebased and can be tried against the newer server version. Nadia can fix the article while Alice tunes the interval, and both edits simply coexist — nobody needs to hear about a disagreement because there was none. Return `false`, and the store keeps server truth as the visible value and records Alice's version separately, with nothing thrown away.

### When a human must choose

Recorded disagreements — and mutations the server definitively refuses — land in `store.status.rejected`. Each record carries the local side of its story: what the row was, what was written, and the server's message when there is one. Server truth is already visible through the query. The records remain in outbox order even if replies arrived differently, so a chain of dependent edits can be considered cause first.

```typescript
const tryAgain = (rejection: Rejection<Card>) =>
  store.retry(rejection);

const keepTheirs = (rejection: Rejection<Card>) =>
  store.discard(rejection);

const saveResolution = (draft: Card) => store.upsert(draft);
```

```rescript
let tryAgain = rejection => store.retry(rejection)

let keepTheirs = rejection => store.discard(rejection)

let saveResolution = draft => store.upsert(draft)
```

`retry` is for work that should be attempted again: perhaps Alice signed in again after a policy rejection. It drops that rejection, reapplies its saved edit against the value visible now, and queues a new ordinary operation. `discard` accepts the visible server truth and drops only the recovery record. When a human composes a third version, as Alice will, an ordinary upsert writes it and clears the older rejection for that card; there is no special conflict-writing mode.

The exact rejection object matters. Recovery acts on the record the screen was actually showing; if a later write has already cleared or replaced it, a stale button does nothing. That small rule prevents an old dialog from reviving an older history.

The invariant underneath is the one from chapter 1 — **no version is ever silently lost**. The server's week is in the deck; Alice's week is either merged in or held, verbatim, in a context waiting for her eyes.

::: story
One card interrupts the bus ride: *echar de menos*, her sentence and Nadia's, side by side. Nadia's verb is better; Alice's ending is funnier. She takes thirty seconds to weave them into one sentence neither of them wrote, taps keep, and the deck moves on — one question asked, out of forty-one writes and a week apart.
:::

::: pro
Design the conflict screen before you need it, in domain language — "two versions of this card" beats "sync error". If the screen is kind, conflicts stop being failures and become what they actually are: two people caring about the same thing.
:::

The trip is over: tunnels, buses, a week in the hills, two devices, one disagreement, zero losses. What remains is to step back and see what was actually built — and what any stack, with or without this library, ought to promise.
