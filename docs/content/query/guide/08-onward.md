---
title: Onward
slug: onward
sort: 8
refs: [tilia-query-type, make]
---

Step back and look at what Alice's app is made of now. The components still read `cards.array({deck: "spanish"})` and render what comes back. The review action still writes a card. Nothing in the feature code mentions tunnels, buses, outboxes, or Spain. One `make()` call, two small adaptors, and a `tick()` on the app's own clock carry the entire trip — and the mental model compresses well:

- **Reads answer twice.** The device answers now, the network confirms later, and `fresh` says which answer you are looking at.
- **Offline is a state, not an error.** Every loadable state is a complete sentence; `NotLocal` is an answer, not an apology.
- **A mutation accepted is a mutation kept.** Applied to memory and disk immediately, queued in order, pushed at reconnection, safe across restarts — and never garbage-collected while unsent.
- **The server is the meeting point.** Devices are just places where the data is remembered; changing hands costs nothing because no cache pretends to be the owner.
- **Disagreement is data.** Base, yours, theirs: merge what merges, and hold the rest — verbatim — for a human, with no version silently lost.

None of these required @tilia/query. They required *deciding* that a spinner in front of cached data is a small unkindness, that an edit accepted is a promise, that a conflict is two people caring about the same thing. The library is one careful implementation of those decisions; the decisions travel to any stack. If you build this lifecycle yourself, build it to these rules — your users will not know the words, but they will feel the difference on every train.

### Kept honest

Behavior like "a mutation made offline survives a restart" is exactly the kind of claim that rots in prose. In the épure toolset it doesn't stay prose — the engine's behavior is pinned by an executable specification, scenarios first, in the shape [vitest-bdd](https://vitest-bdd.dev) runs:

```gherkin
Scenario: A mutation made offline survives a restart
  Given the remote is offline
  When Alice upserts the card "gato"
  And the application restarts
  Then 1 operation is pending
  And the card "gato" is in the "spanish" deck
```

Specification-first is how the offline promises stay promises while the implementation moves.

### Where to go from here

The [@tilia/query API reference](./api.html) documents the complete public surface — every function and type with its signature in both TypeScript and ReScript. It is the place for the precise rule wherever this guide chose the readable one.

The reactivity underneath — why reading is subscribing, why identity means no wasted repaints — is the [tilia guide](../guide.html), and its complete surface is in the [tilia API reference](../api.html). This guide leaned on it in every chapter. Both libraries are open source at [github.com/tiliajs](https://github.com/tiliajs), and the method they serve — software drawn before it is built — is the [épure](https://epuremethod.com) project.

::: story
The train home. Tunnels again — Alice doesn't look up. Somewhere under her thumbs a queue is holding her words like sap through winter, and she has no idea, and that is the highest compliment an architecture ever gets.
:::
