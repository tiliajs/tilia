---
name: watch
slug: watch
kind: function
module: core
since: "2.1"
sort: 40
summary: React to captured values with an untracked effect phase.
tags: []
signature.ts: "function watch<T>(fn: () => T, effect: (v: T) => void): () => void"
signature.res: "let watch: (unit => 'a, 'a => unit) => unit => unit"
label: watch(fn)
---

`watch` separates reactive work into two phases: `fn` captures dependencies and returns a value, and `effect` receives that value when the captured dependencies change.

A watch never retriggers itself through its own writes, whether they occur during capture or effect. The effect runs untracked, and notifications to other observers from its writes are deferred and flushed as a single batch. On initial registration, `fn` runs once to install dependencies, but `effect` is not called. `watch` returns a function that stops the watch; once called, neither phase runs again.

Use [observe](api.html#observe) when you need a single tracked callback. See the guide chapter [While Alice sleeps](guide.html#while-alice-sleeps).

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
