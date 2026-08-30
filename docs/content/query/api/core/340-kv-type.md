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
const persist: Kv = Store.memory();
```

```rescript
let persist: TiliaQuery.Store.Kv.t = Store.memory()
```
