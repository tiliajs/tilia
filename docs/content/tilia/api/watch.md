---
name: watch
slug: watch
kind: function
module: core
since: "2.1"
sort: 40
summary: React to captured values with an untracked effect phase.
signature:
  ts: "function watch<T>(fn: () => T, effect: (v: T) => void): () => void"
  res: "let watch: (unit => 'a, 'a => unit) => unit => unit"
tags: []
---

`watch` separates reactive work into two phases: `fn` captures dependencies and returns a value; `effect` receives that value when captured dependencies change.

A watch never re-triggers itself from its own writes, in capture or effect; the effect runs untracked, and its writes notify other observers deferred, as one batch. On initial registration, `fn` runs once to install dependencies and `effect` is not called. `watch` returns a function that stops the watch: once called, neither phase runs again.

Use [observe](api.html#observe) when a single tracked callback is needed. See guide chapter [While Alice sleeps](guide.html#while-alice-sleeps).

```typescript
import { signal, watch } from "tilia";

const [score, setScore] = signal(0);
const [result, setResult] = signal("pending");

watch(
  () => result.value,
  (value) => {
    if (value === "pass") setScore(score.value + 1);
  }
);

setResult("pass");
```

```rescript
open Tilia

let (score, setScore) = signal(0)
let (result, setResult) = signal("pending")

watch(
  () => result.value,
  value => {
    if value === "pass" {
      setScore(score.value + 1)
    }
  },
)

setResult("pass")
```
