---
title: While Alice sleeps
slug: while-alice-sleeps
sort: 9
refs: [batch, watch, observe]
---

Every night at three, the app imports the day's new cards — Adèle subscribed Alice to a shared Spanish deck. Dozens of writes land at once, and they force the question: *when*, exactly, does a reaction run? tilia has one clear rule, one tool for the exception, and one function for separating cause from effect.

### The flush rule

When you modify a value **outside** any observation context — an event handler, a timeout — every write notifies immediately. When you modify a value **inside** one — a `computed`, `observe` or `watch` callback, a rendering component — notifications are deferred until the callback ends.

The immediate half keeps simple code simple: write a value, watch the screen change. But it means multi-field updates expose transient states. A review touches two fields:

```typescript
card.interval = 6;
// ⚠️ an observer running now sees the new interval with the
// OLD lastReview: a dueDate that was never true
card.lastReview = deck.today;
```

```rescript
card.interval = 6
// ⚠️ an observer running now sees the new interval with the
// OLD lastReview: a dueDate that was never true
card.lastReview = deck.today
```

### batch: atomic by declaration

[`batch`](api.html#batch) groups writes and notifies once, at the end:

```typescript
import { batch } from "tilia";

batch(() => {
  card.interval = 6;
  card.lastReview = deck.today;
});
// ✨ one coherent notification here
```

```rescript
open Tilia

batch(() => {
  card.interval = 6
  card.lastReview = deck.today
})
// ✨ one coherent notification here
```

The review now moves from one true state to the next. Around the nightly import, the same boundary turns forty-one pushes into one coherent change:

::: story
Three in the morning. Forty-one new cards slide into the deck — one notification, one repaint that nobody sees. When Alice wakes, the queue is simply longer, and *el desayuno* is waiting.
:::

::: pro
`batch` is not needed inside `computed`, `source`, `store`, `observe` or `watch` — there, notifications are already deferred. Reach for it in event handlers, network callbacks, and initialization code.
:::

### watch: cause, then effect

Alice's score should follow her results — a value change *causing* a mutation. That must not be a `computed` (a computed that writes what it reads invalidates itself, forever), and plain `observe` would track too much. [`watch`](api.html#watch) splits the two phases: a **capture** function, tracked, defines what is being watched; an **effect** function runs untracked when the captured value changes.

```typescript
import { watch } from "tilia";

watch(
  () => session.result,
  (r) => {
    if (r === "Pass") alice.score = alice.score + 1;
    else if (r === "Fail") alice.score = alice.score - 1;
  }
);
```

```rescript
open Tilia

watch(
  () => session.result,
  r =>
    switch r {
    | Pass => alice.score = alice.score + 1
    | Fail => alice.score = alice.score - 1
    | Pending => ()
    },
)
```

The rule that matters: a `watch` never re-triggers itself from its own writes, in either phase — while its effects still notify everyone else, deferred, as one batch. Cause and effect, cleanly separated; the scenario *the score follows results* goes green with these six lines.

One sharper tool for completeness: inside `observe`, mutating a value the same callback reads schedules one more run, repeating until a run changes nothing. That is how an `observe` can drive a state machine to a fixed point — and how it can loop forever if no fixed point exists. Deliberate, powerful, sharp; make sure every self-feeding `observe` converges.

The whole scheduling model fits in one sentence: *writes notify immediately unless a reactive callback or a batch is running, and every callback sees a coherent world.* With the model complete, it is time to give the scheduler a face.
