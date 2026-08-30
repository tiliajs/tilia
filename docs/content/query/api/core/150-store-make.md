---
name: Store.make
slug: store-make
kind: function
module: core
since: "0.1"
sort: 150
summary: Build the shipped store from backend operations.
tags: []
signature.ts: "Store.make<T, Q>(config: StoreConfig<T, Q>): StoreFactory<T, Q, Store<T>>"
signature.res: "Store.make: Store.config<'query, 'a> => store<'query, 'a, Store.t<'a>>"
label: Store.make(config)
---

`Store.make` is the default high-level backend adapter. Its [StoreConfig](api.html#store-config-type) supplies one query operation and one operation for each write kind; the result is a [StoreFactory](api.html#store-factory-type) for the root [make](api.html#make).

Writes are issued one at a time in outbox order, each waiting for its [Outcome](api.html#outcome-type) or [Removal](api.html#removal-type). This preserves cascades and lets a `transient` response stop the batch before later operations are sent.

```typescript
const factory = Store.make<Card, Query>({ find, upsert, remove });
```

```rescript
let factory = Store.make({find, upsert, remove})
```
