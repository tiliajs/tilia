---
title: Values that follow
slug: values-that-follow
sort: 4
refs: [computed, signal]
---

*Cards come due on their own.* Alice's second scenario contains a small philosophical demand: nobody moves the cards, yet at midnight they are due. `observe` reacts to change by *doing* something. What this scenario needs is a value that simply *is* something — always correct, derived from other values, never manually refreshed. That is [`computed`](api.html#computed).

### Pull, not push

A computed value is the mirror image of an observer. Where `observe` uses push — changes push the callback to run — `computed` uses **pull**: the value is calculated when the key is read, cached, and invalidated when a dependency changes. Until someone reads it again, no work happens.

Due-ness depends on the last review, the interval, and today's date — so let today's date be a reactive value too. A [`signal`](api.html#signal) gives that standalone value a home; its setter will matter when midnight arrives:

```typescript
import { tilia, computed, signal } from "tilia";

const [today] = signal("2026-07-15");

const card = tilia({
  front: "gato",
  interval: 3,
  lastReview: "2026-07-12",
  dueDate: computed(() => addDays(card.lastReview, card.interval)),
  due: computed(() => card.dueDate <= today.value),
});
```

```rescript
open Tilia

let (today, _) = signal("2026-07-15")

let card = tilia({
  front: "gato",
  interval: 3,
  lastReview: "2026-07-12",
  dueDate: "",
  due: false,
})
card.dueDate = computed(() => addDays(card.lastReview, card.interval))
card.due = computed(() => card.dueDate <= today.value)
```

Consider what did not have to be written: no `refreshDueDate()` after every review, no midnight job that walks the cards, no risk of a stale `dueDate` because some code path forgot. The relationship was declared once, in two lines that read like the sentence Alice said; tilia keeps it true. And computed values chain — change `interval` and `dueDate` expires, which expires `due`, and anything watching `due` reacts. Each step of the derivation is its own small function; the graph assembles itself.

Reading a computed that has not expired is a cache hit, nearly free. This is why you can model *everything* derivable this way, instead of rationing derived values like expensive selectors.

### Claudine's first mistake

Claudine's first draft did something reasonable-looking:

```typescript
// ❌ a definition, stranded in a variable
const due = computed(() => card.dueDate <= today.value);
if (due) { ... }
// 💥 Error: orphan computation detected
```

```rescript
// ❌ a definition, stranded in a variable
let due = computed(() => card.dueDate <= today.value)
if due { ... }
// 💥 Error: orphan computation detected
```

`computed` returns a *definition*, not a value — it only comes to life once it is inserted into a tilia object. Used anywhere else, it fails immediately, loudly, at the line that broke the rule. Claudine reads the error, moves the computed into the card, and the moment passes. Note what did *not* happen: no silent wrong value, no bug surfacing three files away, no need for a human to have been watching. The library holds the rule so that no collaborator — however new — can drift far from it.

::: pro
The golden rule: never assign a `computed` (or `source`, or `store`) to an intermediate variable — define it directly inside a `tilia` or `carve` object. [Chapter 11](#mistakes-stay-small) tells the rest of the safety story.
:::

### Green, at midnight

Adèle runs the suite: *cards come due on their own* turns green.

::: story
The scenario said "When midnight comes" — and midnight came, on a Tuesday afternoon, in eleven milliseconds. Nobody in the kitchen finds this remarkable. It should be: it means the app owns its idea of today.
:::

How midnight can come on command is a trick worth its own chapter — [chapter 6](#a-date-you-can-set). But first: one card knowing its schedule is not an app. Alice has a boxful, and a box with an order to it, an action to review, a place to keep everything — that is not a value. It is a *feature*.
