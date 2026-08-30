---
name: receive.removed
slug: receive-removed
kind: function
module: core
since: "0.1"
sort: 70
summary: Apply removed ids pushed by the server.
tags: []
signature.ts: "receive.removed: (ids: string[]) => void"
signature.res: "removed: array<string> => unit"
label: store.receive.removed(ids)
---

`receive.removed` accepts ids deleted by the server. Each id leaves matching in-memory queries and is deleted from persistence.

A server removal conflicts with a pending create or update: the operation is cleared and a rejection is recorded. It confirms and clears a pending remove. Deliveries do not change query freshness.

```typescript
socket.on("cards:removed", (ids: string[]) => store.receive.removed(ids));
```

```rescript
socket.on("cards:removed", ids => store.receive.removed(ids))
```
