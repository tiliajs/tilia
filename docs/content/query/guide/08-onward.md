---
title: Onward
slug: onward
sort: 8
refs: [clear, dispose]
---

Step back and look at what Alice's cards travel through now. A query is a question asked once and kept fresh. An edit is durable before it is optimistic, and optimistic before it is sent. The server's disagreements arrive as named outcomes, not exceptions. Adapters translate; channels absorb late answers; a tick the app controls decides when anything happens at all. Nowhere in the feature code is there a retry loop, a merge function, or an `isLoading` flag someone forgot to reset.

The mental model compresses well:

- **Two caches, no copies.** Objects live once, by id; queries hold id lists. An update lands everywhere because there is only one everywhere.
- **Reads answer twice.** Local answers now, remote answers with authority — writing through what arrived and pruning what fell out. Unchanged answers change nothing.
- **Writes are held sap.** Durable, then optimistic, then dispatched — latest per id wins, and reconnect or restart replays through the same flow.
- **Disagreement is vocabulary.** `offline` retries, `conflict` resolves, `rejected` surfaces and converges; `changed` and `removed` let inbound truth in — and keep it — without an echo.
- **The boundary is channels.** Adapters own transport and storage; cancellation makes their late answers harmless.
- **Time is external.** `tick()` refreshes the live and evicts the idle, and liveness is read from the observer graph, not counted by hand.

### Endings: clear and dispose

Two exits, for two different reasons. `clear()` is for logout or user switch: it empties the memory caches and the outbox so the next user starts blank. It deliberately does *not* wipe the local database — the library never learned your storage, so erasing it is the adapter's job, done with the same code that owns the schema. Forgetting this pairing is a privacy bug: call your store's own wipe alongside `clear()`.

`dispose()` is for tearing down an instance — end of a test, unmount of an app shell. It stops the connectivity watcher and cancels every open channel; the instance stays readable but inert. Nothing will replay, fetch, or settle again.

### Where to go from here

The [API reference](api.html) is the flat, complete surface — every function and type with signatures in both TypeScript and ReScript. This guide chose the readable rule; the reference has the precise one.

Everything here runs on tilia reactivity: views, `status`, the reconnect watcher are ordinary reactive values. If any of that felt like magic, [the tilia guide](docs.html) is the missing floor — this guide is its promised sequel, the "synchronizing collections with a server" its last chapter deferred.

And the behaviors this guide narrated — the tunnel edits, the restart replay, the resurrection of a rejected delete — exist as a Gherkin specification that runs against the implementation under [vitest-bdd](https://www.npmjs.com/package/vitest-bdd). Specification first, in plain language, kept true by the test runner: the [épure](https://epuremethod.com) method, applied to the library that carries its data.

::: story
The train comes out of the third tunnel and Alice's phone syncs three reviews without telling her. On her laptop tonight, *gato* will already be scheduled for next week. She never once thought about the server — which was the point all along.
:::
