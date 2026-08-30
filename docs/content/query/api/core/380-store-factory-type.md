---
name: StoreFactory
slug: store-factory-type
kind: type
module: core
since: "0.1"
sort: 380
summary: Connect a store to an initialized query engine.
tags: []
signature.ts: |-
  type StoreFactory<T, Q, S> =
    (schema: Schema<T, Q>, binding: Binding<T>) => [Source<T, Q>, S]
signature.res: |-
  type store<'query, 'a, 'store> =
    (schema<'query, 'a>, binding<'a>) => (source<'query, 'a>, 'store)
label: StoreFactory
---

`StoreFactory` is the `store` value accepted by [Config](api.html#config-type). [make](api.html#make) calls it once with the resolved [Schema](api.html#schema-type) and an already working [Binding](api.html#binding-type). It returns the store's [Source](api.html#source-type) and any application handle `S`.

The factory shape ensures neither engine nor store exists unconnected. A custom store may use the binding during construction. Use `void` / `unit` for `S` when it exposes no application handle.

```typescript
const factory: StoreFactory<Card, Query, void> = (schema, binding) => [source(schema, binding), undefined];
```

```rescript
let factory: TiliaQuery.store<query, card, unit> = (schema, binding) => (source(schema, binding), ())
```
