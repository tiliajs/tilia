---
name: observe
slug: observe
kind: function
module: core
since: "1.0"
sort: 30
summary: Run a tracked callback immediately and on dependency changes.
signature:
  ts: "function observe(fn: () => void): void"
  res: "let observe: (unit => unit) => unit"
tags: []
---

`observe` runs `fn` once immediately, tracks reactive reads during that run, and re-runs `fn` whenever one of those tracked keys changes. Dependency tracking is rebuilt on each run.

Writes performed inside `fn` are deferred while `fn` is running. If `fn` writes to keys it also tracks, it is scheduled to run again after the current run finishes. This makes `observe` suitable for state-machine style transitions.

`observe` has no return value. For two-phase capture/effect behavior, use [watch](api.html#watch). For pull reactivity, use [computed](api.html#computed). See guide chapters [A living object](docs.html#a-living-object) and [Time and consistency](docs.html#time-and-consistency).

```typescript
import { observe, tilia } from "tilia";

const alice = tilia({
  name: "Alice",
  username: "alice",
});

observe(() => {
  alice.username = alice.name.toLowerCase();
});
```

```rescript
open Tilia

let alice = tilia({
  name: "Alice",
  username: "alice",
})

observe(() => {
  alice.username = alice.name->String.toLowerCase
})
```
