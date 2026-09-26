---
name: lift
slug: lift
kind: function
module: core
since: "3.0"
sort: 110
summary: Lift a signal into a computed value for object insertion.
tags: []
signature.ts: "function lift<T>(s: Signal<T>): T"
signature.res: "let lift: signal<'a> => 'a"
label: lift(s)
---

`lift` converts a signal into an inserted computed value by tracking `s.value`.

It is equivalent to `computed(() => s.value)`. Use it when an object should expose a signal as a read-only field while retaining mutation through the signal setter.

See [signal](api.html#signal), [computed](api.html#computed), and the guide chapter [A small vocabulary](guide.html#a-small-vocabulary).

```typescript
import { lift, signal, tilia } from "tilia";

// Alice's streak. The review logic keeps `setStreak`; `stats` exposes the
// value as a field anyone can read and nobody else can write.
const [streak, setStreak] = signal(0);

const stats = tilia({
  streak: lift(streak),
  best: 0,
});

const pass = () => {
  setStreak(streak.value + 1);
  if (stats.streak > stats.best) stats.best = stats.streak;
};
```

```rescript
open Tilia

// Alice's streak. The review logic keeps `setStreak`; `stats` exposes the
// value as a field anyone can read and nobody else can write.
let (streak, setStreak) = signal(0)

let stats = tilia({
  streak: lift(streak),
  best: 0,
})

let pass = () => {
  setStreak(streak.value + 1)
  if stats.streak > stats.best {
    stats.best = stats.streak
  }
}
```
