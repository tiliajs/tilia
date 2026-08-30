---
name: status
slug: status
kind: value
module: core
since: "0.1"
sort: 80
summary: Read reactive pending and rejected write state.
tags: []
signature.ts: "status: Status<T>"
signature.res: "status: status<'a>"
label: store.status
---

`status` is the reactive [Status](api.html#status-type) on the [Store](api.html#store-type) handle.

- `pending` counts outbox operations waiting for confirmation, including offline writes.
- `rejected` lists reverted conflicts and definitive write failures in outbox order, regardless of reply order.

Read failures are represented by [Loadable](api.html#loadable-type), not by `status`.

```typescript
observe(() => console.log(store.status.pending, store.status.rejected));
```

```rescript
Tilia.observe(() => Console.log2(store.status.pending, store.status.rejected))
```
