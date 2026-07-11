---
name: Loadable
slug: loadable-type
kind: type
module: core
since: "0.1"
sort: 200
summary: Read state of a query or cached object.
signature:
  ts: 'type Loadable<T> = "loading" | "notFound" | { state: "loaded"; data: T }'
  res: |-
    @tag("state")
    type loadable<'a> =
      | @as("loading") Loading
      | @as("loaded") Loaded({data: 'a})
      | @as("notFound") NotFound
tags: []
---

Every read answers with a `Loadable`: `Loading` means the question was just asked; `Loaded` carries the data; `NotFound` means [one](api.html#one) resolved nothing or [get](api.html#get) missed the cache.

An empty list is `Loaded` with an empty array, not `NotFound` — "the server answered and there are none" is an answer, and the UI can choose between a spinner and an empty state.

The ReScript variant compiles to the same tagged JavaScript values the TypeScript union describes, so both languages pattern-match the same runtime shape.

```typescript
const view = cards.array({ deck: "spanish" });
if (view === "loading") render(skeleton);
else if (view === "notFound") render(missing);
else render(view.data);
```

```rescript
switch cards.array({deck: "spanish"}) {
| Loading => render(skeleton)
| NotFound => render(missing)
| Loaded({data}) => render(data)
}
```
