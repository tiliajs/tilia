---
name: Store.rowTag
slug: store-row-tag
kind: value
module: core
since: "0.1"
sort: 180
summary: Identify row entries in a persistent keyspace.
tags: []
signature.ts: "Store.rowTag: string"
signature.res: "Store.rowTag: string"
label: Store.rowTag
---

`Store.rowTag` is the [Kv](api.html#kv-type) tag under which the shipped store keeps one JSON value per row, keyed by id. It is public so a custom keyspace can index those entries and implement `lookup` against the same rows.

```typescript
// A keyspace of your own keeps a deck index beside the rows. Each row is JSON
// under `rowTag`, keyed by its id, so `set` can maintain the index as rows
// come and go — and `lookup` can later answer a deck the store has no record
// of, and certify it.
const persist: Kv = {
  ...table,
  set: (tag, key, value) => {
    table.set(tag, key, value);
    if (tag === Store.rowTag) deckIndex.update(key, value);
  },
};
```

```rescript
// A keyspace of your own keeps a deck index beside the rows. Each row is JSON
// under `rowTag`, keyed by its id, so `set` can maintain the index as rows
// come and go — and `lookup` can later answer a deck the store has no record
// of, and certify it.
let persist: Store.Kv.t = {
  ...table,
  set: (~tag, ~key, value) => {
    table.set(~tag, ~key, value)
    if tag === Store.rowTag {
      DeckIndex.update(key, value)
    }
  },
}
```
