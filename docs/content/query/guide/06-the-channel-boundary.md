---
title: The channel boundary
slug: the-channel-boundary
sort: 6
refs: [remote-type, local-type, read-channel-type, write-channel-type, local-channel-type]
---

Adapters are where your application's reality — its HTTP client, its IndexedDB wrapper, its sync engine — meets the lifecycle. The contract between the two sides is a connectivity signal, a handful of functions, and the channels they answer through. This chapter builds a remote adapter and explains why the boundary is drawn exactly here.

### A remote adapter

The `remote` is a signal and two operations. `fetch` answers a query; `push` sends a batch of queued operations. Each reports its outcome by calling named callbacks on a channel:

```typescript
import { signal } from "tilia";
import type { Remote } from "@tilia/query";

const [online, setOnline] = signal(navigator.onLine);
window.addEventListener("online", () => setOnline(true));
window.addEventListener("offline", () => setOnline(false));

const remote: Remote<Card, DeckQuery> = {
  online,
  fetch(query, channel) {
    api.listCards(query.deck).then(
      (rows) => channel.set(rows),
      (err) => channel.fail(err.message)
    );
  },
  async push(ops, channel) {
    for (const op of ops) {
      // ops in order, one at a time; confirmations are matched by id
      try {
        if (op.op === "upsert") channel.set(await api.saveCard(op.value));
        else {
          await api.deleteCard(op.id);
          channel.removed(op.id);
        }
      } catch (err) {
        // a server verdict is definitive; anything else is weather
        return err.status ? channel.fail(err.message) : channel.retry();
      }
    }
  },
};
```

```rescript
open Tilia

let (online, setOnline) = signal(Navigator.onLine)

let remote: TiliaQuery.remote<card, deckQuery> = {
  online,
  fetch: (query, channel) =>
    Api.listCards(query.deck)
    ->Promise.thenResolve(rows => channel.set(rows))
    ->Promise.catch(err => Promise.resolve(channel.fail(Error.message(err))))
    ->ignore,
  push: (ops, channel) =>
    ops
    // ops in order, one at a time; confirmations are matched by id
    ->Array.reduce(Promise.resolve(), (prev, op) =>
      prev->Promise.then(() =>
        switch op {
        | Upsert({value}) =>
          Api.saveCard(value)->Promise.thenResolve(saved => channel.set(saved))
        | Remove({id}) =>
          Api.deleteCard(id)->Promise.thenResolve(() => channel.removed(id))
        }
      )
    )
    // a server verdict is definitive; anything else is weather
    ->Promise.catch(err =>
      Promise.resolve(
        Api.isVerdict(err) ? channel.fail(Error.message(err)) : channel.retry(),
      )
    )
    ->ignore,
}
```

The adapter's whole job is translation: your API's vocabulary of statuses and errors into the lifecycle's vocabulary of outcomes. It holds no state, retries nothing, caches nothing — all of that is the core's, which is why every collection behaves identically no matter what transport feeds it. The one judgment call it makes is the oldest one in distributed systems: is this "no", or "not now"? `fail` for a verdict, `retry` for weather.

::: pro
The engine reacts to `online` transitions: flipping to false settles queries still `Loading` into `NotLocal`; flipping to true pushes the outbox. Note that `fetch` may be invoked while offline — an adapter that stays silent then is fine. Answer when you can; the local tier's answer stands in the meantime.
:::

### A live source

`fetch` has a second dialect for sources that stay open — a server subscription, a changes feed:

```typescript
fetch(query, channel) {
  const feed = api.subscribe(query, {
    data: (rows) => channel.live(rows),
    error: (e) => channel.fail(String(e)),
    closed: () => channel.end(),
  });
  channel.finally(() => feed.unsubscribe());
}
```

```rescript
let fetch = (query, channel: TiliaQuery.Channel.read<card>) => {
  let feed = Api.subscribe(
    query,
    ~data=rows => channel.live(rows),
    ~error=message => channel.fail(message),
    ~closed=() => channel.end(),
  )
  channel.finally(() => feed.unsubscribe())
}
```

The division of labor is strict: the subscription belongs to the adapter, running its teardown belongs to the engine. `finally` holds one function — last write wins — and the engine runs it exactly once, when the fetch closes: on `end`, when a newer fetch supersedes this one, when the query is evicted from memory, or on `dispose`. Registering on a fetch that is already closed runs the function immediately, so a source that dies synchronously inside `fetch` is still torn down.

Two asymmetries are worth pinning. A `fail` does *not* close a live fetch — the source stays connected, and a later delivery replaces the failure; only `end` says the stream is over and hands the query back to periodic refresh. And going offline does not end a live query either: the engine cannot know whether your transport survived the outage, so ending is always the adapter's call.

### Why callbacks, and why closed channels

Outcomes are reported by *calling a named function*, never by returning or constructing a result value. Two reasons. First, the boundary is bilingual: ReScript variants do not exist in compiled JavaScript, so a contract built on constructing them would be unwritable from TypeScript — named callbacks read identically in both languages. Second, a callback gives the core a place to stand between the adapter and the caches.

That place matters because of time. Answers arrive late: a fetch resolves after a newer fetch superseded it, a subscription pings after its query was evicted. Every callback on a closed fetch is a noop — the engine absorbs staleness at the boundary, once, instead of making it a discipline every adapter must remember. The adapter never checks whether its answer is still wanted. It answers.

### The local store

The optional `local` adapter is the durable half — five functions, two stores in one:

- The **values table**, typed. `fetch(query, channel)` answers a query from disk — `set(rows)`, or `unknown()` when the store cannot answer (a store that can run the collection's `matches` over its cache may prefer a partial `set`: for the user in a tunnel, a partial answer beats `NotLocal`). `push(ops)` applies changes in order: an upsert writes or replaces the row, a remove drops it.
- The **bookkeeping KV**, strings. `set(tag, key, value?)` and `get(tag, key?, set)` hold the engine's own notes — the persisted outbox, the query registry — as opaque strings under tags. `ids(set)` enumerates every row id, which the purge of [chapter 7](#the-pulse-and-the-canopy) uses to sweep.

Local persistence is command-only: there is no local write channel. Confirmation, retry and rejection are remote concepts; a local storage error is the adapter's own business — log it, retry it, surface it in app state — and the library never sees it. Note what else is absent: no migrations, no schemas, no query planner. Values reach the adapter typed, so it stores them natively and indexes them however it likes.

::: story
Alice notices none of this, which is the review the adapter author wanted.
:::

One piece of the lifecycle is still unclaimed: nothing has said *when* stale queries refresh or idle ones are evicted. That timing belongs to the application — and to the next chapter.
