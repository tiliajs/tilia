---
name: carve
slug: carve
kind: function
module: core
since: "2.0"
sort: 25
summary: Build a reactive object where fields can derive from the full object.
signature:
  ts: "function carve<T>(fn: (deriver: Deriver<T>) => T): T"
  res: "let carve: (deriver<'a> => 'a) => 'a"
tags: []
---

`carve` builds a proxied object from a factory function and provides a `deriver` argument with `derived(self => ...)`.

`derived` is evaluated with the carved object as input. This allows cross-field derivation and methods that depend on sibling fields. The returned object is then proxied like [tilia](api.html#tilia).

Use `carve` when derivation needs `self`; use [computed](api.html#computed) when a standalone closure is enough. See guide chapter [Carving a feature](docs.html#carving-a-feature).

```typescript
import { carve } from "tilia";

const counter = carve(({ derived }) => ({
  value: 1,
  double: derived((self) => self.value * 2),
}));
```

```rescript
open Tilia

let counter = carve(({derived}) => {
  value: 1,
  double: derived(self => self.value * 2),
})
```
