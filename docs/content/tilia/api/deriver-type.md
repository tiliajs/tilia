---
name: Deriver
slug: deriver-type
kind: type
module: core
since: "2.0"
sort: 240
summary: Helper object passed to carve for self-based derivation.
signature:
  ts: "type Deriver<U> = { derived: <T>(fn: (p: U) => T) => T }"
  res: "type deriver<'p> = {derived: 'a. ('p => 'a) => 'a}"
tags: []
---

`Deriver<U>`/`deriver<'p>` is the helper parameter type received by [carve](api.html#carve).

Its `derived` method binds the carved object as input for self-based derivations.

```typescript
import type { Deriver } from "tilia";

const build = (d: Deriver<{ value: number }>) => ({
  value: 1,
  double: d.derived((self) => self.value * 2),
});
void build;
```

```rescript
open Tilia

type counter = {value: int, double: int}

let build = (d: deriver<counter>) => {
  value: 1,
  double: d.derived(self => self.value * 2),
}
ignore(build)
```
