---
name: store
slug: store
kind: function
module: core
since: "2.0"
sort: 80
summary: Define an inserted managed value from a setup function with setter.
signature:
  ts: "function store<T>(fn: (set: Setter<T>) => T): T"
  res: "let store: (('a => unit) => 'a) => 'a"
tags: []
---

`store` creates a dynamic inserted value from `fn(set)`. The setup returns the current value and receives `set` to update it later.

The setup runs on first access and can re-run when tracked dependencies used during setup change. This is suitable for finite-state values where transitions call `set`.

Use [source](api.html#source) when setup needs the previous value. See guide chapter [Letting the world in](guide.html#letting-the-world-in).

```typescript
import { store, tilia } from "tilia";
import type { Setter } from "tilia";

type Session =
  | { t: "Idle"; start: () => void }
  | { t: "Running"; stop: () => void };

const idle = (set: Setter<Session>): Session => ({
  t: "Idle",
  start: () => set(running(set)),
});

const running = (set: Setter<Session>): Session => ({
  t: "Running",
  stop: () => set(idle(set)),
});

const app = tilia({ session: store(idle) });
```

```rescript
open Tilia

type session = Idle({start: unit => unit}) | Running({stop: unit => unit})

let rec idle = set => Idle({start: () => set(running(set))})
and running = set => Running({stop: () => set(idle(set))})

let app = tilia({session: store(idle)})
```
