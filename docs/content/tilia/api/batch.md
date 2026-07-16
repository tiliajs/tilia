---
name: batch
slug: batch
kind: function
module: core
since: "2.0"
sort: 50
summary: Group multiple writes and flush notifications once.
signature:
  ts: "function batch(fn: () => void): void"
  res: "let batch: (unit => unit) => unit"
tags: []
---

`batch` runs `fn` with notification flushing locked, then flushes once when the outermost batch ends.

Nested batches are supported. While inside a batch, writes update state immediately but observers are notified only after unlock. This prevents transient intermediate notifications.

`observe`, `watch` effects, and computed rebuilds already run under deferred flushing. Use `batch` for grouped writes from non-reactive callbacks. See [watch](api.html#watch) and guide chapter [Time and consistency](guide.html#time-and-consistency).

```typescript
import { batch, tilia } from "tilia";

const rect = tilia({
  width: 100,
  height: 50,
});

batch(() => {
  rect.width = 200;
  rect.height = 100;
});
```

```rescript
open Tilia

let rect = tilia({
  width: 100,
  height: 50,
})

batch(() => {
  rect.width = 200
  rect.height = 100
})
```
