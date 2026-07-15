---
name: array
slug: array
kind: function
module: core
since: "0.1"
sort: 30
summary: Read a query's full result set, reactively.
signature:
  ts: "array: (query: Q) => Loadable<T[]>"
  res: "array: 'query => loadable<array<'a>>"
tags: []
---

`array` reads a query's results, ordered per the `sort` given to [make](api.html#make).

The read is reactive: inside `observe`, `watch` or a component, the caller re-runs when the result changes.

- `array` never answers `NotFound`: an empty result is `Loaded` with an empty array.
- Results include the optimistic overlay — pending and rejected writes are re-applied on top of every remote delivery, so an unconfirmed write never flickers out of a result.
- All states and the `fresh` flag behave as described in [Loadable](api.html#loadable-type).

`cards` below is the collection from [make](api.html#make). See guide chapter [Reads answer twice](guide.html#reads-answer-twice).

```typescript
import { observe } from "tilia";

observe(() => {
  const spanish = cards.array({ deck: "es" });
  if (typeof spanish === "object" && spanish.state === "loaded") {
    console.log(spanish.data.length, spanish.fresh ? "fresh" : "cached");
  }
});
```

```rescript
Tilia.observe(() =>
  switch cards.array({deck: "es"}) {
  | Loaded({data, fresh}) => Console.log2(data->Array.length, fresh ? "fresh" : "cached")
  | Loading | NotFound | NotLocal | Failed(_) => ()
  }
)
```
