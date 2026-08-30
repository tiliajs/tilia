---
name: Schema
slug: schema-type
kind: type
module: core
since: "0.1"
sort: 350
summary: Share resolved collection behavior with a custom store.
tags: []
signature.ts: |-
  type Schema<T, Q> = {
    id: (value: T) => string,
    matches: (query: Q, value: T) => boolean,
    key: (query: Q) => string,
    sort: (query: Q) => (values: T[]) => T[],
    now: () => number
  }
signature.res: |-
  type schema<'query, 'a> = {
    id: 'a => string,
    matches: ('query, 'a) => bool,
    key: 'query => string,
    sort: 'query => array<'a> => array<'a>,
    now: unit => float,
  }
label: Schema
---

`Schema` is the root [Config](api.html#config-type) after defaults are resolved. [make](api.html#make) passes it once to a custom [StoreFactory](api.html#store-factory-type), so engine and store share the same id, membership, key, ordering, and clock behavior.

The store must not apply its own defaults for these fields.

```typescript
const keyOf = <T, Q>(schema: Schema<T, Q>, query: Q) => schema.key(query);
```

```rescript
let keyOf = (schema: TiliaQuery.schema<'query, 'a>, query) => schema.key(query)
```
