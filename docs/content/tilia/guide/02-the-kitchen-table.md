---
title: The kitchen table
slug: the-kitchen-table
sort: 2
refs: []
---

There is no tilia in this chapter either. There is the first artifact of the project — and the only person who can approve it writes no code.

::: story
Alice calls her cousin on a Sunday. "You build things. My shoebox is overflowing and I keep forgetting *perro*." Adèle laughs, and says yes. By the evening she has an empty directory and two small files in it.
:::

### Two small files

The first is `CONTRIBUTING.md`, copied from the [épure](https://epuremethod.com) project. It is addressed to everyone who will ever build here — humans and AI assistants alike — and it opens with three promises:

> 1. **The scenarios are the design.** Every want becomes a scenario — Given, When, Then, in the domain's own words — before it becomes code. The `.feature` files are the project's design contracts and its decision ledger.
> 2. **Everything else is scaffolding.** Sketches, prose designs, prompts: useful while a want is being turned into scenarios, gone once it has been.
> 3. **Green is the handshake.** A feature is done when its scenarios pass, and it stays done because they keep passing.

The second file is `AGENTS.md` — the file an AI assistant's tooling reads at the start of every session. It says one thing: read `CONTRIBUTING.md`.

Adèle also sketches the app — screens, arrows, a box labeled *the queue*. The sketch will not survive the week, and that is the second promise at work: it exists to become scenarios, not to be maintained.

### What Alice knows

At the kitchen table, Adèle asks Alice how the shoebox actually works. Alice does not describe software; she describes a habit.

"When I get a card right, I put it further back in the box — it should leave me alone for a while, then come back. Twice as long each time, more or less. And every morning, some cards are just… due. Nobody moves them. It's morning, so they're due."

Adèle types while Alice talks. What she types is not a program:

```gherkin
Feature: Spaced repetition

  Scenario: a passed card waits longer
    Given a card "gato" with interval 3 days
    When Alice passes "gato"
    Then "gato" waits 6 days

  Scenario: cards come due on their own
    Given a card "gato" reviewed 3 days ago with interval 3 days
    When midnight comes
    Then "gato" is due
```

She turns the laptop around. Alice reads it out loud, all the way through, and says: "that's exactly it."

The first artifact of the project is one the domain owner can read, correct, and sign. It is written in her words — *passes*, *waits*, *due*, *midnight* — and those words will appear in the code, in the tests, and in every conversation about the app, unchanged. This file is an épure in the old craft sense — the drawing made at full scale before anything is cut, the one every built piece is laid back onto to check the fit.

### Enter Claudine

Adèle opens a session with Claudine. There is no tour: Claudine's tooling has already read `AGENTS.md` and followed it to `CONTRIBUTING.md`; she reads the promises, then the `.feature` file. She has never seen this project — that is her permanent condition; every session, she is the newest member of the team. `CONTRIBUTING.md` is written for exactly this reader: it tells her where truth lives (the scenarios), what to ignore (everything else), and to read the installed reference of any library before using it, so that an unknown is a question to ask, never an API to guess.

Claudine runs the suite — the scenarios execute directly, under [épure's test runner](https://www.npmjs.com/package/@epure/vitest). Two scenarios, two failures.

::: story
Two red lines on Adèle's screen: the project's entire to-do list, written in Alice's words, checked by a machine.
:::

Red is not failure here: red is the distance between the drawing and the build, and it can only shrink. The next chapter closes the first gap: for a card to pass and wait longer, there must first be a card, and it must be alive.
