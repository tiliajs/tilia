---
name: receive.changed
slug: receive-changed
kind: function
module: core
since: "0.1"
sort: 60
summary: Apply changed values pushed by the server.
tags: []
signature.ts: "receive.changed: (values: T[]) => void"
signature.res: "changed: array<'a> => unit"
label: store.receive.changed(values)
---

`receive.changed` accepts authoritative facts from a subscription or other server push. Values join and leave matching in-memory queries and replace clean persisted copies.

When a value has a pending local operation, the configured `merge` receives its [Change](api.html#change-type). Returning `true` rebases the pending edit after mutating the local value in place; returning `false` keeps remote truth, clears the operation, and records a conflict. Deliveries do not change query freshness.

```typescript
// Nora edits a card on her phone and the server tells every device. Clean
// rows are replaced. A card Alice is editing offline is not overwritten: it
// goes through `merge`, and her edit is rebased or recorded as a conflict.
socket.on("cards:changed", (changed: Card[]) => store.receive.changed(changed));
```

```rescript
// Nora edits a card on her phone and the server tells every device. Clean
// rows are replaced. A card Alice is editing offline is not overwritten: it
// goes through `merge`, and her edit is rebased or recorded as a conflict.
socket.on("cards:changed", changed => store.receive.changed(changed))
```
