---
title: Reads answer twice
slug: reads-answer-twice
sort: 3
refs: [claim-type, reason-type, loadable-type, expiry-type, tick]
chapter: "03"
---

Open a query and two kinds of knowledge meet. The store answers from what the device already holds; the backend answers from the present. The first arrives without waiting for the network, and the second strengthens it when it can:

```typescript
cards.array({ deck: "spanish" });
// now   → { state: "loaded", data: [gato, perro], claim: "local" }
// later → { state: "loaded", data: [gato, perro], claim: "fresh" }
```

```rescript
cards.array({deck: "spanish"})
// now   → Loaded({data: [gato, perro], claim: Local})
// later → Loaded({data: [gato, perro], claim: Fresh})
```

That is the whole trick, and it is the first rule from [chapter 1](#where-the-network-ends) made mechanical: no spinner ever stands in front of data the device has already seen. The network improves the answer; it does not gate it.

### Claims are about knowledge

The `claim` does not say where rows happen to be stored. It says what the store can honestly assert about the answer:

- `partial` means “these rows match, but there may be more.” A device can recognize matching cards it holds without claiming it has the whole deck.
- `local` means “this is the complete answer I remembered for this exact question.” It is useful, but it is not a claim about the server now.
- `fresh` means “this complete answer is authoritative as of now.” Usually the backend just confirmed it; a synchronized store could make the same claim without moving any bytes.

This is more expressive than a freshness boolean because incompleteness and age are different problems. Alice can review two locally known cards under a `partial` answer without being told that they are the entire deck. A `local` answer can safely render an empty deck because the device remembers that emptiness as complete. When a fresh answer arrives, its rows and query record are persisted; after it ages, `tick()` lowers it to `local` without taking the data away.

### Nothing also has a reason

A `loadable` asks the reader to make only three broad choices: wait, render, or explain why there is no data. The last choice carries a structured `reason`, because “nothing” can mean importantly different things:

```typescript
const result = cards.one({ deck: "spanish" });

if (result === "loading") return <Skeleton />;
if (result.state === "loaded") return <Card card={result.data} claim={result.claim} />;
if (result.reason === "offline") return <UnavailableOffline />;
if (result.reason.reason === "failed") {
  return <Retryable message={result.reason.message} />;
}
return <NoCardYet claim={result.reason.claim} />;
```

```rescript
switch cards.one({deck: "spanish"}) {
| Loading => <Skeleton />
| Loaded({data, claim}) => <Card card=data claim />
| NoData({reason: Offline}) => <UnavailableOffline />
| NoData({reason: Failed({message})}) => <Retryable message />
| NoData({reason: NoMatch({claim})}) => <NoCardYet claim />
}
```

`offline` says the device has nothing useful for the question and cannot improve that answer now. `failed` carries the backend's message when the first attempt failed before anything could be shown. `noMatch` belongs to `one`: a complete answer was empty, and its own claim says whether that emptiness is remembered or current. For `array`, a complete empty answer is ordinary loaded data — an empty collection is still an answer.

An empty partial answer is not useful enough to render. While online it remains `loading`, because a complete answer may still arrive; offline it becomes `noData` with `offline`, so the app never spins forever.

There is one deliberate asymmetry. If a refresh fails after rows are already loaded, the rows stay visible with their existing claim. Replacing useful data with an error would make a temporary outage destructive. The optional `onError(query, message)` on `make` receives that background failure for logging or a quiet notice; only a first failure with nothing behind it becomes `noData` with `failed` at the read site.

### The heartbeat

Who decides when a `fresh` claim becomes `local`? The engine has no timers. The application calls `tick()`, and the library does the time-based work: queries someone is watching are refreshed when their result grows old, results nobody watches are eventually let go from memory, and the store gets the same heartbeat for persistence and retry work.

"Someone is watching" is not a subscription API. The engine asks tilia's observer graph which results are currently being read. A component rendering `cards.array({deck: "spanish"})` keeps that query alive, and closing the component lets it retire. Reading marks the query as observed, like any reactive value in tilia.

::: pro
A refresh returning the same rows changes nothing: the result keeps its identity, and nothing re-renders. Background freshness is quiet at the UI layer — you do not pay a repaint for learning that nothing changed.
:::

::: story
The 8:04 train pulls out. Alice opens the laptop before the Wi-Fi has decided whether it exists; the Spanish deck is simply there, yesterday's complete copy, marked `local` in the small status line. Three stops later it becomes `fresh`. All along, she never saw a spinner, because there was none.
:::

Reading is now settled: the device offers what it knows, the backend confirms what it can, and the app tells the truth about the strength of the answer. The train, meanwhile, is heading for the mountains — and the first tunnel is about mutations.
