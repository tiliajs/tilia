---
name: .dispose
slug: dispose
kind: function
module: core
since: "0.1"
sort: 140
summary: Stop the connectivity watcher and cancel every open channel.
signature:
  ts: "collection.dispose(): void"
  res: "collection.dispose: unit => unit"
tags: []
---

`dispose` tears the instance down: the reactive watcher on `remote.online` stops, and every open fetch and write channel is cancelled, so late adapter answers become no-ops. The instance stays readable but inert — nothing will fetch, replay or settle again.

Use it at the end of a test or when unmounting an app shell. For logout, use [clear](api.html#clear) instead: it resets state but keeps the instance alive.

```typescript
afterEach(() => cards.dispose());
```

```rescript
afterEach(() => cards.dispose())
```
