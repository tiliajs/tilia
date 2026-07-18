---
title: Reads answer twice
slug: reads-answer-twice
sort: 3
refs: []
---

Open a query and two reads start at once: the local store answers from what the device already holds, and the remote answers from the truth. The local answer arrives in milliseconds; the remote takes whatever the network takes. The user sees the first and is quietly upgraded to the second:

```typescript
cards.array({ deck: "spanish" });
// now   → { state: "loaded", data: [gato, perro], fresh: false }   local
// later → { state: "loaded", data: [gato, perro], fresh: true }    remote
```

```rescript
cards.array({deck: "spanish"})
// now   → Loaded({data: [gato, perro], fresh: false})   local
// later → Loaded({data: [gato, perro], fresh: true})    remote
```

That is the whole trick, and it is the first rule from [chapter 1](#where-the-network-ends) made mechanical: no spinner ever stands in front of data the device has already seen. The network improves the answer; it does not gate it.

### fresh is about knowledge, not location

The `fresh` field does not say where the rows are stored. It says whether the value is known to be current. A UI can whisper that distinction — dim the deck a shade, show a small dot. When a fresh remote result lands, it becomes the visible one, and its rows are written through to the local store, so tomorrow's cold start answers from today's truth.

There is one exception: while online, a local answer that is *empty* keeps the query `Loading` rather than flashing an empty screen. Empty-and-checking and empty-for-sure are different facts, and the user should only see the second.

### Five answers, each a sentence

A `loadable` never makes the reader guess. Each state is a complete sentence:

- `Loading` — an answer may still be coming. Shown only when there is truly nothing to show yet.
- `Loaded, fresh: false` — here is what we know; we are checking.
- `Loaded, fresh: true` — this is current.
- `NotFound` — the fetch completed, and there is nothing. An answer, from `one`.
- `NotLocal` — the device is offline and holds nothing for this query. Also an answer, not a progress state: the app can say "not available offline" instead of spinning forever.
- `Failed` — the remote fetch broke, and the message surfaces *at the read site*, where the value is used. There is no global error slot, and the query is not stuck: it re-enters the refresh cycle and retries.

### The heartbeat

Who decides when "fresh" stops being true? The engine has no timers. The application calls `tick()`, and the library does the time-based work: queries someone is watching are refreshed when their result grows old (30 seconds by default, while online), results nobody watches are let go from memory, old local data is eventually purged.

"Someone is watching" is not a subscription API. The engine asks tilia's observer graph which results are currently being read. A component rendering `cards.array({deck: "spanish"})` keeps that query alive, and closing the component lets it retire. Reading marks the query as observed, like any reactive value in tilia.

::: pro
A refetch returning the same rows changes nothing: the result keeps its identity, and nothing re-renders. Background freshness is free at the UI layer — you never pay a repaint for learning that nothing changed.
:::

::: story
The 8:04 train pulls out. Alice opens the laptop before the wifi has decided whether it exists; the Spanish deck is simply there, yesterday's copy, a shade dimmer if you know where to look. Three stops later, something on the screen barely brightens. All along, she never saw a spinner, because there was none.
:::

Reading is now settled: local answers, remote confirms, the app tells the truth about which is which. The train, meanwhile, is heading for the mountains — and the first tunnel is about mutations.
