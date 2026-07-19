---
title: Drawn before built
slug: drawn-before-built
sort: 1
refs: []
---

This chapter is for the person deciding whether tilia belongs in their stack. There is no code in it.

tilia is a state management library for TypeScript and ReScript applications. Its goal is deliberately narrow: provide a minimal, fast reactive layer that supports domain-oriented development — Clean Architecture, Diagonal Architecture, or any style where the business domain leads. tilia is not a framework, and that is a design decision, not a limitation.

### Joy, written as structure

Underneath the API sits a conviction: building software together — with colleagues, with a cousin, with an AI assistant — should stay a joy for as long as the software lives. Joy does not die by accident; it dies in specific, preventable ways. Each one is answered by a rule of the architecture:

- **Fear of change.** A feature is a bounded, carved thing: its state, its logic and its actions live together, and touching one feature ripples nowhere else.
- **The translation tax.** The domain's words survive into the running code. No reader converts "the queue" back into business meaning, because the code never left the business's language.
- **Glue work.** The wiring between state, derivation and action is the library's job. People write only things worth reading.
- **The world in the way.** Features ask for the world — clock, storage, network — and receive it injected. Every test runs on a world you control.
- **The onboarding wall.** A new mind — cousin, colleague, or AI — reads the shape and knows where everything lives.
- **Logic you can't hold.** Every rule of the domain is a pure function you can read, test, and hand over whole.

The rest of this guide is these six rules, shown rather than argued.

### The shape comes first

Most state libraries ask your team to describe *how* data changes: actions, reducers, dispatch, selectors. The domain ends up encoded in library vocabulary, and every reader must translate back to the business to understand what the code does.

tilia inverts this. You draw the shape of your state as plain objects — a card, a deck, a review session — and declare how each value relates to the others. The library's job is to keep the running program true to that declaration: when something changes, everything that depends on it follows, automatically and precisely. Your code looks and behaves like business logic, because it is business logic.

### How applications are structured

The recommended structure separates an application into a few categories:

- **features** — the business logic, one self-contained object per feature, holding its state, its derived values and its actions.
- **repo** — the persistence layer, one self-contained object per data type that is saved.
- **services** — technical connectors to the outside world (clock, storage, translations, audio), injected into the feature or repo that needs them.
- **views** — the face. Views read features and render; they hold no business logic.

Behavior itself is decided before it is built, in scenarios written in the domain's own words — executable specifications that the running program is checked against for the life of the project. This working method is called [épure](https://epuremethod.com), after the full-scale drawing a builder traces before cutting, and tilia is its state layer: the way of making sure the drawing and the program never drift apart.

### What it costs

Very little, by design. tilia has zero dependencies and weighs around 10&nbsp;KB. Reactivity is highly granular — a view re-renders only when a value it actually read has changed — computed values are cached until a dependency changes, and tracking follows objects even when they are moved or copied. It combines **push** reactivity (react when something changes) and **pull** reactivity (compute only when someone asks), so work happens exactly when it is needed and not before. The same API serves TypeScript and ReScript.

### How this guide works

The guide builds one small, believable thing: a spaced-repetition scheduler — flashcards that come back for review at growing intervals. And it builds it the way real software gets built now: by more than one mind.

::: story
Alice has a shoebox of Spanish flashcards. Some she knows cold, some she keeps forgetting. The box is about to become software — but not by Alice's hand. Her cousin Adèle will design it, and Adèle will build it with Claudine, an AI who has never seen the project, the library, or the shoebox.
:::

That cast is the tension of the whole guide. Software survives by being handed between minds — and every handoff is a place where meaning can be lost. Each chapter starts with something Alice wants, in her words; ends with that want alive and verified; and introduces the one idea that made the handoff safe. A reader moving front to back builds one coherent mental model; the [final chapter](#onward) steps back and points onward. If you decide for your team, this chapter and that one may be all you need. The chapters between are for whoever will build — human or machine, the mental model is the same.
