---
title: Onward
slug: onward
sort: 8
refs: [make, store-make, tilia-query-type, claim-type, reason-type, retry, discard, indexeddb-make]
chapter: "08"
---

Step back and look at what Alice's app is made of now. Components read `cards.array({deck: "spanish"})`; actions write through `store.upsert(card)`; recovery reads `store.status` and chooses `retry` or `discard`. Nothing in the feature code mentions tunnels, buses, outboxes, or Spain. One `[cards, store]` pair, a `Store.make` backend, IndexedDB persistence, and `cards.tick()` on the app's own clock carry the entire trip — and the mental model compresses well:

- **Reads grow in strength.** `partial`, `local`, and `fresh` distinguish a useful fragment, a complete memory, and an answer authoritative now.
- **Nothing has a reason.** `offline`, `failed`, and `noMatch` lead to different humane interfaces; none asks the app to infer meaning from absence.
- **A mutation accepted is a mutation kept.** It is applied optimistically, queued in order, persisted across restarts, and retried after reconnect without allowing later work to overtake it.
- **The server is the meeting point.** Devices remember independently and meet through ordinary refresh and reconnect; no cache pretends to be the owner.
- **Disagreement is data.** Base, yours, theirs: merge what merges, and hold the rest for an explicit retry, discard, or human resolution, with no version silently lost.

None of these required @tilia/query. They required *deciding* that a spinner in front of cached data is a small unkindness, that an edit accepted is a promise, that a conflict is two people caring about the same thing. The library is one careful implementation of those decisions; the decisions travel to any stack. If you build this lifecycle yourself, build it to these rules — your users will not know the words, but they will feel the difference on every train.

### Kept honest

Behavior like "a mutation made offline survives a restart" is exactly the kind of claim that rots in prose. In the épure toolset it doesn't stay prose — the engine's behavior is pinned by an executable specification, scenarios first, in the shape [vitest-bdd](https://vitest-bdd.dev) runs:

```gherkin
Scenario: A mutation made offline survives a restart
  Given the phone is offline
  When Alice saves the card "gato"
  And the application restarts
  Then the store has 1 pending operation
  And the query includes "gato" in the "spanish" deck
```

Specification-first is how the offline promises stay promises while the implementation moves.

### Where to go from here

The [@tilia/query API reference](./api.html) documents the public surface with TypeScript and ReScript signatures. It is the place to look up a precise outcome or type after this guide has given it a purpose.

The reactivity underneath — why reading is subscribing, why identity means no wasted repaints — is the [tilia guide](../guide.html), and its complete surface is in the [tilia API reference](../api.html). This guide leaned on it in every chapter. Both libraries are open source at [github.com/tiliajs](https://github.com/tiliajs), and the method they serve — software drawn before it is built — is the [épure](https://epuremethod.com) project.

::: story
The train home. Tunnels again — Alice doesn't look up. Somewhere under her thumbs a queue is holding her words like sap through winter, and she has no idea, and that is the highest compliment an architecture ever gets.
:::
