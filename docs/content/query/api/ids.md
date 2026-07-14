---
name: _ids
slug: ids
kind: function
module: core
since: "0.1"
sort: 150
summary: Testing hook — ids held by an in-memory query.
signature:
  ts: "_ids: (query: Q) => string[] | undefined"
  res: "_ids: 'query => option<array<string>>"
tags: []
---

`_ids` returns the row ids an in-memory query currently holds, or `None` / `undefined` when the query is not in memory.

- The array is a copy — mutating it changes nothing.
- Ids reflect the visible result, optimistic overlay included.

The underscore marks a tooling entry point: `_ids` exists for tests and debugging, where asserting on ids is cheaper than unwrapping a [Loadable](api.html#loadable-type).

`cards` is the collection from [make](api.html#make).

```typescript
cards._ids({ deck: "es" }); // ["cat", "dog"], or undefined
```

```rescript
switch cards._ids({deck: "es"}) {
| Some(ids) => Console.log(ids) // ["cat", "dog"]
| None => Console.log("query not in memory")
}
```
