---
title: Letting the world in
slug: letting-the-world-in
sort: 5
refs: [source, store]
---

Everything so far was synchronous and self-contained. Real applications load data, wait for servers, and move through states over time. tilia's answer is two primitives that put external and asynchronous values *inside* the reactive object, where the rest of the system can treat them like any other value: `source` and `store`.

### source: a value fed from outside

A `source` is like a computed, but instead of returning a value, its setup function receives a **setter** and calls it — now, later, or repeatedly. It also receives the **previous value**, and it starts from an **initial value** used before the first set.

The setup runs on first read of the key, and again whenever a reactive value it read synchronously has changed. That re-run rule is what turns a plain loader into a *reactive* loader. The deck can load its cards from the repo, and reload them whenever Alice picks another deck:

```typescript
import { carve, source } from "tilia";

const loader =
  (repo: Repo) =>
  (deck: Deck) =>
  (_previous: Card[], set: (cards: Card[]) => void) => {
    // 1. Synchronous read (tracked)
    const id = deck.deckId;
    // 2. Delegate async work
    repo.fetchCards(id).then(set);
  };

const makeDeck = (repo: Repo) =>
  carve<Deck>(({ derived }) => ({
    // state
    deckId: "spanish",
    cards: source([], derived(loader(repo))),
    // computed state
    queue: derived(queue),
    // actions
    review: derived(review),
    selectDeck: derived((deck) => (id: string) => (deck.deckId = id)),
  }));
```

```rescript
let loader = repo => deck => (_previous, set) => {
  // 1. Synchronous read (tracked)
  let id = deck.deckId
  // 2. Delegate async work
  repo.fetchCards(id)->Promise.thenResolve(set)->ignore
}

let makeDeck = repo =>
  carve(({derived}) => {
    // state
    deckId: "spanish",
    cards: source([], derived(loader(repo))),
    // computed state
    queue: derived(queue),
    // actions
    review: derived(review),
    selectDeck: derived(deck => id => deck.deckId = id),
  })
```

::: story
Alice taps *French* on a whim. The deck notices its own `deckId` change, fetches the right cards, and the queue follows. She taps back to *Spanish* before dinner.
:::

Follow what replaced what. Without this, selecting a deck means: call the fetch, guard against races, store the result, invalidate the queue, notify the views. Here, `selectDeck` writes one field. The loader re-runs because it read that field; everything downstream follows because it always does. The previous cards stay visible until `set` delivers the new ones — the UI can show them as stale instead of blinking to empty.

::: pro
Make sure the `source` callback **is not async**. tilia tracks reactive reads during synchronous execution only — read your dependencies first, then delegate the async work, as `loader` does.
:::

::: pro
To represent "still loading", use an empty tilia object as a sentinel initial value and test with `===` identity. That distinguishes "loading" from "loaded but empty" without inventing a status field.
:::

### store: a value that manages itself

Where `source` feeds a value from outside, [`store`](api.html) hands the setter *to the value itself*. The setup function receives `set` and returns the initial value; whatever it builds can capture `set` and decide its own future. This is the natural shape for state machines.

Alice's review session is one: idle, reviewing, finished — and each state only offers the transitions that make sense from there:

```typescript
import { tilia, store, type Setter } from "tilia";

const idle = (set: Setter<Session>): Session => ({
  t: "Idle",
  start: () => set(reviewing(set)),
});

const reviewing = (set: Setter<Session>): Session => ({
  t: "Reviewing",
  finish: () => set(finished(set)),
});

const finished = (set: Setter<Session>): Session => ({
  t: "Finished",
  restart: () => set(idle(set)),
});

const app = tilia({
  session: store(idle),
});
```

```rescript
open Tilia

let rec idle = set => Idle({start: () => set(reviewing(set))})
and reviewing = set => Reviewing({finish: () => set(finished(set))})
and finished = set => Finished({restart: () => set(idle(set))})

let app = tilia({
  session: store(idle),
})
```

Illegal transitions are not rejected at runtime — they are unrepresentable. `app.session` in the `Idle` state has a `start` and nothing else. The type system and the reactive system are telling the same story, which is the point of drawing the shape first.

::: pro
`store` makes it easy to initialize a feature in a specific state — hand it `reviewing` instead of `idle` and a test starts mid-session, no clicking through.
:::

Like `source`, a store's setup re-runs when a reactive value it read has changed, so a machine can also rebuild itself from its surroundings. And inside `carve`, `source(initialValue, derived(...))` gives a machine access to the whole feature — the recursive derivation mentioned in the [previous chapter](#carving-a-feature).

The deck now lives, loads, and runs sessions. Before composing larger applications, it is worth meeting four small words that round out the vocabulary.
