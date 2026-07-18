---
title: Where the network ends
slug: where-the-network-ends
sort: 1
refs: []
---

This chapter is for the person deciding whether @tilia/query belongs in their stack. There is no code in it.

@tilia/query is a query-state layer for remote collections, built on tilia reactivity. It exists because every feature that talks to a server ends up reinventing the same lifecycle: load list data, cache it, refresh it when it goes stale, merge live updates, and — if the app must keep working when the network becomes flaky or absent — keep local data safe until it returns. Each hand-rolled copy of that lifecycle is subtly different, and the differences are where the bugs live. @tilia/query makes it one lifecycle, shared by every collection in the application.

### Care, written as behavior

Underneath the API sits a conviction: an application should treat its user's time and words as things that matter. Here is how we translate this idea into enforceable rules: 

- **Never make the user wait for data the device has already seen.** The cache answers now; the network improves the answer when it can.
- **Offline is a state, not an error.** A tunnel is not an exceptional condition. Nothing red appears; nothing stops working that could keep working.
- **A write accepted is a write kept.** An edit made with no signal is applied on the spot, held durably, and delivered — in order — when the world returns. Restarting the app changes nothing.
- **Freshness is honest.** The app always knows whether what it shows is confirmed current or served from memory of the last visit, and it can say so quietly instead of blocking.
- **Disagreement is data, not damage.** When two people — or two devices — edit the same thing, the resolution has everything on the table: the common ancestor, your version, theirs. What can merge, merges. What cannot becomes a question for a human, with no version silently lost.

The landing page borrows a word for the third rule: *sève* — the sap. Held through winter, flowing again at thaw. Offline support is not a feature bolted onto a cache; it is what emerges naturally when the cache receives true persistence.

### What it deliberately does not do

@tilia/query owns the lifecycle and nothing else. It does not know your transport (HTTP, WebSocket, a sync engine), your storage (IndexedDB, SQLite, a file), your domain's query language, or even the clock — the app calls `tick()` from whatever scheduler it already has. All of those arrive as small **adapters** you write once per data source. The boundary is strict on purpose: the library can promise one coherent lifecycle precisely because it refuses to absorb the parts that differ between applications.

This is the same philosophy as tilia itself: a narrow library that supports domain-oriented development instead of a framework that replaces it. Feature modules are expected to wrap their query state in domain-specific helpers, so application code keeps reading in the language of the business.

### What it costs

The library is small and adds no dependencies beyond tilia. Every result it returns is a tilia value, so the reactivity you already understand carries through: a component re-renders only when a value it actually read has changed, and a background refetch that changes nothing re-renders nothing. The same API serves TypeScript and ReScript.

### How this guide works

Readers of the [tilia guide](../tilia/guide.html) left Alice with a working spaced-repetition scheduler and one politely ignored question: what happens when the cards must live on a server? This guide answers it, while on a trip.

::: story
Alice is going to spend a week with her friend Nora, in a village in the Spanish hills where the network is a rumor. Between here and there: a train with tunnels, a bus with curves, a laptop, a phone — and a deck of flashcards that had better not care about any of it.
:::

Each chapter explains one part of the lifecycle and why it is shaped that way: the shape of a query, the read that answers twice, writes that outlive the connection, changing devices, a week without a signal, and what happens when the server disagrees. If you decide for your team, this chapter and the [last](#onward) may be all you need. The chapters between are for whoever will build. And even a team that never adopts the library can adopt the rules, and the care.
