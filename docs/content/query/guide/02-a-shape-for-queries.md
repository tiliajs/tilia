---
title: A shape for queries
slug: a-shape-for-queries
sort: 2
refs: [make, config-type, one, array, loadable-type, sorted-stringify, tilia-query-type]
---

Everything in @tilia/query starts with one call: `make` builds the query state for a collection. This chapter is about what that object holds — two connected caches — and the vocabulary it uses to answer honestly when data is not there yet.

### Making a collection

`make` takes the domain's own logic — how to identify a value, how to decide membership, where the data lives:

```typescript
import { make } from "@tilia/query";

type Card = {
  id: string;
  deck: string;
  front: string;
  back: string;
  dueDate: string;
};
type DeckQuery = { deck: string };

const cards = make<Card, DeckQuery>({
  id: (card) => card.id, // identity
  matches: (q, card) => card.deck === q.deck, // membership
  remote, // authoritative — chapter 6 builds it
  local, // answers offline — chapter 6 builds it too
});
```

```rescript
type card = {
  id: string,
  deck: string,
  front: string,
  back: string,
  dueDate: string,
}
type deckQuery = {deck: string}

let cards = TiliaQuery.make({
  id: card => card.id, // identity
  matches: (q, card) => card.deck == q.deck, // membership
  remote, // authoritative — chapter 6 builds it
  local, // answers offline — chapter 6 builds it too
})
```

Four optional pieces refine the shape: `sort` fixes result order (an array in, an ordered array out — [one](api.html#one) answers the first value per that order), `key` names a query when the default serialization doesn't fit, `expiry` tunes the clocks of [chapter 7](#the-pulse-and-the-canopy), and `now` injects a fake clock in tests.

Notice what the configuration is *not*: there is no URL, no table name, no serialization format. Those belong to the adapters. And notice the constraint on `matches`: it must be a pure predicate over one value. Limits, pagination and aggregates do not fit this shape, because a written value joins a result through `matches` alone — membership has to be decidable by looking at a single row.

### Two connected caches

Internally, `cards` keeps two caches that reference each other:

- an **object cache**, every known card by id;
- a **query cache**, one entry per distinct filter, holding an *id list* — not copies of the rows.

The split is the load-bearing decision of the whole library. Because queries store ids and objects live in one place, an object updated once is updated everywhere: every list that contains it, every detail view that shows it. There is no "which copy is current?" — there are no copies.

The query cache is keyed by a stable serialization of the filter (`{deck: "spanish"}` and a differently-ordered but equal object produce the same key), so the same question always finds the same entry. Queries should stay plain data that survives a JSON round trip — the default key needs it, and so does the persistence machinery of later chapters, which stores queries on disk and runs `matches` against them long after they left memory. You can supply your own `key` function when filters carry values that don't serialize well.

### Two readers, one honesty

You read the collection through two views — `array` for lists, `one` for a single value. There is no separate read-by-id API: an id is just another query, read with `one`. Each returns a `loadable`, a value that admits it might not be there yet:

```typescript
const spanish = cards.array({ deck: "spanish" });

if (spanish === "loading") render(skeleton);
else if (typeof spanish === "object" && spanish.state === "loaded")
  render(spanish.data); // Card[] — an empty deck included
```

```rescript
switch cards.array({deck: "spanish"}) {
| Loading => render(skeleton)
| Loaded({data}) => render(data) // an empty deck included
| _ => ()
}
```

::: story
Alice opens the Spanish deck on her phone. For one frame the list says *loading*; then every card she has ever written is simply there.
:::

`loadable` is deliberately small. `Loading` means the question was just asked. `Loaded` carries data — and an empty list is `Loaded` with an empty array, not `NotFound`: "the server answered and there are none" is an answer. `NotFound` is reserved for `one` resolving nothing. The distinction sounds pedantic until a UI has to choose between a spinner and an empty state; then it is the whole point.

Two more states exist — `NotLocal` and `Failed` — and `Loaded` carries a `fresh` flag this chapter has quietly ignored. All three belong to the next chapter, where reads meet the network.

### Reading is subscribing

Results are tilia values. Read one inside `observe`, a computed, or a React component using tilia, and the caller re-runs when the result changes — no hooks or glue specific to @tilia/query. And because values live once in the object cache, an update to one card reaches every list and every detail view in the same commit.

::: pro
Reading a result inside an observer does one more thing, quietly: it marks the query as *watched*, which is what keeps it refreshed and in memory. [Chapter 7](#the-pulse-and-the-canopy) makes that mechanism explicit.
:::

So far the data appeared by magic. The next chapter follows the question out of the cache: who answers a query, in what order, and what *fresh* means.
