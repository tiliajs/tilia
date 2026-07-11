---
title: Onward
slug: onward
sort: 10
refs: []
---

Step back and look at what Alice's scheduler is made of. A card is a plain object. A deck is a carved feature: state, derived queue, review action, injected repo. The session is a state machine that only offers legal moves. The clock is a reactive value like any other. The views are functions that read the domain and repaint exactly when their answer changes. Nowhere in it is there a store, a reducer, an action type, or a subscription list.

That is the mental model this guide set out to build, and it compresses well:

- **Objects live.** `tilia` makes a plain object reactive without changing its shape; separate objects share one forest.
- **Values follow.** `computed` and `derived` keep declared relationships true — pull, cached, nearly free to read.
- **The world flows in.** `source` and `store` place external, asynchronous and self-managing values inside the same objects, under the same rules.
- **Time is coherent.** Writes notify immediately, except inside reactive callbacks and batches; `watch` separates cause from effect.
- **Mistakes stay small.** Orphan computations fail loudly at the source; a throwing observer is cleared, reported, and quarantined.

The deeper habit the library rewards is the one named in the first chapter: draw the shape first. Decide what the values are and how they relate, write the relationships as pure functions, and let the reactive system carry the declaration into the running program. tilia is small because that is all it does — and most of what state management frameworks manage simply never comes into existence.

### Where to go from here

The [API reference](api.html) documents the complete public surface — every function with its signature in both TypeScript and ReScript and a minimal example. It is the place to check the precise rule wherever this guide chose the readable one.

The scheduler's repo was injected and politely ignored; synchronizing collections with a server — loading, caching, going offline and coming back — is its own discipline. **tilia/query** builds that lifecycle on the reactivity you now understand: see [its page](query.html).

Testing was a promise this guide made often: pure functions and injected services are what make features checkable in plain language. **vitest-bdd** is the épure suite's tool for exactly that — specifications first, in Gherkin, runnable under [vitest-bdd](https://www.npmjs.com/package/vitest-bdd).

tilia itself is open source, at [github.com/tiliajs/tilia](https://github.com/tiliajs/tilia). And the method these tools serve — software drawn before it is built — is the [épure](https://epuremethod.com) project; tilia is its way of making sure the drawing and the program never drift apart.

::: story
Alice knows none of this. She flips a card, the box learns, and tomorrow asks better questions. Which was the point all along.
:::
