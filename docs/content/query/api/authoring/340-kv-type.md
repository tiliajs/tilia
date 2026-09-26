---
name: Kv
slug: kv-type
kind: type
module: core
since: "0.1"
sort: 340
summary: Persist tagged string entries for the shipped store.
tags: []
signature.ts: |-
  type Kv = {
    get: (tag: string, keys: string[] | undefined, set: (values: string[]) => void) => void,
    keys: (tag: string, set: (keys: string[]) => void) => void,
    set: (tag: string, key: string, value: string | undefined) => void
  }
signature.res: |-
  type Store.Kv.t = {
    get: (~tag: string, ~keys: array<string>=?, ~set: array<string> => unit) => unit,
    keys: (~tag: string, ~set: array<string> => unit) => unit,
    set: (~tag: string, ~key: string, option<string>) => unit,
  }
label: Kv
---

`Kv` is the complete persistence interface required by the shipped store. Rows, query records, and the outbox are tagged string entries.

- `get(tag, keys, set)` reads named entries, or every entry under the tag when `keys` is `undefined`.
- `keys(tag, set)` lists entry keys without reading their values.
- `set(tag, key, value)` writes one entry; `undefined` / `None` deletes it.

Reads reply through callbacks synchronously or later. Persistence is command-only: an implementation that cannot read answers with no values, and write errors are reported by the implementation rather than through the store. Use [Store.memory](api.html#store-memory) or the TypeScript [IndexedDB adapter](api.html#indexeddb-make).

```typescript
// The whole of what the shipped store asks of persistence: three functions
// over tagged string entries. This one, over a Map of Maps, is the shape
// `Store.memory()` has; IndexedDB answers the same three calls later instead
// of now, and the store does not care which.
const tags = new Map<string, Map<string, string>>();
const under = (tag: string) => tags.get(tag) ?? tags.set(tag, new Map()).get(tag)!;

const persist: Kv = {
  get: (tag, keys, set) => set((keys ?? [...under(tag).keys()]).flatMap((key) => under(tag).get(key) ?? [])),
  keys: (tag, set) => set([...under(tag).keys()]),
  set: (tag, key, value) => {
    if (value === undefined) under(tag).delete(key);
    else under(tag).set(key, value);
  },
};
```

```rescript
// The whole of what the shipped store asks of persistence: three functions
// over tagged string entries. This one, over a Map of Maps, is the shape
// `Store.memory()` has; IndexedDB answers the same three calls later instead
// of now, and the store does not care which.
let tags: Map.t<string, Map.t<string, string>> = Map.make()
let under = tag =>
  switch tags->Map.get(tag) {
  | Some(entries) => entries
  | None =>
    let entries = Map.make()
    tags->Map.set(tag, entries)
    entries
  }

let persist: Store.Kv.t = {
  get: (~tag, ~keys=?, ~set) => {
    let entries = under(tag)
    let keys = keys->Option.getOr(entries->Map.keys->Iterator.toArray)
    set(keys->Array.filterMap(key => entries->Map.get(key)))
  },
  keys: (~tag, ~set) => set(under(tag)->Map.keys->Iterator.toArray),
  set: (~tag, ~key, value) =>
    switch value {
    | Some(value) => under(tag)->Map.set(key, value)
    | None => under(tag)->Map.delete(key)->ignore
    },
}
```
