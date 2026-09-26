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
// A sync indicator in the header. `status` is a tilia object, so `observe`
// re-runs as the outbox drains and as rejections come and go.
observe(() => {
  const { pending, rejected } = store.status;
  syncBadge.textContent = pending > 0 ? `${pending} to sync` : "";
  syncBadge.hidden = pending === 0 && rejected.length === 0;
});
```

```rescript
// A sync indicator in the header. `status` is a tilia object, so `observe`
// re-runs as the outbox drains and as rejections come and go.
Tilia.observe(() => {
  let {pending, rejected} = store.status
  syncBadge.textContent = pending > 0 ? `${pending->Int.toString} to sync` : ""
  syncBadge.hidden = pending === 0 && rejected->Array.length === 0
})->ignore
```
