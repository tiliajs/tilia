---
name: .get
slug: get
kind: function
module: core
since: "0.1"
sort: 20
summary: Read a cached object by id, without fetching.
signature:
  ts: "collection.get(id: string): Loadable<T>"
  res: "collection.get: string => loadable<'a>"
tags: []
---

`get` looks up the object cache by id. It never fetches: an id the cache does not hold answers `NotFound`, even if the remote knows it.

The read is reactive — when the object later arrives through a fetch, [upsert](api.html#upsert) or [changed](api.html#changed), observers of `get` re-run. Use [one](api.html#one) instead when the row should be fetched on demand.

```typescript
const card = cards.get("gato");
if (card !== "loading" && card !== "notFound") {
  console.log(card.data.front);
}
```

```rescript
switch cards.get("gato") {
| Loaded({data}) => Js.log(data.front)
| Loading | NotFound => ()
}
```
