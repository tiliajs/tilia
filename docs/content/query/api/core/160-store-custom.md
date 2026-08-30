---
name: Store.custom
slug: store-custom
kind: function
module: core
since: "0.1"
sort: 160
summary: Build the shipped store from advanced channels.
tags: []
signature.ts: "Store.custom<T, Q>(channels: StoreChannels<T, Q>): StoreFactory<T, Q, Store<T>>"
signature.res: "Store.custom: Store.channels<'query, 'a> => store<'query, 'a, Store.t<'a>>"
label: Store.custom(channels)
---

`Store.custom` is the lower-level adapter for a backend already expressed as [Remote](api.html#remote-type) read and write channels. It adds the shipped store's cache, outbox, merge, query registry, persistence, and application [Store](api.html#store-type) handle.

Use [Store.make](api.html#store-make) when the backend is more naturally described as individual `find`, `upsert`, and `remove` operations.

```typescript
const factory = Store.custom<Card, Query>({ remote, persist });
```

```rescript
let factory = Store.custom({remote, persist})
```
