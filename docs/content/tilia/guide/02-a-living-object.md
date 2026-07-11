---
title: A living object
slug: a-living-object
sort: 2
refs: [tilia, observe]
---

Everything in tilia starts with two moves: make an object reactive, and react to it. This chapter is about those two moves and the mental model behind them.

### An object, unchanged

[`tilia`](api.html#tilia) transforms a plain object or array into a reactive one. Nothing about its shape changes — you read and write properties exactly as before. What changes is invisible: every read and write can now be tracked, including reads and writes on nested objects and arrays.

```typescript
import { tilia } from "tilia";

const card = tilia({
  front: "gato",
  back: "cat",
  interval: 1, // days before the card comes back
  lastReview: "2026-07-06",
});
```

```rescript
open Tilia

let card = tilia({
  front: "gato",
  back: "cat",
  interval: 1, // days before the card comes back
  lastReview: "2026-07-06",
})
```

::: story
Alice writes her first card: *gato*. She saw it yesterday. It comes back today.
:::

There is no store to register, no wrapper type to unwrap. The card is still a card. This matters more than it seems: the domain model you already have *is* the state layer, so nothing in your code needs to know that tilia exists — except the glue, which comes next.

### Reacting: observe

[`observe`](api.html#observe) registers a callback that re-runs whenever a value it read has changed. This is **push** reactivity: changes push the callback to run.

```typescript
import { observe } from "tilia";

observe(() => {
  console.log(`"${card.front}" comes back in ${card.interval} day(s)`);
});

card.interval = 3; // ✨ triggers the observe callback
```

```rescript
open Tilia

observe(() => {
  Js.log(`"${card.front}" comes back in ${card.interval->Int.toString} day(s)`)
})

card.interval = 3 // ✨ triggers the observe callback
```

The mechanism is worth holding onto, because all of tilia rests on it. During the callback's execution, tilia records which properties are read on which reactive objects. Those exact properties — no more — become the callback's dependencies. The callback always runs once when `observe` is set up, which is how the first dependencies are captured.

Notice what you did not write: no subscription list, no event names, no unsubscribe bookkeeping. You declared what the reaction needs by simply using it, and tilia drew the wiring from that.

Two details complete the picture. Writing a value that is *equal* to the current one notifies nobody — silence is the correct reaction to a non-change. And if the callback mutates a value it also observes, it is scheduled to run again as soon as it ends; that behavior is deliberate and powerful, and [chapter 7](#time-and-consistency) treats it with the care it deserves.

### A forest, not a tree

Reactive objects do not need to share a root. Separate `tilia` objects live in one shared context, and a single observer can depend on several of them:

```typescript
const alice = tilia({
  name: "Alice",
  streak: 0,
});
const settings = tilia({ dailyGoal: 10 });

observe(() => {
  console.log(`${alice.name}: ${alice.streak} / ${settings.dailyGoal}`);
});

alice.streak = 1; // ✨ triggers
settings.dailyGoal = 20; // ✨ also triggers
```

```rescript
let alice = tilia({
  name: "Alice",
  streak: 0,
})
let settings = tilia({dailyGoal: 10})

observe(() => {
  Js.log(`${alice.name}: ${alice.streak->Int.toString} / ${settings.dailyGoal->Int.toString}`)
})

alice.streak = 1 // ✨ triggers
settings.dailyGoal = 20 // ✨ also triggers
```

This is **forest mode**. It is why you never face the question "which store does this belong to?" — there is no store, only objects. Tracking even follows objects that are moved or copied between reactive parents: assign `card` into another tilia object and both paths see the same living value.

::: pro
Use `tilia` when you want a quick reactive object and you are not designing a feature. Designing a feature — state, derived values and actions as one self-contained object — is what [`carve`](#carving-a-feature) is for.
:::

The scheduler so far is one card and a console line. It needs a sense of time: when is a card *due*? That is a value that should follow other values on its own, and it opens the next chapter.
