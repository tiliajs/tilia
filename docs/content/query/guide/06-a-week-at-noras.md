---
title: A week at Nora's
slug: a-week-at-noras
sort: 6
refs: [store-make, indexeddb-make, indexeddb-config-type, expiry-type, store-expiry-type, tick, status]
chapter: "06"
---

A tunnel tests whether offline *works*. A week tests whether offline was *designed*. Seven days without a signal means restarts, storage limits, and a growing pile of unsent writes — and Alice's feature code, notably, does nothing special about any of it. Nothing branches on connectivity. The same query and store absorb the whole week.

### Memory that survives the process

Without a `persist` option, `Store.make` uses an in-memory keyspace. The lifecycle is already offline-capable, but a page reload forgets it. In a browser, `@tilia/query/indexeddb` changes the material of that memory without changing the model:

```typescript
import { Store, make } from "@tilia/query";
import { make as indexedDb } from "@tilia/query/indexeddb";

const [cards, store] = make({
  id: (card: Card) => card.id,
  matches: (query: DeckQuery, card) => card.deck === query.deck,
  expiry: { refresh: 30_000, memory: 300_000 },
  store: Store.make<Card, DeckQuery>({
    find,
    upsert,
    remove,
    persist: indexedDb({
      name: "alice-cards",
      onError: reportPersistence,
    }),
    expiry: { local: 30 * 24 * 3_600_000 },
  }),
});
```

```rescript
let (cards, store) = TiliaQuery.make({
  id: card => card.id,
  matches: (query, card) => card.deck === query.deck,
  expiry: {refresh: 30_000., memory: 300_000.},
  store: TiliaQuery.Store.make({
    find,
    upsert,
    remove,
    persist: TiliaQueryIndexedDb.make({
      name: "alice-cards",
      onError: reportPersistence,
    }),
    expiry: {local: 30. *. 24. *. 3_600_000.},
  }),
})
```

Rows, remembered query answers, and the optimistic outbox all pass through that one durable keyspace. When the phone dies at two percent and restarts, the store reconstructs its memory and pending work. The feature resumes as if nothing happened, because as far as the data is concerned, nothing did. The outbox is data, not process state.

IndexedDB failure still deserves attention: `onError` is where the application reports an opening or transaction problem. Persistence cannot make a broken disk safe; it can make failure visible without giving the query engine a second, contradictory error model.

### Three clocks

Retention is governed by three independent expiries, each answering a different question:

`refresh` asks whether an observed answer should be confirmed again. `memory`
asks how long an unobserved query should occupy RAM. Both belong to `make`,
because they govern the query engine. `local` asks how long the durable record
of an unobserved query should keep participating in retention, so it belongs
to `Store.make`.

The split in the configuration mirrors the split in responsibility. Expiring one layer never implies expiring another. A fresh answer becoming local does not evict it from RAM; leaving RAM does not touch IndexedDB; and durable storage forgets only data that has gone unreferenced for long enough.

The local clock measures usefulness, not time offline. Each time Alice views
the deck, its query record is seen again. Leave the deck unopened past the
local expiry and that record may be removed; rows that no surviving record or
pending operation references are then swept. The duration belongs to the
query record, not each row: if a fresh answer stops listing a card, that card
can disappear at the next purge unless another record or pending write still
needs it.

The one guarantee that matters more than the cleanup mechanism is this: **pending writes are roots**. An edit that has not reached the server cannot be purged, no matter how old the queries around it grow. Retention may tidy the device's memory of server data; it has no authority over promises not yet kept.

All three clocks advance through the same `cards.tick()` the app was already calling. There are no daemons and no timers of the engine's own — the application's heartbeat maintains the week.

::: story
In the evenings at Nora's kitchen table, with the phone propped against the fruit bowl, Alice reviews her cards. She updates the clumsy example sentence on *echar de menos* and adds new cards from dinner conversations: *sobremesa* has no direct English translation, so she writes *time spent talking at the table after a meal*. The counter reads "41 waiting" by Friday, a number she has stopped reading as a warning. It isn't one. It is an inventory of things the app is keeping for her.
:::

::: pro
Never dress `pending` up as an error state offline. Forty-one held writes on day five is the system working exactly as designed — show it like a draft count, not a failure count.
:::

Forty-one operations, one week, two versions of a few shared cards — because Alice's study group kept going while she was in the hills. The bus back down is where the deck finds out.
