---
name: Signal
slug: signal-type
kind: type
module: core
since: "2.0"
sort: 210
summary: Mutable single-value container used by signal-based APIs.
signature:
  ts: "type Signal<T> = { value: T }"
  res: "type signal<'a> = {mutable value: 'a}"
tags: []
---

`Signal<T>`/`signal<'a>` is the value container returned by [signal](api.html#signal) and [derived](api.html#derived).

Reads from `value` are trackable, and writes through setters update `value`.

See also [Setter](api.html#setter-type) and [lift](api.html#lift).

```typescript
import type { Signal } from "tilia";

const s: Signal<number> = { value: 0 };
s.value = 1;
```

```rescript
open Tilia

let s: signal<int> = {value: 0}
s.value = 1
```
