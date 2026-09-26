---
name: Observer
slug: observer-type
kind: type
module: core
since: "1.0"
sort: 200
summary: Opaque observer handle used by low-level observer lifecycle helpers.
tags: []
signature.ts: "type Observer = { readonly [o]: true }"
signature.res: type observer
label: Observer
---

The `Observer`/`observer` type is an opaque handle representing a registered observer.

Application code that uses public APIs does not normally create or consume this type directly. It appears in low-level lifecycle helpers (`_observe`, `_done`, `_ready`, `_clear`).

For ordinary reactive effects, use [observe](api.html#observe) or [watch](api.html#watch).

```typescript
import { _clear, _done, _observe, _ready } from "tilia";
import type { Observer } from "tilia";

// A view library, not an application. Around one render it registers a raw
// observer: reads during `render` are recorded, `_done` closes the recording,
// `_ready` arms it once the view is mounted, and `_clear` ends it on unmount.
// Application code never meets this type; `observe` and `watch` hand back a
// plain stop function instead.
const track = (render: () => void, rerender: () => void) => {
  const observer: Observer = _observe(rerender);
  render();
  _done(observer);
  return { arm: () => _ready(observer, true), release: () => _clear(observer) };
};
```

```rescript
open Tilia

// A view library, not an application. Around one render it registers a raw
// observer: reads during `render` are recorded, `_done` closes the recording,
// `_ready` arms it once the view is mounted, and `_clear` ends it on unmount.
// Application code never meets this type; `observe` and `watch` hand back a
// plain stop function instead.
let track = (render, rerender) => {
  let observer: observer = _observe(rerender)
  render()
  _done(observer)
  (() => _ready(observer, true), () => _clear(observer))
}
```
