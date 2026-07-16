---
name: computed
slug: computed
kind: function
module: core
since: "2.0"
sort: 60
summary: Define a pull-based cached value for insertion into reactive objects.
signature:
  ts: "function computed<T>(fn: () => T): T"
  res: "let computed: (unit => 'a) => 'a"
tags: []
---

`computed` creates a dynamic value intended to be assigned directly in a `tilia`/`carve` object. The value is computed on read, cached, and invalidated when tracked dependencies change.

If no observer depends on the computed key, Tilia can clear its internal observer and keep the dynamic definition for later reads. Replacing or deleting the property removes the previous computed behavior.

Using a computed value outside insertion context raises an orphan-computation error. Define it directly where it is inserted. See [tilia](api.html#tilia), [carve](api.html#carve), and guide chapter [Values that follow](guide.html#values-that-follow).

```typescript
import { computed, tilia } from "tilia";

const alice = tilia({
  birthYear: 2015,
  nowYear: 2026,
  age: computed(() => alice.nowYear - alice.birthYear),
});

alice.nowYear = 2027;
alice.age;
```

```rescript
open Tilia

let alice = tilia({
  birthYear: 2015,
  nowYear: 2026,
  age: computed(() => alice.nowYear - alice.birthYear),
})

alice.nowYear = 2027
ignore(alice.age)
```
