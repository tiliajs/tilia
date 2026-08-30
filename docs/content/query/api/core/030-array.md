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
const result = cards.array({ deck: "es" });
if (result !== "loading" && result.state === "loaded") console.log(result.data);
```

```rescript
switch cards.array({deck: "es"}) {
| Loaded({data}) => Console.log(data)
| Loading | NoData(_) => ()
}
```
