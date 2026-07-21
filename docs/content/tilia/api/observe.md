---
name: observe
slug: observe
kind: function
module: core
since: "1.0"
sort: 30
summary: Run a tracked callback immediately and on dependency changes.
signature:
  ts: "function observe(fn: () => void): () => void"
  res: "let observe: (unit => unit) => unit => unit"
tags: []
---

`observe` runs `fn` once immediately, tracks reactive reads during that run, and re-runs `fn` whenever one of those tracked keys changes. Dependency tracking is rebuilt on each run.

Writes performed inside `fn` are deferred while `fn` is running. If `fn` writes to keys it also tracks, it is scheduled to run again after the current run finishes. This makes `observe` suitable for state-machine style transitions.

`observe` returns a function that cancels the observation: once called, the callback never runs again. Ignore it for observers that should live as long as the context. For two-phase capture/effect behavior, use [watch](api.html#watch). For pull reactivity, use [computed](api.html#computed). See guide chapters [A living object](guide.html#a-living-object) and [While Alice sleeps](guide.html#while-alice-sleeps).

```typescript
import { observe, tilia } from "tilia";

const alice = tilia({
  name: "Alice",
  username: "alice",
});

const stop = observe(() => {
  alice.username = alice.name.toLowerCase();
});

alice.name = "Alba"; // ✨ username follows

stop();
alice.name = "Ada"; // 💤 username no longer follows
```

```rescript
open Tilia

let alice = tilia({
  name: "Alice",
  username: "alice",
})

let stop = observe(() => {
  alice.username = alice.name->String.toLowerCase
})

alice.name = "Alba" // ✨ username follows

stop()
alice.name = "Ada" // 💤 username no longer follows
```
