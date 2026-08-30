---
name: upsert
slug: upsert
kind: function
module: core
since: "0.1"
sort: 40
summary: Optimistically write a value through the store handle.
tags: []
signature.ts: "upsert: (value: T) => void"
signature.res: "upsert: 'a => unit"
label: store.upsert(value)
---

`upsert` belongs to the [Store](api.html#store-type) handle returned beside the query engine. It places the value immediately, updates every in-memory query whose `matches` result changed, persists the new optimistic state, and queues an ordered outbox operation.

Writing an id clears its current rejection. A saved confirmation replaces the
value with authoritative server data. A conflict is offered to `merge`: an
accepted merge rebases the write and keeps it pending, while a declined or
missing merge keeps remote truth and records a conflict
[Rejection](api.html#rejection-type). A definitive rejection reverts the
optimistic change and records its message.

```typescript
store.upsert({ id: "cat", deck: "es", word: "gato" });
```

```rescript
store.upsert({id: "cat", deck: "es", word: "gato"})
```
