---
title: Time and consistency
slug: time-and-consistency
sort: 7
refs: [batch, watch, observe]
---

Reactivity is easy to demonstrate and subtle to schedule. *When* does an observer run — immediately, or once things settle? tilia has one clear rule, one tool for the exception, and one function whose whole purpose is separating cause from effect. This chapter is the guide's most technical, and the one that pays off longest.

### The flush rule

When you modify a value **outside** any observation context — an event handler, a `setTimeout` — every write notifies immediately. When you modify a value **inside** an observation context — a `computed`, `observe` or `watch` callback, a `leaf` component — notifications are deferred until the callback ends.

The immediate half keeps simple code simple: write a value, watch the screen change. But it means multi-field updates expose transient states. A review touches two fields:

```typescript
// After a pass: double the interval, stamp the review
card.interval = 6;
// ⚠️ an observer running now sees the new interval
// with the OLD lastReview — a dueDate that was never true
card.lastReview = clock.today;
```

```rescript
// After a pass: double the interval, stamp the review
card.interval = 6
// ⚠️ an observer running now sees the new interval
// with the OLD lastReview — a dueDate that was never true
card.lastReview = clock.today
```

### batch: atomic by declaration

`batch` groups writes and notifies once, at the end:

```typescript
import { batch } from "tilia";

batch(() => {
  card.interval = 6;
  card.lastReview = clock.today;
});
// ✨ one coherent notification here
```

```rescript
open Tilia

batch(() => {
  card.interval = 6
  card.lastReview = clock.today
})
// ✨ one coherent notification here
```

::: story
Every night while Alice sleeps, the app imports the day's new cards — dozens of writes, one notification, one repaint.
:::

::: pro
`batch` is not required inside `computed`, `source`, `store`, `observe` or `watch` — there, notifications are already deferred. Reach for it in event handlers, network callbacks, and initialization code.
:::

### observe can feed itself

Inside `observe`, mutating a value the same callback observes schedules one more run after the current one ends. Runs repeat until the callback makes no observed change — which is how an `observe` can drive a state machine to a fixed point, and also how it can loop forever if no fixed point exists. Deliberate, powerful, sharp: make sure every self-feeding `observe` converges.

### watch: cause, then effect

Often you want something narrower than `observe`: react to *this* value changing, then act — including acting on values the reaction should not depend on. `watch` splits the two phases. The **capture function** is tracked and defines the dependencies; the **effect function** runs untracked when the captured value changes.

The scheduler's heart is exactly this shape — a result comes in, the score and the card react:

```typescript
import { watch } from "tilia";

watch(
  () => session.result,
  (r) => {
    if (r === "Pass") {
      alice.score = alice.score + 1;
    } else if (r === "Fail") {
      alice.score = alice.score - 1;
    }
  }
);

session.result = "Pass"; // ✨ triggers the effect
alice.score = alice.score + 10; // does not — score is not captured 💤
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

session.result = Pass // ✨ triggers the effect
alice.score = alice.score + 10 // does not — score is not captured 💤
```

The rule that matters: a `watch` never re-triggers itself from its own writes, in either phase. The effect's writes still notify *other* observers — deferred, as one batch. (That is the simplified statement; the precise mechanics live with the [`watch` API entry](api.html#watch).)

### Why not just mutate in computed?

Because a `computed` that reads and writes the same value invalidates itself: read, write, invalidate, recalculate — an infinite loop. A `computed` must stay a pure derivation. When a value change should *cause a mutation* — appending to Alice's review history, say — that is a cause-and-effect pair, and `watch` is its home:

```typescript
// ✅ observation tracked, mutation untracked — no loop possible
watch(
  () => session.result,
  (result) => {
    alice.history.push(result);
  }
);
```

```rescript
// ✅ observation tracked, mutation untracked — no loop possible
watch(
  () => session.result,
  result => {
    alice.history->Array.push(result)
  },
)
```

Between the flush rule, `batch`, and `watch`, the scheduling model fits in a sentence: *writes notify immediately unless a reactive callback or a batch is running, and every callback sees a coherent world.* With the model complete, it is time to put a face on the scheduler — tilia in React.
