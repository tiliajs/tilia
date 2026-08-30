---
name: Binding
slug: binding-type
kind: type
module: core
since: "0.1"
sort: 360
summary: Let a custom store update engine rows safely.
tags: []
signature.ts: |-
  type Binding<T> = {
    item: (id: string) => T | undefined,
    changed: (values: T[]) => void,
    removed: (ids: string[]) => void,
    place: (value: T) => void
  }
signature.res: |-
  type binding<'a> = {
    item: string => option<'a>,
    changed: array<'a> => unit,
    removed: array<string> => unit,
    place: 'a => unit,
  }
label: Binding
---

`Binding` is passed to a custom [StoreFactory](api.html#store-factory-type):

- `item(id)` returns the canonical live object when present. A merge may mutate that object in place; a store must not keep another canonical copy.
- `changed(values)` applies remote truth and retains rows only while an in-memory query matches.
- `removed(ids)` applies remote deletions.
- `place(value)` applies an optimistic value and keeps its row even when no current query lists it.

Insertions and deletions remain controlled by these methods rather than direct access to the row table.

```typescript
const apply = <T>(binding: Binding<T>, values: T[]) => binding.changed(values);
```

```rescript
let apply = (binding: TiliaQuery.binding<'a>, values) => binding.changed(values)
```
