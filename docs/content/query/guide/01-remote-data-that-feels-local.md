---
title: Remote data that feels local
slug: remote-data-that-feels-local
sort: 1
refs: []
---

This chapter is for the person deciding whether @tilia/query belongs in their stack. There is no code in it.

@tilia/query is a query-state layer built on tilia reactivity. It exists because every feature that touches a server ends up reinventing the same flow: load list data, cache it, refresh it when it goes stale, merge live updates, avoid pointless refetches — and, if the app must work offline, keep local writes safe until the network returns. Each hand-rolled copy of that flow is subtly different, and the differences are where the bugs live. @tilia/query makes it one flow, shared by every collection in the application.

### Local first, remote authoritative

The design rests on a single conviction: the user should never wait for data the app has already seen. Reads answer instantly from cache — memory first, then a local store — and refresh quietly in the background when the remote answers. Writes apply on the spot and sync when they can. There are no loading walls between the user and data that is already on the device; the network improves the answer, it does not gate it.

The landing page borrows a word for this: *sève* — the sap. Held through winter, flowing again at thaw. Data written offline is not lost or blocked; it is held, durably, and moves the moment the connection returns. Offline support is not a feature bolted on top — it is what falls out when the cache is honest about being a cache.

### What it deliberately does not do

@tilia/query owns the lifecycle and nothing else. It does not know your transport (HTTP, WebSocket, a sync engine), your storage (IndexedDB, SQLite, a file), your domain's query language, or your scheduling policy. All of those arrive as small **adapters** you write per feature — a `remote`, an optional `local` store, and a `tick()` call from whatever scheduler the app already has. The boundary is strict on purpose: the library can promise one coherent lifecycle precisely because it refuses to absorb the parts that differ between applications.

This is the same philosophy as tilia itself: a narrow library that supports domain-oriented development instead of a framework that replaces it. Feature modules are expected to wrap their query state in domain-specific helpers, so application code keeps reading in the language of the business.

### What it costs

The library is small and adds no dependencies beyond tilia. Because every view it returns is a tilia value, the reactivity you already understand carries through: a component re-renders only when a value it actually read has changed, and a refetch that changes nothing re-renders nothing. The same API serves TypeScript and ReScript.

### How this guide works

Readers of the [tilia guide](../guide.html) left Alice with a working spaced-repetition scheduler and one politely ignored question: what happens when the cards must live on a server? This guide answers it.

::: story
Alice made an account. Her cards now live on a server, her phone and her laptop both show the deck — and her commute goes through three tunnels. In two weeks, a bigger test: a week at Nora's in Madrid, with no data plan.
:::

Each chapter explains one part of the lifecycle and why it is shaped that way: the caches, the two-tier reads, the write outbox, disagreement with the server, the adapter boundary, and time. The behavior described here is pinned by an executable specification — every claim about offline edits, replays and rejections is a scenario that runs green. If you decide for your team, this chapter and the [last](#onward) may be all you need. The chapters between are for whoever will build — human or machine, the specification holds both to the same contract.
