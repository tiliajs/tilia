---
title: Drawn before built
slug: drawn-before-built
sort: 1
refs: []
---

This chapter is for the person deciding whether tilia belongs in their stack. There is no code in it.

tilia is a state management library for TypeScript and ReScript applications. Its goal is deliberately narrow: provide a minimal, fast reactive layer that supports domain-oriented development — Clean Architecture, Diagonal Architecture, or any style where the business domain leads. tilia is not a framework, and that is a design decision, not a limitation.

### The shape comes first

Most state libraries ask your team to describe *how* data changes: actions, reducers, dispatch, selectors. The domain ends up encoded in library vocabulary, and every reader must translate back to the business to understand what the code does.

tilia inverts this. You draw the shape of your state as plain objects — a card, a deck, a review session — and declare how each value relates to the others. The library's job is to keep the running program true to that declaration: when something changes, everything that depends on it follows, automatically and precisely. Your code looks and behaves like business logic, because it is business logic.

The result is that entire applications can be built from **pure functions** and **lean views**. The logic lives in ordinary functions that take data and return data — easy to read, easy to test in isolation, easy to hand to a new team member or an AI assistant. The glue that makes it all alive is tilia's, and it stays out of the way.

### How applications are structured

The recommended structure separates an application into three categories:

- **repo** — the persistence layer, one self-contained object per data type that is saved.
- **features** — the business logic, one self-contained object per feature.
- **services** — technical connectors to the outside world (translations, audio, database wrappers), written in a `service` file and injected into the feature or repo that needs them.

Each feature is a bounded piece of the domain: its state, its derived values, and its actions live together, and its external dependencies arrive by injection. This maps directly onto Domain-Driven Design practice — a ubiquitous language in the code, bounded contexts as modules, rich models that keep logic next to the data it operates on, and domain logic testable in isolation. Teams onboard faster because the code reads in the language of the business, not the language of a state library.

### What it costs

Very little, by design. tilia has zero dependencies and weighs around 10&nbsp;KB. It is optimized for stability and speed: reactivity is highly granular (a view re-renders only when a value it actually read has changed), computed values are cached until a dependency changes, and tracking follows objects even when they are moved or copied. It combines **push** reactivity (react when something changes) and **pull** reactivity (compute only when someone asks), so work happens exactly when it is needed and not before. The same API serves TypeScript and ReScript.

### How this guide works

The rest of the guide builds one small, believable thing: a spaced-repetition scheduler — flashcards that come back for review at growing intervals. Alice, whom readers of the [API reference](api.html) already know, is learning Spanish with it.

::: story
Alice has a shoebox of Spanish flashcards. Some she knows cold, some she keeps forgetting. The box is about to become software.
:::

Each chapter introduces one idea because the scheduler needs it, and each chapter ends knowing why tilia works that way. A reader moving front to back builds one coherent mental model; the [final chapter](#onward) steps back and points onward. If you decide for your team, this chapter and that one may be all you need. The chapters between are for whoever will build — human or machine, the mental model is the same.
