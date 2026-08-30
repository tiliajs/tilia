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
if (tag === Store.rowTag) index(value);
```

```rescript
if tag === Store.rowTag {
  index(value)
}
```
