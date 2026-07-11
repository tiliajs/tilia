---
name: .dict
slug: dict
kind: function
module: core
since: "0.1"
sort: 50
summary: Same view as array, keyed by object id.
signature:
  ts: "collection.dict(query: Q): Loadable<Record<string, T>>"
  res: "collection.dict: 'query => loadable<dict<'a>>"
tags: []
---

`dict` answers the same query as [array](api.html#array), delivering the rows as a record keyed by id. Fetching, memoization and identity behavior are identical — the two views share the query cache entry.

Use it when downstream code joins rows by id (annotating another list, constant-time lookups in render code).

```typescript
const byId = cards.dict({ deck: "spanish" });
if (byId !== "loading" && byId !== "notFound") {
  console.log(byId.data["gato"]?.back);
}
```

```rescript
switch cards.dict({deck: "spanish"}) {
| Loaded({data}) =>
  switch TiliaQuery.Object.get(data, "gato") {
  | Value(card) => Js.log(card.back)
  | _ => ()
  }
| Loading | NotFound => ()
}
```
