---
name: one
slug: one
kind: function
module: core
since: "0.1"
sort: 20
summary: Read the first result of a query, reactively.
signature:
  ts: "one: (query: Q) => Loadable<T>"
  res: "one: 'query => loadable<'a>"
tags: []
---

`one` reads the first result of a query — first per the `sort` given to [make](api.html#make).

The read is reactive: inside `observe`, `watch` or a component, the caller re-runs when the result changes. Reading the same query from many places shares one entry — it does not multiply fetches.

- `NotFound` means the fetch completed and the result was empty. `one` is the only reader that answers `NotFound` — [array](api.html#array) answers an empty `Loaded` instead.
- Reading a value by id is not a separate API: make the id a query and read it with `one`.
- All other states behave as described in [Loadable](api.html#loadable-type).

`cards` below is the collection from [make](api.html#make). See guide chapter [Reads answer twice](docs.html#reads-answer-twice).

```typescript
const first = cards.one({ deck: "es" });

if (typeof first === "object" && first.state === "loaded") {
  console.log(first.data.english, first.fresh);
} else if (first === "notFound") {
  console.log("deck is empty");
}
```

```rescript
switch cards.one({deck: "es"}) {
| Loaded({data, fresh}) => Console.log2(data.english, fresh)
| NotFound => Console.log("deck is empty")
| Loading | NotLocal | Failed(_) => ()
}
```
