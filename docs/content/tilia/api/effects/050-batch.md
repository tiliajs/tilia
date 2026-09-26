---
name: batch
slug: batch
kind: function
module: core
since: "2.0"
sort: 50
summary: Group multiple writes and flush notifications once.
tags: []
signature.ts: "function batch(fn: () => void): void"
signature.res: "let batch: (unit => unit) => unit"
label: batch(fn)
---

`batch` runs `fn` while notification flushing is locked, then flushes notifications once the outermost batch ends.

Nested batches are supported. Within a batch, writes update state immediately, but observers are notified only after the outermost batch ends. This prevents transient intermediate notifications.

`observe`, `watch` effects, and computed rebuilds already use deferred flushing. Use `batch` for grouped writes from non-reactive callbacks. See [watch](api.html#watch) and the guide chapter [While Alice sleeps](guide.html#while-alice-sleeps).

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
