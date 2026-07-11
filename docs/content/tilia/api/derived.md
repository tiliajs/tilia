---
name: derived
slug: derived
kind: function
module: core
since: "2.1"
sort: 100
summary: Create a signal whose value is computed from reactive dependencies.
signature:
  ts: "function derived<T>(fn: () => T): Signal<T>"
  res: "let derived: (unit => 'a) => signal<'a>"
tags: []
---

`derived` computes a signal value from reactive reads in `fn`. The returned signal exposes the computed result at `.value`.

Internally, this is equivalent to creating a signal with a [computed](api.html#computed) value. Consumers track `signal.value` like any other signal.

Use [signal](api.html#signal) for manual writes, and [lift](api.html#lift) to insert a derived signal into objects.

```typescript
import { derived, signal } from "tilia";

const [a, setA] = signal(1);
const [b, setB] = signal(2);
const sum = derived(() => a.value + b.value);

setA(3);
setB(4);
sum.value;
```

```rescript
open Tilia

let (a, setA) = signal(1)
let (b, setB) = signal(2)
let sum = derived(() => a.value + b.value)

setA(3)
setB(4)
ignore(sum.value)
```
