---
name: dispose
slug: dispose
kind: function
module: core
since: "0.1"
sort: 120
summary: Close finds and dispose the store.
tags: []
signature.ts: "dispose: () => void"
signature.res: "dispose: unit => unit"
label: query.dispose()
---

`dispose` stops connectivity observation, closes every open find, runs each registered `finally` teardown once, and then disposes the store. The engine completes its own shutdown before calling the store, so no find remains in flight against a stopped store.

Cached data follows normal expiry and nothing is written during disposal. Calls after the first are safe. Stop any application timer that calls [tick](api.html#tick) separately.

```typescript
clearInterval(timer);
query.dispose();
```

```rescript
clearInterval(timer)
query.dispose()
```
