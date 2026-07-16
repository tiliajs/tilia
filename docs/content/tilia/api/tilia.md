---
name: tilia
slug: tilia
kind: function
module: core
since: "2.0"
sort: 20
summary: Wrap an object or array in a reactive proxy.
signature:
  ts: "function tilia<T>(branch: T): T"
  res: "let tilia: 'a => 'a"
tags: []
---

`tilia` converts a plain object or array into a proxy that tracks property reads and writes. The return value keeps the same shape and type as the input.

Nested plain objects and arrays are proxied lazily when read. Values with non-plain prototypes (for example class instances) are returned as-is. Calling `tilia` on a value that is not an object or array throws. Calling `tilia` on an already proxied value returns the same proxy.

Writing the same value (or the same underlying target object) does not notify observers. See also [observe](api.html#observe), [computed](api.html#computed), and guide chapter [A Living Object](guide.html#a-living-object).

```typescript
import { tilia } from "tilia";

const alice = tilia({
  name: "Alice",
  age: 10,
});

alice.age = 11;
```

```rescript
open Tilia

let alice = tilia({
  name: "Alice",
  age: 10,
})

alice.age = 11
```
