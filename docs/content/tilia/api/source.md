---
name: source
slug: source
kind: function
module: core
since: "2.0"
sort: 70
summary: Define an inserted value managed by previous-plus-set setup logic.
signature:
  ts: "function source<T>(initVal: T, fn: (previous: T, set: Setter<T>) => unknown): T"
  res: "let source: ('a, ('a, 'a => unit) => 'ignored) => 'a"
tags: []
---

`source` creates a dynamic value for insertion in a reactive object. It starts from `initialValue`, then executes `fn(previous, set)` on first read and whenever tracked dependencies in `fn` change.

`previous` is the latest value held by the source, and `set` updates it. If `fn` does asynchronous work, dependencies must still be read synchronously before awaiting; only synchronous reads are tracked.

If dependencies change, the current value stays available until `set` is called again — below, the previous cards stay visible while the new deck loads. See [store](api.html#store), [carve](api.html#carve), and guide chapter [Letting the world in](docs.html#letting-the-world-in).

```typescript
import { signal, source, tilia } from "tilia";

const [deckId, setDeckId] = signal("spanish");

const app = tilia({
  cards: source([], (_previous, set) => {
    const id = deckId.value; // synchronous read: tracked
    fetchCards(id).then(set);
  }),
});

setDeckId("french"); // setup re-runs, cards reload
```

```rescript
open Tilia

let (deckId, setDeckId) = signal("spanish")

let app = tilia({
  cards: source([], (_previous, set) => {
    let id = deckId.value // synchronous read: tracked
    fetchCards(id)->Promise.thenResolve(set)->ignore
  }),
})

setDeckId("french") // setup re-runs, cards reload
```
