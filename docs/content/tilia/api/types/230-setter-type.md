---
name: Setter
slug: setter-type
kind: type
module: core
since: "2.0"
sort: 230
summary: Function type that assigns a new value of the same type.
tags: []
signature.ts: "type Setter<T> = (v: T) => void"
signature.res: type setter<'a> = 'a => unit
label: Setter
---

The `Setter<T>`/`setter<'a>` type defines the callback shape used by [signal](api.html#signal), [source](api.html#source), and [store](api.html#store).

It accepts the next value and returns `void`/`unit`.

```typescript
import { signal } from "tilia";
import type { Setter, Signal } from "tilia";

// Whoever holds the setter owns the writes. The scheduler receives `setToday`
// and advances the date at midnight; the deck receives the signal and can
// only read it.
const advance = (setToday: Setter<string>, today: Signal<string>) => () => setToday(addDays(today.value, 1));

const [today, setToday] = signal("2026-07-15");
const deck = makeDeck(today);
schedule("00:00", advance(setToday, today));
```

```rescript
open Tilia

// Whoever holds the setter owns the writes. The scheduler receives `setToday`
// and advances the date at midnight; the deck receives the signal and can
// only read it.
let advance = (setToday: setter<string>, today: signal<string>) => () =>
  setToday(addDays(today.value, 1))

let (today, setToday) = signal("2026-07-15")
let deck = makeDeck(today)
schedule("00:00", advance(setToday, today))
```
