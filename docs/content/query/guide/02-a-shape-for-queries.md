---
title: A shape for queries
slug: a-shape-for-queries
sort: 2
refs: [make, one, array, sorted-stringify]
---

Everything in @tilia/query starts with one call: `make` builds the query state for a collection. This chapter is about what that object holds — two connected caches — and the vocabulary it uses to answer honestly when data is not there yet.

### Making a collection

`make` takes a configuration that describes the collection in domain terms: how to identify an object, where the data lives, and — optionally — how to decide membership and order without asking the server:

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
  id: (card) => card.id,
  remote, // authoritative — chapter 6 builds it
  local, // answers offline — chapter 6 builds it too
  matches: (q, card) => card.deck === q.deck,
  sort: (a, b) => (a.dueDate < b.dueDate ? -1 : 1),
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
  id: card => card.id,
  remote, // authoritative — chapter 6 builds it
  local, // answers offline — chapter 6 builds it too
  matches: (q, card) => card.deck == q.deck,
  sort: (a, b) => a.dueDate < b.dueDate ? -1.0 : 1.0,
})
```

Notice what the configuration is *not*: there is no URL, no table name, no serialization format. Those belong to the adapters. What `make` needs is the domain's own logic — identity, membership, order — because those are exactly the three things it can use to keep results correct without a round trip.

### Two connected caches

Internally, `cards` keeps two caches that reference each other:

- an **object cache**, every known card by id;
- a **query cache**, one entry per distinct filter, holding an *id list* — not copies of the rows.

The split is the load-bearing decision of the whole library. Because queries store ids and objects live in one place, an object updated once is updated everywhere: every list that contains it, every detail view that shows it. There is no "which copy is current?" — there are no copies.

The query cache is keyed by a stable serialization of the filter (`{deck: "spanish"}` and a differently-ordered but equal object produce the same key), so the same question always finds the same entry. You can supply your own `key` function when filters carry values that don't serialize well.

### Three views, one honesty

You read the collection through three views — `array` for lists, `one` for a detail, `dict` when you want rows keyed by id — plus `get` for a plain cache lookup by id. Each returns a `loadable`, a value that admits it might not be there yet:

```typescript
const spanish = cards.array({ deck: "spanish" });

if (spanish === "loading") render(skeleton);
else if (spanish === "notFound") render(empty);
else render(spanish.data); // Card[]
```

```rescript
let spanish = cards.array({deck: "spanish"})

switch spanish {
| Loading => render(skeleton)
| NotFound => render(empty)
| Loaded({data}) => render(data)
}
```

::: story
Alice opens the Spanish deck on her phone. For one frame the list says *loading*; then every card she has ever written is simply there.
:::

`loadable` is deliberately small. `Loading` means the question was just asked. `Loaded` carries data — and an empty list is `Loaded` with an empty array, not `NotFound`: "the server answered and there are none" is an answer. `NotFound` is reserved for `one` resolving nothing and for `get` missing the cache. The distinction sounds pedantic until a UI has to choose between a spinner and an empty state; then it is the whole point.

### Views keep their identity

Views are memoized per query key: asking `array({deck: "spanish"})` twice returns the *same* reactive value, and that value only rebuilds when the id list actually changes membership or order. A background refetch that returns the same rows commits nothing, notifies nobody, re-renders nothing. This falls straight out of the two-cache design — comparing two id lists is cheap, so the library can afford to check before it speaks.

::: pro
Views are tilia values. Read them inside `observe`, a computed, or a React component using tilia, and the view subscribes like any other reactive value — no hooks or glue specific to @tilia/query.
:::

So far the data appeared by magic. The next chapter follows the question out of the cache: who answers a query, in what order, and what *fresh* means.
