---
name: .array
slug: array
kind: function
module: core
since: "0.1"
sort: 40
summary: List view — a reactive array of the rows matching a query.
signature:
  ts: "collection.array(query: Q): Loadable<T[]>"
  res: "collection.array: 'query => loadable<array<'a>>"
tags: []
---

`array` is the main list view. The first read registers the query and starts the two-tier fetch; later reads return the same memoized view.

An empty result is `Loaded` with an empty array, not `NotFound` — "the query answered and there are none" is an answer. The view rebuilds only when the underlying id list changes membership or order, so a refetch that returns the same rows re-renders nothing. With `sort` configured, rows keep their order as membership changes. See guide chapter [A shape for queries](docs.html#a-shape-for-queries).

```typescript
const spanish = cards.array({ deck: "spanish" });
if (spanish !== "loading" && spanish !== "notFound") {
  spanish.data.forEach((card) => console.log(card.front));
}
```

```rescript
switch cards.array({deck: "spanish"}) {
| Loaded({data}) => data->Array.forEach(card => Js.log(card.front))
| Loading | NotFound => ()
}
```
