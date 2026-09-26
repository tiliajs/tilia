---
name: signal
slug: signal
kind: function
module: core
since: "2.0"
sort: 90
summary: Create a single-value reactive signal and its setter.
tags: []
signature.ts: "function signal<T>(value: T): [Signal<T>, Setter<T>]"
signature.res: "let signal: 'a => (signal<'a>, setter<'a>)"
label: signal(value)
---

`signal` returns a pair: a reactive object `{ value }` and a setter function.

The signal object is a Tilia proxy, so reads of `.value` are tracked, and writes through the setter notify dependents. This provides a compact form for individual mutable values.

Use [derived](api.html#derived) to build a computed signal and [lift](api.html#lift) to expose a signal in a `tilia` object.

```typescript
import { signal } from "tilia";

// Today's date, owned by whoever advances it. The clock keeps the setter; the
// deck receives the signal and can only read it — through `today.value`,
// inside its computeds, so every `due` follows the date.
const [today, setToday] = signal("2026-07-15");

const deck = makeDeck(today);
setToday("2026-07-16"); // midnight: the queue reorders, nobody recounts
```

```rescript
open Tilia

// Today's date, owned by whoever advances it. The clock keeps the setter; the
// deck receives the signal and can only read it — through `today.value`,
// inside its computeds, so every `due` follows the date.
let (today, setToday) = signal("2026-07-15")

let deck = makeDeck(today)
setToday("2026-07-16") // midnight: the queue reorders, nobody recounts
```
