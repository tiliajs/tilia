---
title: Letting the world in
slug: letting-the-world-in
sort: 7
refs: [source, store, lift]
---

Everything so far was synchronous and self-contained. Real applications load data, wait for storage, and move through states over time. Two new wants make it concrete:

```gherkin
Scenario: cards survive a restart
  Given Alice passed "gato" yesterday
  When the app restarts
  Then "gato" still waits 2 days

Scenario: a session offers only legal moves
  Given an idle session
  Then Alice can start it, and nothing else
```

tilia's answer is two primitives that put external and asynchronous values *inside* the reactive object, where the rest of the system treats them like any other value: `source` and `store`.

### source: a value fed from outside

A [`source`](api.html#source) is like a computed, but instead of returning a value, its setup function receives a **setter** and calls it — now, later, or repeatedly. The setup runs on first read, and again whenever a reactive value it read synchronously has changed. That re-run rule turns a plain loader into a *reactive* loader:

```typescript
import { carve, lift, source, type Signal } from "tilia";

const loader =
  (deck: Deck) =>
  (_previous: Card[], set: (cards: Card[]) => void) => {
    const id = deck.deckId; // synchronous read: tracked
    deck.repo.fetchCards(id).then(set); // async work: delegated
  };

const makeDeck = (repo: Repo, today: Signal<string>) =>
  carve<Deck>(({ derived }) => ({
    deckId: "spanish",
    cards: source([], derived(loader)),
    queue: derived(queue),
    review: derived(review),
    selectDeck: derived((deck) => (id: string) => (deck.deckId = id)),
    repo,
    today: lift(today),
  }));
```

```rescript
let loader = deck => (_previous, set) => {
  let id = deck.deckId // synchronous read: tracked
  deck.repo.fetchCards(id)->Promise.thenResolve(set)->ignore // async: delegated
}

let makeDeck = (repo, today) =>
  carve(({derived}) => {
    deckId: "spanish",
    cards: source([], derived(loader)),
    queue: derived(queue),
    review: derived(review),
    selectDeck: derived(deck => id => deck.deckId = id),
    repo,
    today: today->lift,
  })
```

The cards now come from the injected repo — so *cards survive a restart* goes green against the in-memory repo, and works identically against real storage. And because the loader *read* `deck.deckId`, it re-runs when the deck changes:

::: story
Alice taps *French* on a whim. The deck notices its own `deckId` change, fetches the right cards, and the queue follows. She taps back to *Spanish* before dinner. Nobody wrote a refresh.
:::

Without this, selecting a deck means: call the fetch, guard against races, store the result, invalidate the queue, notify the views. Here, `selectDeck` writes one field and everything downstream follows.

::: pro
Keep the `source` callback synchronous: tilia tracks reads during synchronous execution only. Read your dependencies first, then delegate the async work, as `loader` does.
:::

::: pro
This loader reads from injected *local* storage. When the cards one day live on a server — with caching, refresh, offline — that whole lifecycle is [@tilia/query](query/index.html)'s job. The loader then gives way to a loadable list, read with `cards.array(...)`, while the surrounding feature keeps the same vocabulary.
:::

### store: a value that manages itself

Where `source` feeds a value from outside, [`store`](api.html#store) hands the setter *to the value itself*: the setup receives `set` and returns the initial value, and whatever it builds can capture `set` and decide its own future. This is the natural shape for state machines — like the review session, which Alice's scenario says must offer only legal moves:

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

Illegal transitions are not rejected at runtime — they are *unrepresentable*. `app.session` in the `Idle` state has a `start` and nothing else, which is what the scenario asserts.

::: pro
`store` also makes tests pleasant to start anywhere: hand it `reviewing` instead of `idle` and a scenario begins mid-session, no clicking through.
:::

The deck now lives, loads, switches, and runs sessions — three more green lines. Four small words remain in tilia's vocabulary, and their whole job is naming intentions.
