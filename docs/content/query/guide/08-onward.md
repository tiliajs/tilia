---
title: Onward
slug: onward
sort: 8
refs: [dispose]
---

Step back and look at what Alice's cards travel through now. A query is a question asked once and kept fresh. An edit is applied everywhere at once and owed to the server until confirmed. Disagreements arrive as named outcomes, not exceptions. Adapters translate; closed channels absorb late answers; a tick the app controls decides when anything happens at all. Nowhere in the feature code is there a retry loop, a reconciliation pass, or an `isLoading` flag someone forgot to reset.

The mental model compresses well:

- **Two caches, no copies.** Values live once, by id; queries hold id lists. An update lands everywhere because there is only one everywhere.
- **Reads answer twice.** Local answers now; the remote answers with authority and is written through. `fresh` is trust, not location.
- **Writes are held sap.** Applied at once, persisted under a sequence number, pushed as ordered batches — reconnect and restart replay through the same flow.
- **Disagreement is vocabulary.** `retry` is weather, `fail` is a verdict; a rejection stays visible until `retry` or `discard` settles it; `receive` lets inbound truth in — and keeps it — without an echo.
- **The boundary is channels.** Adapters own transport and storage; a closed channel turns their late answers into silence.
- **Time is external.** One `tick` refreshes the watched, evicts the idle and sweeps the disk — three clocks, three tiers of forgetting — and liveness is read from the observer graph, not counted by hand.

### The exit

`dispose()` tears an instance down: it stops watching connectivity and closes every open fetch, so live subscriptions run their teardowns. Cached data is left to normal expiry, and calling it twice is safe. The engine never owned your interval, so stop your own timer beside it.

An instance is deliberately cheap. For a logout or a user switch: dispose the old instance, wipe the local store with your own code — the library never learned your storage, so only your adapter knows how to erase it, and forgetting that pairing is a privacy bug — then `make` a fresh one.

### Where to go from here

The [API reference](api.html) is the flat, complete surface — every function and type with signatures in both TypeScript and ReScript. This guide chose the readable rule; the reference has the precise one.

Everything here runs on tilia reactivity: results, `status`, the reconnect watcher are ordinary reactive values. If any of that felt like magic, [the tilia guide](../guide.html) is the missing floor — this guide is its promised sequel, the "synchronizing collections with a server" its last chapter deferred.

And the behaviors this guide narrated — the tunnel edits, the restart replay, the rejection that resurfaces until someone decides — exist as a Gherkin specification that runs against the implementation under [vitest-bdd](https://www.npmjs.com/package/vitest-bdd). Specification first, in plain language, kept true by the test runner: the [épure](https://epuremethod.com) method, applied to the library that carries its data.

::: story
The train comes out of the third tunnel and Alice's phone syncs three reviews without telling her. In Madrid, Nora's copy of the deck quietly gains them. A tunnel and a country turn out to be the same problem at different lengths — and Alice never once thought about the server, which was the point all along.
:::
