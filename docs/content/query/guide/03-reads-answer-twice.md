---
title: Reads answer twice
slug: reads-answer-twice
sort: 3
refs: [one, array, loadable-type, read-channel-type, local-channel-type]
---

A query has two possible sources: the local store on the device, and the remote. @tilia/query asks both — and the way it arbitrates between their answers is what makes cached data trustworthy instead of merely fast.

### The first read starts the fetch

Nothing is fetched until someone asks. The first read of `array({deck: "spanish"})` registers the query and starts a fetch; every later read finds the same entry. A fetch runs both tiers:

- **local**, when a local store is configured, answers from disk. Whatever rows it sets fill the caches immediately — this is why a deck the device has seen appears in one frame. A local answer only ever *materializes* a query: on a later refresh it is skipped, so a stale disk read can never overwrite a fresher remote answer.
- **remote** is **authoritative**. Its rows refresh the query's freshness and are written through to the local store, so the next offline session starts from the newest truth the device ever saw.

The expectation is simply that the remote's answer lands after the local one — a network round trip after a disk read — so authority arrives last and wins by arriving. Both answer through the same path; there is no special merge step, just a second, better answer to the same question.

::: story
The métro doors close and the signal dies mid-refresh. Alice's deck doesn't flinch: the local store already answered. The remote's turn will come at the next station.
:::

Write-through has a deliberate limit: remote rows are upserted into the local store, but rows *missing* from an answer are not deleted from disk. Absence from one query's result proves nothing — the row may still belong to another query. Forgetting is a global question, and [chapter 7](#the-pulse-and-the-canopy)'s purge answers it globally, by proof rather than by guess.

### Fresh is trust, not location

`Loaded` carries a `fresh` flag, and it describes exactly one thing: whether the remote is known to be current. It does not say where the rows physically came from.

- A remote delivery sets `fresh: true`.
- A query that goes longer than the refresh window (30 seconds by default) without a remote delivery flips to `fresh: false` on the next `tick()`. The data stays on screen; only the claim about it weakens. While online, the flip waits one extra eighth of the window, so an in-flight refresh can land without a flicker; offline, it flips right at the limit.
- The next remote delivery flips it back.

Refresh itself is background work: a watched query older than the window is refetched on the next tick, while online — [chapter 7](#the-pulse-and-the-canopy) owns the schedule. What matters here is the shape of the policy: freshness decays with time, refresh happens behind the data, and there is no flash of *loading* over a list the user is already reading.

::: story
Two stations without signal. The deck is still on screen and still correct as far as anyone knows — but its little cloud icon has gone hollow: the app renders `fresh`, and the deck stopped being provably fresh a minute ago.
:::

### Two honest dead ends

The remaining `loadable` states are answers, not accidents:

- `NotLocal` is the offline dead end: nothing cached locally and the remote unreachable. Unlike `Loading` it is an answer, not a progress state — show "not available offline", not a spinner. It only appears while offline; online, an empty local answer keeps the query `Loading` until the remote responds. A local adaptor that can filter its cache with `matches` may prefer building partial results and setting those — a partial answer beats a dead end.
- `Failed` carries a fetch error to the read site, where the value is used — there is no global error slot to join against. A failed query is not stuck: once the refresh window has passed, the next tick retries it, and a success replaces the failure. One attempt per window — no giving up, no hammering.

The narrowness of `fail` is deliberate. "The server says there are none" is `set([])`. "I couldn't reach the server" is `fail`. Collapsing the two would poison the cache with absences that were really outages.

::: story
Deep under the river, Alice taps a deck she has never opened on this phone. No spinner, no lie: *not available offline*. At the next station it loads — and joins the set of decks that will never say that again.
:::

### How a source answers

The remote adapter reports through a channel of five named callbacks, and the distinctions carry the semantics:

- `set(rows)` — here is the answer, complete — never a delta. Call it again whenever fresher rows arrive; each call replaces the result. A `set`-only source gets the periodic refresh described above.
- `live(rows)` — same delivery, plus a declaration: "I keep this fresh myself." A subscription source answers with `live` on every update, and the periodic refresh skips the query — its source is the freshness.
- `fail(message)` — a transport error, and strictly that.
- `end()` — the stream is over. The query returns to ordinary periodic refresh.
- `finally(fn)` — register the teardown for whatever `fetch` opened. The engine runs it exactly once, when the fetch closes.

The last three belong to the subscription story, and [chapter 6](#the-channel-boundary) tells it fully — including why an adapter never has to worry about answering too late.

Reading is now solid: instant, honest, self-refreshing. But Alice doesn't just read her cards — she reviews them, in a tunnel, and expects the server to eventually agree. Writing is where the sap has to survive winter.
