---
name: Signal
slug: signal-type
kind: type
module: core
since: "2.0"
sort: 210
summary: Mutable single-value container used by signal-based APIs.
tags: []
signature.ts: "type Signal<T> = { value: T }"
signature.res: "type signal<'a> = {mutable value: 'a}"
label: Signal
---

The `Signal<T>`/`signal<'a>` type is the value container returned by [signal](api.html#signal) and [derived](api.html#derived).

Reads from `value` are trackable, and writes through setters update `value`.

See also [Setter](api.html#setter-type) and [lift](api.html#lift).

```typescript
import { carve } from "tilia";
import type { Signal } from "tilia";

// A parameter typed `Signal<string>` is a date the deck may read and not set.
// `today` came out of `signal`, but the type promises only a tracked `value`.
type Deck = { cards: Card[]; queue: Card[] };

const makeDeck = (today: Signal<string>) =>
  carve<Deck>(({ derived }) => ({
    cards: [],
    queue: derived((self) => self.cards.filter((card) => card.dueDate <= today.value)),
  }));
```

```rescript
open Tilia

type deck = {cards: array<card>, queue: array<card>}

// A parameter typed `signal<string>` is a date the deck may read and not set.
// `today` came out of `signal`, but the type promises only a tracked `value`.
let makeDeck = (today: signal<string>) =>
  carve(({derived}) => {
    cards: [],
    queue: derived(self => self.cards->Array.filter(card => card.dueDate <= today.value)),
  })
```
