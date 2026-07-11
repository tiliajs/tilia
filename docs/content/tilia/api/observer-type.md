---
name: Observer
slug: observer-type
kind: type
module: core
since: "1.0"
sort: 200
summary: Opaque observer handle used by low-level observer lifecycle helpers.
signature:
  ts: "type Observer = { readonly [o]: true }"
  res: "type observer"
tags: []
---

`Observer`/`observer` is an opaque handle representing a registered observer.

Application code using public APIs normally does not create or consume this type directly. It appears in low-level lifecycle helpers (`_observe`, `_done`, `_ready`, `_clear`).

For ordinary reactive effects, use [observe](api.html#observe) or [watch](api.html#watch).

```typescript
import type { Observer } from "tilia";

const list: Observer[] = [];
void list;
```

```rescript
open Tilia

let list: array<observer> = []
ignore(list)
```
