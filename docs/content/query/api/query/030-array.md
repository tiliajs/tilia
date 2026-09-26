---
name: array
slug: array
kind: function
module: core
since: "0.1"
sort: 30
summary: Reactively read a query's sorted result array.
tags: []
signature.ts: "array: (query: Q) => Loadable<T[]>"
signature.res: "array: 'query => loadable<array<'a>>"
label: array(query)
---

`array` reads all values matching a query, ordered by the configured `sort`. The read is reactive and includes the optimistic overlay from pending store writes.

A complete empty answer is data: `{ state: "loaded", data: [], claim }`. An empty `partial` answer remains `"loading"` while remote data is possible and becomes offline `NoData` when it is not.

```typescript
// The deck list. `claim` is a field, not a state: the common path renders
// whatever is there, and only the badge asks how strong the answer is. An
// empty deck is a loaded empty list, not an absence.
const deckView = () => {
  const deck = cards.array({ deck: "spanish" });
  if (deck === "loading") return spinner();
  if (deck.state === "noData") return empty(deck.reason);
  return list(deck.data, deck.claim === "fresh" ? null : staleBadge(deck.claim));
};
```

```rescript
// The deck list. `claim` is a field, not a state: the common path renders
// whatever is there, and only the badge asks how strong the answer is. An
// empty deck is a loaded empty list, not an absence.
let deckView = () =>
  switch cards.array({deck: "spanish"}) {
  | Loading => spinner()
  | NoData({reason}) => empty(reason)
  | Loaded({data, claim: Fresh}) => list(data, None)
  | Loaded({data, claim}) => list(data, Some(staleBadge(claim)))
  }
```
