---
name: derived
slug: derived
kind: function
module: core
since: "2.1"
sort: 100
summary: Create a signal whose value is computed from reactive dependencies.
tags: []
signature.ts: "function derived<T>(fn: () => T): Signal<T>"
signature.res: "let derived: (unit => 'a) => signal<'a>"
label: derived(fn)
---

`derived` computes a signal's value from reactive reads in `fn`. The returned signal exposes the computed result at `.value`.

Internally, this is equivalent to creating a signal with a [computed](api.html#computed) value. Consumers track `signal.value` like any other signal.

Use [signal](api.html#signal) for manual writes, and [lift](api.html#lift) to insert a derived signal into objects.

```typescript
import { derived, observe } from "tilia";

// A value that follows, before it has a home in a larger object: how many
// cards are due, from a deck and a date that both move.
const dueCount = derived(() => deck.cards.filter((card) => card.dueDate <= today.value).length);

observe(() => {
  badge.textContent = String(dueCount.value);
});
setToday("2026-07-16"); // the badge follows; nobody recounted
```

```rescript
open Tilia

// A value that follows, before it has a home in a larger object: how many
// cards are due, from a deck and a date that both move.
let dueCount = derived(() =>
  deck.cards->Array.filter(card => card.dueDate <= today.value)->Array.length
)

observe(() => badge.textContent = dueCount.value->Int.toString)->ignore
setToday("2026-07-16") // the badge follows; nobody recounted
```
