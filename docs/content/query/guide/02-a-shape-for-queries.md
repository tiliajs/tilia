---
title: A shape for queries
slug: a-shape-for-queries
sort: 2
refs: [make, store-make, config-type, store-config-type, sorted-stringify, loadable-type, one, array]
chapter: "02"
---

In tilia's domain-driven guide, the scheduler's repository was injected... and politely ignored for nine chapters. Now it is connected to a remote server, and the first question is what the engine needs to know about your domain to manage it.

The domain-specific answer is deliberately short: two functions. The store needs three more answers from the backend — how to find, save, and remove — but those describe transport rather than the domain.

### Identity and membership

`id` says which row a value *is*. `matches` says whether a value *belongs* to a query. Everything else (caching, refreshing, offline writes, merging) is built on those two answers:

```typescript
import { make, Store } from "@tilia/query";

type DeckQuery = { deck: string };

const [cards, store] = make({
  id: (card: Card) => card.id,
  matches: (query: DeckQuery, card: Card) => card.deck === query.deck,
  store: Store.make<Card, DeckQuery>({ find, upsert, remove }),
});
```

```rescript
open TiliaQuery

type deckQuery = {deck: string}

let (cards, store) = make({
  id: card => card.id,
  matches: (query, card) => card.deck === query.deck,
  store: Store.make({find, upsert, remove}),
})
```

A `find` answers one question, while `upsert` and `remove` say what became of one write. They are small translations around the application's existing backend; their exact callback shapes belong in the [Store.make reference](api.html#store-make). The important point here is the boundary: the engine knows identity and membership, while the store knows how to speak to the server.

A query is plain data — `{deck: "spanish"}` — and its deterministically serialized form is its cache key by default. A custom `key` can replace that rule. Ask the same question anywhere in the application and you get the same living result: one find, one cached id list, one identity. There is nothing to register and nothing to name; the question *is* the key.

Notice what `matches` is: a pure predicate over **one row**. That restriction is the cornerstone of the library. Because membership can be decided by looking at a single value, the engine can update query results locally when a write happens, without asking the server which lists changed. Ordering can still depend on the query because `sort`, when supplied, returns a sorter for that query. A question whose membership cannot be decided per row — a limit, a page, an aggregate — needs a different domain boundary rather than a misleading query.

### Reading is asking

The returned pair gives each side a plain role. `cards` is the query object: `array` returns all results and `one` returns the first. `store` is where the application writes and watches synchronization. Both belong to the same engine, but keeping their verbs apart makes feature code easier to read:

```typescript
import { leaf } from "@tilia/react";

const DeckView = leaf(() => {
  const result = cards.array({ deck: "spanish" });
  return typeof result === "object" && result.state === "loaded"
    ? <Deck cards={result.data} />
    : <DeckUnavailable result={result} />;
});
```

```rescript
open TiliaReact

@react.component
let make = leaf(() => {
  switch cards.array({deck: "spanish"}) {
  | Loaded({data}) => <Deck cards=data />
  | result => <DeckUnavailable result />
  }
})
```

Both readers are reactive tilia values — reading is subscribing, exactly as in tilia. Their result is a `loadable`: not merely data, but the application's present knowledge of that data. The [next chapter](#reads-answer-twice) explains why that knowledge has a shape of its own.

::: story
Alice packs. Her cards became an account last month; the laptop and the phone are both signed in. Nothing in her deck components changed that day. They still read `cards.array({deck: "spanish"})` and render what comes back.
:::

::: pro
Keep queries in domain vocabulary and wrap the filters and views in feature helpers: `deck.select("spanish")` reads better than selecting with a query literal in a component, and it keeps the query shape in one place as it evolves.
:::

Two domain functions, three backend operations, and one pair. What that pair means becomes visible the first time the app opens somewhere slow. A read does not merely answer once; it begins with what this device knows and becomes stronger when the world replies.
