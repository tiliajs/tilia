---
title: Carving a feature
slug: carving-a-feature
sort: 4
refs: [carve, computed]
---

A feature is more than a bag of values. Alice's deck has state (the cards), derived state (which cards are due, in what order), and actions (record a review). These belong together, speak the same domain language, and should be testable as a unit. `carve` is tilia's way of building exactly that — and it is where tilia truly shines.

### Logic as pure functions

Start by writing the logic with no library in sight. A queue is a function of a deck. A review is a function of a deck, applied to a card:

```typescript
const queue = (deck: Deck) =>
  deck.cards
    .filter((c) => c.dueDate <= clock.today)
    .sort((a, b) => (a.dueDate < b.dueDate ? -1 : 1));

const review = (deck: Deck) => (id: string, result: Result) => {
  const card = deck.cards.find((c) => c.id === id);
  if (!card) return;
  card.interval = result === "Pass" ? card.interval * 2 : 1;
  card.lastReview = clock.today;
  deck.repo.save(card);
};
```

```rescript
let queue = deck =>
  deck.cards
  ->Array.filter(c => c.dueDate <= clock.today)
  ->Array.toSorted((a, b) => String.compare(a.dueDate, b.dueDate))

let review = deck => (id, result) =>
  switch deck.cards->Array.find(c => c.id === id) {
  | None => ()
  | Some(card) =>
    card.interval = result === Pass ? card.interval * 2 : 1
    card.lastReview = clock.today
    deck.repo.save(card)
  }
```

These are ordinary functions. You can test `queue` with a plain object and an assertion — no mocking of a reactive system, because they do not know one exists.

### Assembling the feature

`carve` builds the reactive object and hands your functions the object itself, through `derived`:

```typescript
import { carve } from "tilia";

const makeDeck = (repo: Repo) =>
  carve<Deck>(({ derived }) => ({
    // state
    cards: [],
    // computed state
    queue: derived(queue),
    // actions
    review: derived(review),
    // injected service
    repo,
  }));
```

```rescript
open Tilia

let makeDeck = repo =>
  carve(({derived}) => {
    // state
    cards: [],
    // computed state
    queue: derived(queue),
    // actions
    review: derived(review),
    // injected service
    repo: repo,
  })
```

::: story
The shoebox becomes a deck. Alice flips the first due card, taps *Pass*, and *gato* schedules itself further out. The queue reorders on its own.
:::

`derived(queue)` means: call `queue` with the carved object, track what it reads, and keep the result current. When `review` doubles a card's interval, that card's `dueDate` moves, the queue's dependencies fire, and `deck.queue` is fresh at the next read. The feature's whole behavior was declared in its shape — the wiring between state, derivation and action is tilia's problem, not yours.

Note the last field: `repo` is injected. The deck knows *that* cards are saved, not *how*. Swap in an in-memory repo and the entire feature runs in a test.

### derived or computed?

Both create values that follow. The distinction is scope:

- Use `computed` for a value that does **not** need the whole object — it closes over whatever it depends on, as `card.due` did in the [previous chapter](#values-that-follow).
- Use `derived` (inside `carve`) when the logic needs the carved object itself — cross-property values like `queue`, or actions like `review` that read and write siblings.

::: pro
Carving is a powerful way to build domain-driven, self-contained features. Extracting the logic into pure functions makes testing and reuse easy — the carved object is just the shape that brings them to life.
:::

For recursive derivation — state that both derives from the object and updates itself over time, like a state machine — combine `carve` with `source`, which is precisely where we go next. The deck's `cards: []` is a placeholder too: real cards live in storage, and letting the outside world in is the next chapter's subject.
