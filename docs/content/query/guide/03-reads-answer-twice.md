---
title: Reads answer twice
slug: reads-answer-twice
sort: 3
refs: [array, one, loadable-type, read-channel-type, local-channel-type]
---

A query has two possible sources: the local store on the device, and the remote. @tilia/query asks both — and the way it arbitrates between their answers is what makes cached data trustworthy instead of merely fast.

### The first read starts the fetch

Nothing is fetched until someone asks. The first read of `array({deck: "spanish"})` registers the query, marks it stale, and starts a fetch; every later read finds the memoized view. A fetch runs both tiers:

- **local** always answers, if a local store is configured. Whatever rows it sets fill the caches immediately — this is why the list appears in one frame.
- **remote** answers only while `remote.online` is true. Its rows are **authoritative**: they refresh the query's freshness timestamp, and they are written through to the local store, so the next offline session starts from the newest truth the device ever saw.

The expectation is simply that the remote's answer lands after the local one — a network round trip after a disk read — so authority arrives last and wins by arriving. Both answer through the same path; there is no special merge step, just a second, better answer to the same question.

::: story
The métro doors close and the signal dies mid-refresh. Alice's deck doesn't flinch: the local store already answered. The remote's turn will come at the next station.
:::

If the id list a tier sets is identical to the current one, nothing commits — the view keeps its identity, exactly as the [previous chapter](#a-shape-for-queries) promised. A no-op refresh is invisible by construction, not by diffing the DOM later.

### The answer is also the inventory

An authoritative answer does one more thing: it settles what the device should still be holding. Each query's id list is persisted through the local store, and every remote answer is diffed against the last one — rows that were in the result and no longer are get purged from the local store and evicted from memory. Without this, a row deleted on the server would linger on disk and reappear as a ghost on the next offline start: the screen said gone, the restart said back.

The rule is worth stating precisely, because it decides what your local store contains: **retention is driven by the server's own answers — the persisted id lists — never by re-evaluating `matches`, and unsynced writes are untouchable.** A row survives as long as some persisted result still claims it or the outbox still owes it to the server; when the last claim goes, so does the row. The local store is thereby bounded to the union of known query results plus unsynced writes — it cannot grow into an unaccounted copy of the server.

::: story
On the laptop, Alice prunes twenty cards she'll never review again. Her phone, online in her pocket, refreshes the deck and quietly drops the same twenty from disk. In tomorrow's tunnel, the deck is the deck — not the deck plus its dead.
:::

### Stale is a timestamp, not an event

Every query remembers when the remote last confirmed it. A query older than the `stale` window (30 seconds by default) is refetched on the next `tick()` — while online and while someone is actually watching it. [Chapter 7](#the-pulse-and-the-canopy) covers the tick; what matters here is the shape of the policy: freshness decays with time, refresh happens in the background, and the data on screen stays put while the new answer is fetched. There is no flash of *loading* over a list the user is already reading.

### Three ways for a fetch to end

The adapter reports the outcome of a fetch through a channel with three named callbacks, and the distinctions carry the semantics:

- `set(rows)` — here is the answer. Each call replaces the query's result with these complete rows — never a delta — and may happen more than once: cached rows now, fresh rows later, live updates forever.
- `covered()` — "a sync engine owns this query." Mark it fresh, keep whatever the cache holds, don't expect rows. This is the hook for delta-sync setups where the local store *is* continuously updated by other machinery and a remote refetch would be redundant. Covered queries are also never reconciled or pruned — no id list is persisted for them, so the engine keeps sole ownership of their rows.
- `fail(message)` — a transport error, and strictly that. The query's freshness is left untouched, so the next tick simply retries; the last failure is surfaced on `status.error` for the UI, and cleared by the next success.

The narrowness of `fail` is deliberate. "The server said there are none" is `set([])`. "I couldn't reach the server" is `fail`. Collapsing the two would poison the cache with absences that were really outages.

::: pro
Local-tier failures are ignored by design. A local store that throws is an adapter bug, not a sync state the application should reason about — fix the adapter, don't design UI for it.
:::

Reading is now solid: instant, honest, self-refreshing. But Alice doesn't just read her cards — she reviews them, in a tunnel, and expects the server to eventually agree. Writing is where the sap has to survive winter.
