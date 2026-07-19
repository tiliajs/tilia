---
title: A clock you can set
slug: a-clock-you-can-set
sort: 6
refs: []
---

This chapter adds no scenario. It answers a question two chapters old: in [chapter 4](#values-that-follow), the suite said "When midnight comes" — and midnight came, on command, in milliseconds. Nobody waited. How?

### Opening the steps file

Between the scenarios and the code sits one small file Adèle wrote: the *steps* file. It is where the drawing's words meet the build — each Given, When and Then bound to a few lines of code. Here is its heart:

```typescript
import { Given, type Context } from "@epure/vitest";
import { tilia } from "tilia";
import { makeDeck } from "../src/features/deck";
import { memoryRepo } from "./memoryRepo";

Given("a deck of cards", ({ When, Then }: Context, table: string[][]) => {
  const clock = tilia({ today: "2026-07-15" });
  const deck = makeDeck(memoryRepo(toCards(table)), clock);

  When("midnight comes", () => {
    clock.today = addDays(clock.today, 1);
  });

  When("Alice passes {string}", (front: string) => {
    deck.review(byFront(deck, front).id, "Pass");
  });

  Then("the queue is {string}", (expected: string) => {
    expect(deck.queue.map((c) => c.front).join(", ")).toBe(expected);
  });
});
```

```rescript
open VitestBdd

given("a deck of cards", ({step}, table) => {
  let clock = Tilia.tilia({today: "2026-07-15"})
  let deck = Deck.make(MemoryRepo.make(toCards(table)), clock)

  step("midnight comes", () => clock.today = addDays(clock.today, 1))

  step("Alice passes {string}", front =>
    deck.review(byFront(deck, front).id, Pass)
  )

  step("the queue is {string}", expected =>
    expect(deck.queue->Array.map(c => c.front)->Array.join(", "))->toBe(expected)
  )
})
```

Read the first two lines inside `Given`. The steps file *builds a world* — a repo that lives in memory, a clock that is just a tilia object — and hands it to the feature. Then "midnight comes" is one write: `clock.today` moves, `due` values follow ([chapter 4](#values-that-follow) at work), and the queue reorders. Midnight is not simulated. For this deck, whose only sense of time is the clock it was handed, midnight genuinely happens.

### Asking, not reaching

None of this would be possible if the deck had reached for the world — imported a storage module, called `Date.now()`. It never does. Features and repos *ask* for the world and receive it injected, as arguments:

```typescript
// the app, for Alice
const deck = makeDeck(indexedDbRepo(), wallClock());

// the same app, for a scenario
const deck = makeDeck(memoryRepo(cards), tilia({ today: "2026-07-15" }));
```

```rescript
// the app, for Alice
let deck = Deck.make(IndexedDbRepo.make(), WallClock.make())

// the same app, for a scenario
let deck = Deck.make(MemoryRepo.make(cards), Tilia.tilia({today: "2026-07-15"}))
```

Same feature, same code, two worlds. The connectors — real storage, the real clock, the network someday — live in `services/`, and they are the *only* place the outside world is touched. This is dependency injection, and in this architecture it is not a testing technique bolted on afterward: it is one of the most important structural decisions in the whole design, the reason a feature is a complete, self-contained unit of meaning.

### What it buys

Everything this guide has been enjoying quietly:

- **The suite is fast** — no database to start, no clock to wait for. Alice's scenarios run in milliseconds, so they run constantly, so green stays current.
- **Green is trustworthy** — every scenario runs on a world under total control, so a red line means the behavior changed, never that the network hiccuped.
- **Claudine builds alone** — no credentials, no test server, no "works on my machine." The world she needs is constructed in the first line of the steps file.
- **The feature is enumerates its needs** — `makeDeck(repo, clock)` is a complete list of what the deck touches. Nothing hides in an import.

::: story
Adèle explains the trick to Alice, who thinks about it and asks the right question: "So you can make it any day you want?" — "Any day we want." — "Then test a Sunday. The café cards. I only ever get those wrong on Sundays."
:::

A clock you can set, a repo in memory: the world so far is one the deck politely asked for. But some of the world is not asked for — it *arrives*: saved cards loading from storage, a session moving through its states. Letting that world in, without losing any of the calm, is next.
