---
name: signal
slug: signal
kind: function
module: core
since: "2.0"
sort: 90
summary: Create a single-value reactive signal and its setter.
signature:
  ts: "function signal<T>(value: T): [Signal<T>, Setter<T>]"
  res: "let signal: 'a => (signal<'a>, setter<'a>)"
tags: []
---

`signal` returns a pair: a reactive object `{ value }` and a setter function.

The signal object is a Tilia proxy, so reads of `.value` are tracked and writes through the setter notify dependents. It is a compact form for single mutable values.

Use [derived](api.html#derived) to build a computed signal and [lift](api.html#lift) to expose a signal in a `tilia` object.

```typescript
import { signal } from "tilia";

const [count, setCount] = signal(0);
setCount(1);
count.value;
```

```rescript
open Tilia

let (count, setCount) = signal(0)
setCount(1)
ignore(count.value)
```
