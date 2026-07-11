---
name: Setter
slug: setter-type
kind: type
module: core
since: "2.0"
sort: 230
summary: Function type that assigns a new value of the same type.
signature:
  ts: "type Setter<T> = (v: T) => void"
  res: "type setter<'a> = 'a => unit"
tags: []
---

`Setter<T>`/`setter<'a>` is the callback shape used by [signal](api.html#signal), [source](api.html#source), and [store](api.html#store).

It accepts the next value and returns `void`/`unit`.

```typescript
import type { Setter } from "tilia";

const setCount: Setter<number> = (v) => {
  void v;
};
setCount(1);
```

```rescript
open Tilia

let setCount: setter<int> = v => ignore(v)
setCount(1)
```
