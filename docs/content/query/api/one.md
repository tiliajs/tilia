---
name: .one
slug: one
kind: function
module: core
since: "0.1"
sort: 30
summary: Detail view resolving the first row of a query.
signature:
  ts: "collection.one(query: Q): Loadable<T>"
  res: "collection.one: 'query => loadable<'a>"
tags: []
---

`one` runs the same two-tier fetch as any query and resolves the first row of the result. An empty result answers `NotFound` — the query was answered, and there is no such row.

The view is memoized per query key and stays reactive: editing the resolved object updates the view in place. See guide chapter [Reads answer twice](docs.html#reads-answer-twice).

```typescript
const gato = cards.one({ deck: "spanish", front: "gato" });
if (gato === "loading") render(skeleton);
else if (gato === "notFound") render(missing);
else render(gato.data);
```

```rescript
switch cards.one({deck: "spanish", front: "gato"}) {
| Loading => render(skeleton)
| NotFound => render(missing)
| Loaded({data}) => render(data)
}
```
