---
title: A shape for queries
slug: a-shape-for-queries
sort: 2
refs: []
---

In tilia's domain-driven guide, the scheduler's repository was injected... and politely ignored for nine chapters. Now it is connected to a remote server, and the first question is what the engine needs to know about your domain to manage it.

The answer is deliberately short: two functions.

### Identity and membership

`id` says which row a value *is*. `matches` says whether a value *belongs* to a query. Everything else (caching, refreshing, offline writes, merging) is built on those two answers:

```typescript
import { make } from "@tilia/query";

type DeckQuery = { deck: string };

const cards = make<Card, DeckQuery>({
  id: (card) => card.id,
  matches: (query, card) => card.deck === query.deck,
  remote: {
    online, // a tilia signal — chapter 4
    fetch: (query, channel) =>
      api.deckCards(query.deck, {
        onSuccess: channel.set,
        onFail: channel.fail,
      }),
    push: (ops, channel) => api.push(ops, channel), // chapter 4
  },
  local: cardStore, // a small adaptor over the device's storage — chapter 6
});
```

```rescript
open TiliaQuery

type deckQuery = {deck: string}

let cards = make({
  id: card => card.id,
  matches: (query, card) => card.deck === query.deck,
  remote: {
    online, // a tilia signal — chapter 4
    fetch: (query, channel) =>
      Api.deckCards(query.deck, ~onSuccess=channel.set, ~onFail=channel.fail),
    push: (ops, channel) => Api.push(ops, channel), // chapter 4
  },
  local: cardStore, // a small adaptor over the device's storage — chapter 6
})
```

A query is plain data — `{deck: "spanish"}` — and its serialized form is its cache key. Ask the same question anywhere in the application and you get the same living result: one fetch, one cached id list, one identity. There is nothing to register and nothing to name; the question *is* the key.

Notice what `matches` is: a pure predicate over **one row**. That restriction is the cornerstone of the library. Because membership can be decided by looking at a single value, the engine can update query results locally — when a write arrives, when a live update lands — without asking the server which lists changed. A query that cannot be expressed this way (a limit, a page, an aggregate) belongs in a domain adaptor of its own, not in this shape.

### Reading is asking

Two readers cover collection data: `array` returns a query's results, `one` returns the first result. Both are reactive tilia values — read them in a component or an observer and the subscription is the reading, exactly as in tilia:

```typescript
import { leaf } from "@tilia/react";

const DeckView = leaf(() => {
  const result = cards.array({ deck: "spanish" });
  switch (result) {
    case "loading":
      return <Skeleton />;
    case "notFound":
    case "notLocal":
      return <EmptyState />;
    default:
      if (result.state === "failed") return <Retryable message={result.message} />;
      return <Deck cards={result.data} dim={!result.fresh} />;
  }
});
```

```rescript
open TiliaReact

@react.component
let make = leaf(() => {
  switch cards.array({deck: "spanish"}) {
  | Loading => <Skeleton />
  | NotFound | NotLocal => <EmptyState />
  | Failed({message}) => <Retryable message />
  | Loaded({data, fresh}) => <Deck cards=data dim={!fresh} />
  }
})
```

The result is a `loadable`: a value with a lifecycle. Five answers are possible, and in ReScript the compiler holds you to all of them; the [next chapter](#reads-answer-twice) gives each one its precise meaning.

::: story
Alice packs. Her cards became an account last month; the laptop and the phone are both signed in. Nothing in her deck components changed that day. They still read `cards.array({deck: "spanish"})` and render what comes back.
:::

::: pro
Keep queries in domain vocabulary and wrap the filters and views in feature helpers : `deck.select("spanish")` reads better than a select with a query literal in a component, and it keeps the query shape in one place when it evolves.
:::

Two functions, two readers, one config. What that config gives back becomes visible the first time the app opens somewhere slow. Because now a read does not answer once. It answers twice.
