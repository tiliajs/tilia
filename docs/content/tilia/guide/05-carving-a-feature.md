---
title: Carving a feature
slug: carving-a-feature
sort: 5
refs: [carve, computed, lift]
---

Alice's whole shoebox arrives, and with it the first scenarios that talk about the deck as a thing: which cards line up, in what order, what happens when one is reviewed. Adèle writes them with a table — Alice's actual cards, straight from the box:

```gherkin
Feature: The deck

  Background:
    Given a deck of cards
      | front | back | interval | reviewed   |
      | gato  | cat  | 1        | yesterday  |
      | perro | dog  | 3        | 4 days ago |
      | luna  | moon | 8        | yesterday  |

  Scenario: due cards line up, oldest first
    Then the queue is "perro, gato"

  Scenario: a reviewed card leaves the queue
    When Alice passes "perro"
    Then the queue is "gato"
```

A feature is more than a bag of values: the deck has state (the cards), derived state (the queue), and actions (review). These belong together, speak the same language, and should be testable as a unit. [`carve`](api.html#carve) is tilia's way of building exactly that — and it is where tilia truly shines.

### Logic as pure functions

Claudine starts by writing the logic with no library in sight. A queue is a function of a deck. A review is a function of a deck, applied to a card:

```typescript
const queue = (deck: Deck) =>
  deck.cards
    .filter((c) => c.dueDate <= deck.today)
    .sort((a, b) => (a.dueDate < b.dueDate ? -1 : 1));

const review = (deck: Deck) => (id: string, result: Result) => {
  const card = deck.cards.find((c) => c.id === id);
  if (!card) return;
  card.interval = result === "Pass" ? card.interval * 2 : 1;
  card.lastReview = deck.today;
  deck.repo.save(card);
};
```

```rescript
let queue = deck =>
  deck.cards
  ->Array.filter(c => c.dueDate <= deck.today)
  ->Array.toSorted((a, b) => String.compare(a.dueDate, b.dueDate))

let review = deck => (id, result) =>
  switch deck.cards->Array.find(c => c.id === id) {
  | None => ()
  | Some(card) =>
    card.interval = result === Pass ? card.interval * 2 : 1
    card.lastReview = deck.today
    deck.repo.save(card)
  }
```

These are ordinary functions: data in, data out. You can test `queue` with a plain object and an assertion — no reactive system to mock, because they do not know one exists.

### Assembling the feature

`carve` builds the reactive object and hands the functions the object itself, through `derived`:

```typescript
import { carve, lift, type Signal } from "tilia";

const makeDeck = (repo: Repo, today: Signal<string>) =>
  carve<Deck>(({ derived }) => ({
    // state
    cards: [],
    // computed state
    queue: derived(queue),
    // actions
    review: derived(review),
    // injected dependencies
    repo,
    today: lift(today),
  }));
```

```rescript
open Tilia

let makeDeck = (repo, today) =>
  carve(({derived}) => {
    // state
    cards: [],
    // computed state
    queue: derived(queue),
    // actions
    review: derived(review),
    // injected dependencies
    repo,
    today: today->lift,
  })
```

`derived(queue)` means: call `queue` with the carved object, track what it reads, and keep the result current. When `review` doubles a card's interval, that card's `dueDate` moves, the queue's dependencies fire, and `deck.queue` is fresh at the next read. The feature's whole behavior was declared in its shape — the wiring between state, derivation and action is tilia's problem, not anyone's.

::: story
Adèle reads Claudine's diff before running anything. `queue`. `review`. `due`. She realizes she is not translating: the code is the kitchen-table conversation, typed. She signs it the way Alice signed the scenarios.
:::

That is the handoff working. A feature written in the domain's words can be reviewed by reading, extended by a newcomer, and explained to Alice with the screen turned around. Two more lines turn green.

A word on the distinction inside the carve: use `computed` for a value that stands alone — it closes over whatever it needs, as `card.due` did. Use `derived` when the logic needs the carved object itself: cross-property values like `queue`, actions like `review` that read and write siblings. And when a standalone value already lives in a signal, `lift` inserts its current value directly.

The last two fields of the deck are the quiet heroes: `repo` arrives directly as an *argument*, while `today` is lifted from the signal beside it. The deck knows *that* cards are saved and *that* the date advances — never how. Those two arguments are the subject of the next chapter, and the reason everything in this guide runs green in milliseconds.
