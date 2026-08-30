---
name: Store.memory
slug: store-memory
kind: function
module: core
since: "0.1"
sort: 170
summary: Create a process-local string keyspace.
tags: []
signature.ts: "Store.memory(): Kv"
signature.res: "Store.memory: unit => Store.Kv.t"
label: Store.memory()
---

`Store.memory` creates the in-memory [Kv](api.html#kv-type) used when `persist` is omitted. It follows the same storage path as a durable keyspace but forgets all entries with the process.

```typescript
const persist = Store.memory();
```

```rescript
let persist = Store.memory()
```
