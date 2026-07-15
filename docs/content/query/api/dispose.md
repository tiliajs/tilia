---
name: dispose
slug: dispose
kind: function
module: core
since: "0.1"
sort: 120
summary: Close every open fetch and stop watching connectivity.
signature:
  ts: "dispose: () => void"
  res: "dispose: unit => unit"
tags: []
---

`dispose` shuts the collection down:

- It stops watching `remote.online`.
- It closes every open fetch: each registered `finally` teardown runs — live subscriptions are unsubscribed.
- Cached data is left alone; it follows normal expiry.

Safe to call more than once. Remember to also stop the interval driving [tick](api.html#tick) — the engine owns no timers, so it cannot stop them either.

`cards` is the collection from [make](api.html#make). See guide chapter [The pulse and the canopy](guide.html#the-pulse-and-the-canopy).

```typescript
clearInterval(timer);
cards.dispose();
```

```rescript
clearInterval(timer)
cards.dispose()
```
