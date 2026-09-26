---
name: source
slug: source
kind: function
module: core
since: "2.0"
sort: 70
summary: Define an inserted value managed by previous-plus-set setup logic.
tags: []
signature.ts: "function source<T>(initVal: T, fn: (previous: T, set: Setter<T>)
  => unknown): T"
signature.res: "let source: ('a, ('a, 'a => unit) => 'ignored) => 'a"
label: source(initVal, fn, set)
---

`source` creates a dynamic value for insertion into a reactive object. It starts with `initialValue`, then executes `fn(previous, set)` on the first read and whenever tracked dependencies in `fn` change.

`previous` is the latest value held by the source, and `set` updates it. If `fn` does asynchronous work, dependencies must still be read synchronously before awaiting; only synchronous reads are tracked.

If dependencies change, the current value remains available until `set` is called again. In the example below, the previous cards remain visible while the new deck loads. See [store](api.html#store), [carve](api.html#carve), and the guide chapter [Letting the world in](guide.html#letting-the-world-in).

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

**Loading sentinel**

When an empty result is valid, use a stable, empty `tilia` value to distinguish the initial loading state without changing the value's type. Compare by identity:

```typescript
const loading = tilia<Card[]>([]);

const app = tilia({
  cards: source(loading, (_previous, set) => {
    fetchCards("spanish").then(set);
  }),
});

if (app.cards === loading) {
  // No result has arrived yet.
}
```

```rescript
let loading = tilia([])

let app = tilia({
  cards: source(loading, (_previous, set) => {
    fetchCards("spanish")->Promise.thenResolve(set)->ignore
  }),
})

if app.cards === loading {
  // No result has arrived yet.
}
```

The sentinel marks only the initial load. When a dependency changes, `source` keeps its previous value until the next call to `set`. Call `set(loading)` synchronously if a reload should return to the loading state.
