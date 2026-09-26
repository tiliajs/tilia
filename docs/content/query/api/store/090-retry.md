---
name: retry
slug: retry
kind: function
module: core
since: "0.1"
sort: 90
summary: Reapply and queue one rejected operation.
tags: []
signature.ts: "retry: (rejection: Rejection<T>) => void"
signature.res: "retry: rejection<'a> => unit"
label: store.retry(rejection)
---

`retry` removes the exact [Rejection](api.html#rejection-type), reapplies its edit as an ordinary optimistic write against the value that exists now, and queues a copied operation.

It acts only when the same rejection record is still present. A record already cleared or replaced is a no-op. Retrying a remove queues another remove; retrying a create or update queues the recorded `edited` value.

```typescript
// The rejections panel. "Try again" queues the refused work as a new
// optimistic write against the row as it stands now. The record is spent
// either way: if the row has moved on since, `retry` on it is a no-op.
for (const rejection of store.status.rejected) {
  panel.row(describe(rejection), { tryAgain: () => store.retry(rejection) });
}
```

```rescript
// The rejections panel. "Try again" queues the refused work as a new
// optimistic write against the row as it stands now. The record is spent
// either way: if the row has moved on since, `retry` on it is a no-op.
store.status.rejected->Array.forEach(rejection =>
  panel.row(describe(rejection), ~tryAgain=() => store.retry(rejection))
)
```
