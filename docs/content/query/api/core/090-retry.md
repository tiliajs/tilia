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
const rejection = store.status.rejected[0];
if (rejection) store.retry(rejection);
```

```rescript
switch store.status.rejected[0] {
| Some(rejection) => store.retry(rejection)
| None => ()
}
```
