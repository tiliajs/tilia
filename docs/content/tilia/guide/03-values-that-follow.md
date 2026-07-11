---
title: Values that follow
slug: values-that-follow
sort: 3
refs: [computed]
---

`observe` reacts to change by *doing* something. Just as often, you want a value that simply *is* something — always correct, derived from other values, never manually refreshed. That is [`computed`](api.html#computed).

### Pull, not push

A computed value is the mirror image of an observer. Where `observe` uses push reactivity — changes push the callback to run — `computed` uses **pull**: the value is calculated when the key is read, cached, and invalidated when any value it depends on changes. Until someone reads it again, no work happens.

The scheduler needs to know when a card is due. Due-ness depends on the last review, the interval, and today's date — so let today's date be a reactive value too:

```typescript
import { tilia, computed } from "tilia";

const clock = tilia({ today: "2026-07-07" });
// something updates clock.today once a day

const card = tilia({
  front: "gato",
  interval: 3,
  lastReview: "2026-07-06",
  dueDate: computed(() => addDays(card.lastReview, card.interval)),
  due: computed(() => card.dueDate <= clock.today),
});
```

```rescript
open Tilia

let clock = tilia({today: "2026-07-07"})
// something updates clock.today once a day

let card = tilia({
  front: "gato",
  interval: 3,
  lastReview: "2026-07-06",
  dueDate: "",
  due: false,
})
card.dueDate = computed(() => addDays(card.lastReview, card.interval))
card.due = computed(() => card.dueDate <= clock.today)
```

::: story
Alice reviews *gato*, and the card quietly knows when it wants to be seen again. When the clock rolls over at midnight, cards become due — nobody asks them to.
:::

Consider what did not have to be written: no `refreshDueDate()` to call after every review, no midnight job that walks the cards, no risk of a stale `dueDate` because some code path forgot to update it. The relationship was declared once; tilia keeps it true.

### Computed values chain

`dueDate` is itself built from reactive values, and `due` is built from `dueDate`. Computed values compose freely: change `card.interval` and `dueDate` is invalidated, which invalidates `due`, and anything observing `due` reacts. You describe each step of the derivation in its own small function, and the dependency graph assembles itself.

### The cost model

Once calculated, a computed value behaves exactly like a regular value until a dependency changes and expires it. Reading it is a cache hit — there is nearly zero overhead for computed values acting as getters. This is what makes it reasonable to model *everything* derivable as `computed`, rather than rationing them the way you might ration expensive selectors elsewhere.

::: pro
A `computed` can be created anywhere, but it only becomes active once it is inserted into a tilia object or array. Assigning one into an existing reactive object — as the ReScript example above does — is the normal way to derive a value from the object itself.
:::

One honest simplification in this chapter: we wrote `computed(() => ...)` referring to `card` from inside `card`'s own definition. The rules for where a computation may live before it is attached — and how tilia protects you when you get it wrong — are spelled out in [chapter 9](#what-keeps-it-honest).

One card now knows its own schedule. But Alice has a boxful, and a box of cards with sorting, review actions and persistence is not a value — it is a *feature*. Building one as a single coherent object is the subject of the next chapter.
