---
title: A living object
slug: a-living-object
sort: 3
refs: [tilia, observe]
---

Claudine's first task is the first scenario: *a passed card waits longer*. Everything in tilia starts with two moves — make an object reactive, and react to it — and both fit in her first commit.

### An object, unchanged

[`tilia`](api.html#tilia) transforms a plain object or array into a reactive one. Nothing about its shape changes — you read and write properties exactly as before. What changes is invisible: every read and write can now be tracked, including on nested objects and arrays.

```typescript
import { tilia } from "tilia";

const card = tilia({
  front: "gato",
  back: "cat",
  interval: 3, // days before the card comes back
});

const pass = (card: Card) => {
  card.interval = card.interval * 2;
};
```

```rescript
open Tilia

let card = tilia({
  front: "gato",
  back: "cat",
  interval: 3, // days before the card comes back
})

let pass = card => card.interval = card.interval * 2
```

Notice what `pass` is: an ordinary function, mutating an ordinary-looking object, named with Alice's word. There is no store to register, no wrapper type to unwrap, no action to dispatch. The card is still a card. This matters more than it seems: the domain model *is* the state layer, so nothing in the code needs to know that tilia exists — except the glue, which comes next.

### Reacting: observe

[`observe`](api.html#observe) registers a callback that re-runs whenever a value it read has changed. This is **push** reactivity: changes push the callback to run.

```typescript
import { observe } from "tilia";

observe(() => {
  console.log(`"${card.front}" comes back in ${card.interval} day(s)`);
});

pass(card); // ✨ "gato" comes back in 6 day(s)
```

```rescript
open Tilia

observe(() => {
  Js.log(`"${card.front}" comes back in ${card.interval->Int.toString} day(s)`)
})

pass(card) // ✨ "gato" comes back in 6 day(s)
```

The mechanism is worth holding onto, because all of tilia rests on it. While the callback runs, tilia records which properties are read on which reactive objects — those exact properties, no more, become its dependencies. You never wrote a subscription, an event name, or an unsubscribe: you declared what the reaction needs by simply using it, and tilia drew the wiring from that. Writing a value equal to the current one notifies nobody; when a reaction should end, `observe` returns a function that stops it.

### A forest, not a tree

Reactive objects do not need to share a root. Separate `tilia` objects live in one shared context, and a single observer can depend on several of them — Alice's profile here, the settings there, no "which store does this belong to?" ever asked. Tracking even follows objects that are moved or copied between reactive parents: assign a card into another tilia object and both paths see the same living value.

::: pro
Use `tilia` when you want a quick reactive object. Designing a *feature* — state, derived values and actions as one self-contained object — is what [`carve`](#carving-a-feature) is for, two chapters from here.
:::

### Green

Adèle wires the scenario's words to these two functions — a small file whose workings [chapter 6](#a-clock-you-can-set) opens up — and runs the suite.

::: story
One line turns green: *a passed card waits longer*. Alice tries it that evening — taps **Pass**, and *gato* answers: six days. The first sentence she said at the kitchen table is now something the machine checks forever.
:::

One scenario remains red, and it is the more interesting one: *cards come due on their own*. Due-ness is not something anyone sets — it is a value that should **follow** other values. That is the next chapter.
